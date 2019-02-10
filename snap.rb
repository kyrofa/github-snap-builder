require_relative 'snap_builder_base'

class Snap < SnapBuilderBase
	def initialize(path)
		super()
		@path = path
		unless File.exist? path
			raise MissingSnapFileError.new(path)
		end

		# So that the caller doesn't HAVE to call cleanup
		ObjectSpace.define_finalizer( self, self.class.cleanup(@path) )
	end

	def push_and_release(channel)
		snapcraft('push', @path, '--release', channel)
	end

	def cleanup
		File.delete @path
	end

	def self.cleanup(path)
		proc { File.delete path }
	end
end