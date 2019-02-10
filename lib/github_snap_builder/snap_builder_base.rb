require 'open3'
require 'github_snap_builder'

module GithubSnapBuilder
	class SnapBuilderBase
		def initialize
			if find_executable('snapcraft').empty?
				raise MissingSnapcraftError
			end
		end

		private

		def snapcraft(*args)
			system('snapcraft', *args)
		end

		def find_executable(executable_name)
			output, status = Open3.capture2('which', executable_name)

			if status.exitstatus != 0
				output = ''
			end

			output.chop
		end
	end
end