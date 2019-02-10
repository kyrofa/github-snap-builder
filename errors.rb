class SnapBuilderError < StandardError
end

class MissingSnapcraftError < SnapBuilderError
	def initialize
		super("snapcraft must be installed and in the PATH")
	end
end

class MissingSnapFileError < SnapBuilderError
	def initialize(path)
		super("unable to find snap with path '#{path}'")
	end
end

class BuildFailedError < SnapBuilderError
	def initialize
		super("build failed")
	end
end

class TooManySnapsError < SnapBuilderError
	def initialize(paths)
		super("expected to find a single snap, found #{paths.length}: #{paths}")
	end
end