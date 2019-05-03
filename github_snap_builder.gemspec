
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "github_snap_builder/version"

Gem::Specification.new do |spec|
	spec.name          = "github_snap_builder"
	spec.version       = GithubSnapBuilder::VERSION
	spec.authors       = ["Kyle Fazzari"]
	spec.email         = ["kyrofa@ubuntu.com"]

	spec.summary       = "Github app that builds and releases snaps for each pull request."
	spec.homepage      = "https://github.com/kyrofa/github-snap-builder"
	spec.license       = "GPL-3.0"

	# Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
	# to allow pushing to a single host or delete this section to allow pushing to any host.
	if spec.respond_to?(:metadata)
		spec.metadata["homepage_uri"] = spec.homepage
		spec.metadata["source_code_uri"] = spec.homepage
	else
		raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
	end

	# Specify which files should be added to the gem when it is released.
	# The `git ls-files -z` loads the files in the RubyGem that have been added into git.
	spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
		`git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features|snap)/}) }
	end
	spec.executables   << "github_snap_builder"
	spec.executables   << "github_snap_builder_config_validator"
	spec.require_paths = ["lib"]

	spec.add_dependency 'sinatra', '~> 2.0'
	spec.add_dependency 'jwt', '~> 2.1'
	spec.add_dependency 'octokit', '~> 4.0'
	spec.add_dependency 'rugged', '~> 0.0'
	spec.add_dependency 'docker-api', '~> 1.34'

	spec.add_development_dependency "bundler", "~> 2.0"
	spec.add_development_dependency 'test-unit', '~> 3.2'
	spec.add_development_dependency 'rack-test', '~> 1.0'
	spec.add_development_dependency 'mocha', '~> 1.0'
	spec.add_development_dependency 'rake', '~> 12.3'
end
