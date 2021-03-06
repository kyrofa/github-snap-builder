require 'sinatra/base'
require 'octokit'
require 'json'
require 'openssl'     # Verifies the webhook signature
require 'jwt'         # Authenticates a GitHub App
require 'time'        # Gets ISO 8601 representation of a Time object
require 'logger'      # Logs debug statements
require 'yaml'
require 'github_snap_builder/config'
require 'github_snap_builder/snap_builder'

module GithubSnapBuilder
	if ENV.include? 'SNAP_BUILDER_CONFIG'
		CONFIG = Config.new(File.read(ENV['SNAP_BUILDER_CONFIG']))
	else
		CONFIG = Config.new('{}')
	end

	class Application < Sinatra::Application
		set :port, CONFIG.port
		set :bind, CONFIG.bind

		# Converts the newlines. Expects that the private key has been set as an
		# environment variable in PEM format.
		PRIVATE_KEY = OpenSSL::PKey::RSA.new(CONFIG.github_app_private_key.gsub('\n', "\n")) if CONFIG.valid?

		# Your registered app must have a secret set. The secret is used to verify
		# that webhooks are sent by GitHub.
		WEBHOOK_SECRET = CONFIG.github_webhook_secret

		# The GitHub App's identifier (type integer) set when registering an app.
		APP_IDENTIFIER = CONFIG.github_app_id

		# Turn on Sinatra's verbose logging during development
		configure :development do
			set :logging, Logger::DEBUG
		end

		# Executed before each request to the `/event_handler` route
		before '/event_handler' do
			get_payload_request(request)
			verify_webhook_signature
			authenticate_app
			# Authenticate the app installation in order to run API operations
			authenticate_installation(@payload)
		end

		post '/event_handler' do
			if !CONFIG.valid?
				logger.info "Invalid config, ignoring event..."
				return 200
			end

			case request.env['HTTP_X_GITHUB_EVENT']
			when 'pull_request'
				repo = @payload['pull_request']['base']['repo']['full_name']
				unless CONFIG.repos_include? repo
					logger.info "Not configured for repo '#{repo}'. Ignoring event..."
					return 200 # Ignored, but still successful
				end

				case @payload['action']
				when "opened", "reopened", "synchronize"
					handle_pull_request_updated_event(@payload)
				end
			end

			200 # success status
		end

		get '/logs/*' do
			logfile = File.join logdir, params[:splat][0]
			if File.file? logfile
				send_file logfile
			else
				404
			end
		end


		helpers do

			def handle_pull_request_updated_event(payload)
				pull_request = payload['pull_request']
				repo = pull_request['base']['repo']['full_name']
				head_url = pull_request['head']['repo']['html_url']
				base_url = pull_request['base']['repo']['html_url']
				commit_sha = pull_request['head']['sha']
				pr_number = pull_request['number']

				repo_config = CONFIG.repo(repo) || raise("Config missing repo definition for '#{repo}'")
				channel = repo_config.channel
				token = repo_config.token || raise("'#{repo}' config missing token")

				relative_logfile_path = File.join repo, "#{commit_sha}.log"
				logfile_path = File.join(logdir, relative_logfile_path)
				FileUtils.mkpath File.dirname(logfile_path)
				FileUtils.chmod_R 0755, File.dirname(logfile_path)
				build_logger = Logger.new(logfile_path)
				log_url = request.url.gsub 'event_handler', "logs/#{relative_logfile_path}"
				status_reporter = GithubStatusReporter.new(@installation_client, repo, commit_sha, log_url)

				begin
					begin
						status_reporter.pending("Currently building a snap...")

						builder = SnapBuilder.new(build_logger, base_url, head_url, commit_sha, CONFIG.build_type)
						logger.info "Building snap for '#{repo}'"
						snap_path = builder.build
					rescue Error => e
						logger.error "Failed to build snap: #{e.message}"
						status_reporter.error("Snap failed to build.")
						return
					end

					begin
						status_reporter.pending("Currently uploading/releasing snap...")

						full_channel = "#{channel}/pr-#{pr_number}"
						logger.info "Pushing and releasing snap into '#{full_channel}'"
						builder.release(snap_path, token, full_channel)
					rescue Error => e
						logger.error "Failed to push/release snap: #{e.message}"
						status_reporter.error("Snap failed to upload/release.")
						return
					end

					logger.info 'Built and released snap, all done'
					status_reporter.success("Snap built and released to '#{full_channel}'")
				rescue => e
					logger.error "Unknown error: #{e.message}"
					status_reporter.error("Encountered an error.")
					raise
				ensure
					if !snap_path.nil? and File.file? snap_path
						File.delete snap_path
					end
				end
			end

			# Saves the raw payload and converts the payload to JSON format
			def get_payload_request(request)
				# request.body is an IO or StringIO object
				# Rewind in case someone already read it
				request.body.rewind
				# The raw text of the body is required for webhook signature verification
				@payload_raw = request.body.read
				begin
					@payload = JSON.parse @payload_raw
				rescue => e
					fail  "Invalid JSON (#{e}): #{@payload_raw}"
				end
			end

			# Instantiate an Octokit client authenticated as a GitHub App.
			# GitHub App authentication requires that you construct a
			# JWT (https://jwt.io/introduction/) signed with the app's private key,
			# so GitHub can be sure that it came from the app an not altererd by
			# a malicious third party.
			def authenticate_app
				payload = {
					# The time that this JWT was issued, _i.e._ now.
					iat: Time.now.to_i,

					# JWT expiration time (10 minute maximum)
					exp: Time.now.to_i + (10 * 60),

					# Your GitHub App's identifier number
					iss: APP_IDENTIFIER
				}

				# Cryptographically sign the JWT.
				jwt = JWT.encode(payload, PRIVATE_KEY, 'RS256')

				# Create the Octokit client, using the JWT as the auth token.
				@app_client ||= Octokit::Client.new(bearer_token: jwt)
			end

			# Instantiate an Octokit client, authenticated as an installation of a
			# GitHub App, to run API operations.
			def authenticate_installation(payload)
				@installation_id = payload['installation']['id']
				@installation_token = @app_client.create_app_installation_access_token(@installation_id)[:token]
				@installation_client = Octokit::Client.new(bearer_token: @installation_token)
			end

			# Check X-Hub-Signature to confirm that this webhook was generated by
			# GitHub, and not a malicious third party.
			#
			# GitHub uses the WEBHOOK_SECRET, registered to the GitHub App, to
			# create the hash signature sent in the `X-HUB-Signature` header of each
			# webhook. This code computes the expected hash signature and compares it to
			# the signature sent in the `X-HUB-Signature` header. If they don't match,
			# this request is an attack, and you should reject it. GitHub uses the HMAC
			# hexdigest to compute the signature. The `X-HUB-Signature` looks something
			# like this: "sha1=123456".
			# See https://developer.github.com/webhooks/securing/ for details.
			def verify_webhook_signature
				their_signature_header = request.env['HTTP_X_HUB_SIGNATURE'] || 'sha1='
				method, their_digest = their_signature_header.split('=')
				our_digest = OpenSSL::HMAC.hexdigest(method, WEBHOOK_SECRET, @payload_raw)
				halt 401 unless their_digest == our_digest

				# The X-GITHUB-EVENT header provides the name of the event.
				# The action value indicates the which action triggered the event.
				logger.debug "---- received event #{request.env['HTTP_X_GITHUB_EVENT']}"
				logger.debug "----    action #{@payload['action']}" unless @payload['action'].nil?
			end

			def logdir
				ENV.fetch("SNAP_BUILDER_LOG_DIR", "log")
			end

			def logfile_path(repo, commit_sha)
			end

		end
	end

	class GithubStatusReporter
		def initialize(client, repo, commit_sha, log_url)
			@client = client
			@repo = repo
			@commit_sha = commit_sha
			@log_url = log_url
		end

		def pending(message)
			create_status 'pending', message
		end

		def success(message)
			create_status 'success', message
		end

		def failure(message)
			create_status 'failure', message
		end

		def error(message)
			create_status 'error', message
		end

		private

		def create_status(state, description)
			@client.create_status(@repo, @commit_sha, state, {
				context: "Snap Builder",
				description: description,
				target_url: @log_url
			})
		end
	end
end