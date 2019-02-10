require_relative 'snap_builder_base'
require_relative 'errors'

class Snap < SnapBuilderBase
	def initialize(path)
		super()
		@path = path
		unless File.exist? path
			raise MissingSnapFileError, path
		end

		# So that the caller doesn't HAVE to call cleanup
		ObjectSpace.define_finalizer(self, self.class.cleanup(@path))
	end

	def push_and_release(token, channel)
		_, stderr, status = Open3.capture3(
			'snapcraft', 'login', '--with', '-', stdin_data: token)
		if status != 0
			raise AuthenticationError, stderr
		end

		unless snapcraft('push', @path, '--release', channel)
			raise SnapPushError
		end
	end

	def cleanup
		File.delete @path
	end

	def self.cleanup(path)
		proc { File.delete path }
	end
end