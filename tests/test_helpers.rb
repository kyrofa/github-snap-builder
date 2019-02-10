require 'test/unit'
require 'rack/test'
require 'mocha/test_unit'
require_relative '../server.rb'

set :environment, :test

class SnapBuilderBaseTest < Test::Unit::TestCase
	include Rack::Test::Methods

	def app
		GHAapp
	end
end