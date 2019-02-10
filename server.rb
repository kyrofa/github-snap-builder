require 'sinatra/base'
require 'octokit'
require 'json'
require 'openssl'     # Verifies the webhook signature
require 'jwt'         # Authenticates a GitHub App
require 'time'        # Gets ISO 8601 representation of a Time object
require 'logger'      # Logs debug statements
require 'yaml'
require_relative 'snap_builder'

if ENV.include? 'SNAP_BUILDER_CONFIG'
	$CONFIG = YAML.safe_load(File.read(ENV['SNAP_BUILDER_CONFIG']))
else
	$CONFIG = {}
end

class GHAapp < Sinatra::Application
	set :port, $CONFIG.fetch('port', 3000)
	set :bind, $CONFIG.fetch('bind', '0.0.0.0')

	# Converts the newlines. Expects that the private key has been set as an
	# environment variable in PEM format.
	PRIVATE_KEY = OpenSSL::PKey::RSA.new($CONFIG['github_app_private_key'].gsub('\n', "\n")) if $CONFIG.include? 'github_app_private_key'

	# Your registered app must have a secret set. The secret is used to verify
	# that webhooks are sent by GitHub.
	WEBHOOK_SECRET = $CONFIG['github_webhook_secret']

	# The GitHub App's identifier (type integer) set when registering an app.
	APP_IDENTIFIER = $CONFIG['github_app_id']

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
		case request.env['HTTP_X_GITHUB_EVENT']
		when 'pull_request'
			repo = @payload['pull_request']['base']['repo']['full_name']
			unless $CONFIG.fetch('repos', {}).include? repo
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


	helpers do

		def handle_pull_request_updated_event(payload)
			pull_request = payload['pull_request']
			repo = pull_request['base']['repo']['full_name']
			clone_url = pull_request['head']['repo']['html_url']
			commit_sha = pull_request['head']['sha']
			pr_number = pull_request['number']

			config = $CONFIG['repos'] || raise("Config missing repos definition")
			repo_config = config[repo] || raise("Config missing repo definition for '#{repo}'")
			channel = repo_config.fetch('channel', 'edge') || raise("'#{repo}' config missing channel")
			token = repo_config['token'] || raise("'#{repo}' config missing token")

			@installation_client.create_status(repo, commit_sha, 'pending', {
				context: "Snap Builder",
				description: "Currently building a snap..."
			})

			begin
				begin
					builder = SnapBuilder.new(clone_url, commit_sha)
					logger.info "Building snap for '#{repo}'"
					snap = builder.build()
				rescue SnapBuilderError => e
					logger.error 'Failed to build snap'
					@installation_client.create_status(repo, commit_sha, 'error', {
						context: "Snap Builder",
						description: "Snap failed to build. Please see logs."
					})
					return
				end

				begin
					full_channel = "#{channel}/pr-#{pr_number}"
					logger.info "Pushing and releasing snap into '#{full_channel}'"
					snap.push_and_release(token, full_channel)
				rescue SnapBuilderError => e
					logger.error 'Failed to push/release snap'
					@installation_client.create_status(repo, commit_sha, 'error', {
						context: "Snap Builder",
						description: "Snap failed to push/release. Please see logs."
					})
					return
				end

				logger.info 'Built and released snap, all done'
				@installation_client.create_status(repo, commit_sha, 'success', {
					context: "Snap Builder",
					description: "Snap built and released to '#{channel}'"
				})
			rescue => e
				logger.error "Encountered unexpected error: #{e.message}"
				@installation_client.create_status(repo, commit_sha, 'error', {
					context: "Snap Builder",
					description: "Encountered an error: #{e.message}"
				})
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

	end

	# Finally some logic to let us run this server directly from the command line,
	# or with Rack. Don't worry too much about this code. But, for the curious:
	# $0 is the executed file
	# __FILE__ is the current file
	# If they are the same—that is, we are running this file directly, call the
	# Sinatra run method
	run! if __FILE__ == $0
end
