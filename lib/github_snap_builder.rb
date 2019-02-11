require 'github_snap_builder/version'

module GithubSnapBuilder
	class Error < StandardError; end

	class MissingSnapcraftError < Error
		def initialize
			super("snapcraft must be installed and in the PATH")
		end
	end

	class MissingSnapFileError < Error
		def initialize(path)
			super("unable to find snap with path '#{path}'")
		end
	end

	class BuildFailedError < Error
		def initialize
			super("build failed")
		end
	end

	class TooManySnapsError < Error
		def initialize(paths)
			super("expected to find a single snap, found #{paths.length}: #{paths}")
		end
	end

	class SnapPushError < Error
		def initialize
			super("failed to push/release snap")
		end
	end

	class AuthenticationError < Error
		def initialize(message)
			super("failed to authenticate: #{message}")
		end
	end

	class ConfigurationError < Error; end

	class ConfigurationFieldError < ConfigurationError
		def initialize(field)
			super("configuration field is invalid: '#{field}'")
		end
	end
end
