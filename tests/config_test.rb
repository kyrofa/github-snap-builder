require 'github_snap_builder/config'
require_relative 'test_helpers'

module GithubSnapBuilder
	class ConfigTest < SnapBuilderBaseTest
		def setup
			@config_data = {
				"github_webhook_secret" => "test-secret",
				"github_app_id" => 123,
				"github_app_private_key" => "test-key",
				"port" => 1234,
				"bind" => "1.2.3.4",
				"build_type" => "docker",
				"repos" => {
					"test/repo" => {
						"channel" => "test-channel",
						"token" => "test-token",
					}
				},
			}
		end

		def test_valid
			assert config.valid?
		end

		def test_github_webhook_secret
			assert_equal "test-secret", config.github_webhook_secret
		end

		def test_github_app_id
			assert_equal 123, config.github_app_id
		end

		def test_github_app_private_key
			assert_equal "test-key", config.github_app_private_key
		end

		def test_port
			assert_equal 1234, config.port
		end

		def test_bind
			assert_equal "1.2.3.4", config.bind
		end

		def test_build_type
			assert_equal "docker", config.build_type
		end

		def test_repos
			repos = config.repos
			assert_equal 1, repos.length
			repo = repos[0]

			assert_equal "test/repo", repo.name
			assert_equal "test-channel", repo.channel
			assert_equal "test-token", repo.token
		end

		def test_invalid_github_webhook_secret
			@config_data["github_webhook_secret"] = 1
			assert !config.valid?

			@config_data["github_webhook_secret"] = ''
			assert !config.valid?

			@config_data.delete "github_webhook_secret"
			assert !config.valid?
		end

		def test_invalid_github_app_id
			@config_data["github_app_id"] = 'string'
			assert !config.valid?

			@config_data["github_app_id"] = 0
			assert !config.valid?

			@config_data.delete "github_app_id"
			assert !config.valid?
		end

		def test_invalid_github_app_private_key
			@config_data["github_app_private_key"] = 1
			assert !config.valid?

			@config_data["github_app_private_key"] = ''
			assert !config.valid?

			@config_data.delete "github_app_private_key"
			assert !config.valid?
		end

		def test_invalid_port
			@config_data["port"] = 'string'
			assert !config.valid?

			@config_data["port"] = 0
			assert !config.valid?
		end

		def test_invalid_bind
			@config_data["bind"] = 1
			assert !config.valid?

			@config_data["bind"] = ''
			assert !config.valid?
		end

		def test_invalid_build_type
			@config_data["build_type"] = 1
			assert !config.valid?

			@config_data["build_type"] = ''
			assert !config.valid?

			@config_data["build_type"] = 'invalid'
			assert !config.valid?

			@config_data.delete "build_type"
			assert !config.valid?
		end

		def test_invalid_channel
			@config_data["repos"]["test/repo"]["channel"] = 1
			assert !config.valid?

			@config_data["repos"]["test/repo"]["channel"] = ''
			assert !config.valid?
		end

		def test_invalid_token
			@config_data["repos"]["test/repo"]["token"] = 1
			assert !config.valid?

			@config_data["repos"]["test/repo"]["token"] = ''
			assert !config.valid?

			@config_data["repos"]["test/repo"].delete "token"
			assert !config.valid?
		end

		def test_port_is_optional
			@config_data.delete "port"
			assert config.valid?
		end

		def test_bind_is_optional
			@config_data.delete "bind"
			assert config.valid?
		end

		def test_channel_is_optional
			@config_data["repos"]["test/repo"].delete "channel"
			assert config.valid?
		end

		private

		def config
			Config.new(@config_data.to_yaml)
		end
	end
end