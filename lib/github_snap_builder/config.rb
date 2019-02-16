require 'yaml'
require 'github_snap_builder'
require 'github_snap_builder/snap_builder'

module GithubSnapBuilder
	class Config
		def initialize(config_file_contents)
			@config = YAML.safe_load(config_file_contents) || {}
		end

		def github_webhook_secret
			@config['github_webhook_secret']
		end

		def github_app_id
			@config['github_app_id']
		end

		def github_app_private_key
			@config['github_app_private_key']
		end

		def build_type
			@config['build_type']
		end

		def port
			@config.fetch('port', 3000)
		end

		def bind
			@config.fetch('bind', '0.0.0.0')
		end

		def repos
			@repos ||= initialize_repos
		end

		def repos_include?(repo_name)
			@config.fetch('repos', {}).include? repo_name
		end

		def repo(repo_name)
			repos.each do | repo |
				if repo.name == repo_name
					return repo
				end
			end
		end

		def validate
			if @config.nil? or @config.empty?
				raise ConfigurationError, "Config seems completely empty"
			end

			if github_webhook_secret.nil? || !github_webhook_secret.is_a?(String) || github_webhook_secret.empty?
				raise ConfigurationFieldError, "github_webhook_secret"
			end

			if github_app_id.nil? || !github_app_id.is_a?(Integer) || github_app_id == 0
				raise ConfigurationFieldError, "github_app_id"
			end

			if github_app_private_key.nil? || !github_app_private_key.is_a?(String) || github_app_private_key.empty?
				raise ConfigurationFieldError, "github_app_private_key"
			end

			if build_type.nil? || !build_type.is_a?(String) || build_type.empty? || !SnapBuilder.supported_build_types.include?(build_type)
				raise ConfigurationFieldError, "build_type"
			end

			if port.nil? || !port.is_a?(Integer) || port == 0
				raise ConfigurationFieldError, "port"
			end

			if bind.nil? || !bind.is_a?(String) || bind.empty?
				raise ConfigurationFieldError, "bind"
			end
		end

		def valid?
			begin
				validate
			rescue ConfigurationError
				return false
			end

			begin
				repos.each do | repo |
					repo.validate
				end
			rescue ConfigurationError
				return false
			end

			true
		end

		private

		def initialize_repos
			repos = []
			@config.fetch('repos', {}).each do | name, definition |
				repos << RepoConfig.new(name, definition)
			end
			repos
		end
	end

	class RepoConfig
		attr_reader :name, :channel, :token

		def initialize(name, config)
			@name = name
			@channel = config.fetch('channel', 'edge')
			@token = config['token']
		end

		def validate
			if name.nil? || !name.is_a?(String) || name.empty?
				raise ConfigurationFieldError, "repo name"
			end

			if channel.nil? || !channel.is_a?(String) || channel.empty?
				raise ConfigurationFieldError, "#{name}'s channel"
			end

			if token.nil? || !token.is_a?(String) || token.empty?
				raise ConfigurationFieldError, "#{name}'s token"
			end
		end

		def valid?
			begin
				validate
			rescue ConfigurationError
				return false
			end

			true
		end
	end
end