ENV['APP_ENV'] = 'test'

require 'test/unit'
require 'rack/test'
require 'mocha/test_unit'
require_relative '../server.rb'

class SnapBuilderBaseTest < Test::Unit::TestCase
	include Rack::Test::Methods

	def app
		GHAapp
	end
end