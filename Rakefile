require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
	if ENV['TEST'].nil? or ENV['TEST'].empty?
		t.pattern = "tests/**/*_test.rb"
	else
		t.pattern = ENV['TEST']
	end
end

task default: :test