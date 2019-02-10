ENV['APP_ENV'] = 'test'

require 'test/unit'
require 'rack/test'
require 'mocha/test_unit'
require 'github_snap_builder/server'

module GithubSnapBuilder
	class SnapBuilderBaseTest < Test::Unit::TestCase
		include Rack::Test::Methods

		def app
			Application
		end
	end
end