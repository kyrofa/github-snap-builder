require 'date'
require 'shellwords'
require 'docker'
require 'github_snap_builder'

module GithubSnapBuilder
	class DockerBuilder
		def initialize(logger, base)
			@logger = logger
			@base = base

			begin
				Docker.validate_version!
			rescue Excon::Error::Socket
				raise DockerVersionError
			end
		end

		def build(project_directory)
			run(['sh', '-c', "apt update -qq && snapcraft --destructive-mode"], {
				'Env' => ['SNAPCRAFT_MANAGED_HOST=yes'],
				'WorkingDir' => '/snapcraft',
				'HostConfig' => {
					'Binds' => ["#{project_directory}:/snapcraft"],
					'AutoRemove' => true,
				}
			})
		end

		def release(snap_path, token, channel)
			run(['sh', '-c', "snapcraft login --with /token && snapcraft push #{File.basename(snap_path).shellescape} --release=#{channel.shellescape}"], {
				'Env' => ['SNAPCRAFT_MANAGED_HOST=yes'],
				'WorkingDir' => '/snapcraft',
				'HostConfig' => {
					'Binds' => ["#{File.dirname(snap_path)}:/snapcraft"],
					'AutoRemove' => true,
				}
			}) do |container|
				container.store_file("/token", token)
			end
		end

		private

		def run(command, options)
			# Grab the image for this base
			@logger.info 'Fetching image...'
			image = get_image(@base)
			options = {'Image' => image.id, 'Cmd' => command}.merge(options)

			begin
				# Create a new container
				@logger.info 'Provisioning...'
				container = Docker::Container.create options

				# Give called the change to mess with container before running
				# anything
				yield container if block_given?

				# Fire up the container and stream its logs
				@logger.info 'Firing up build...'
				container.tap(&:start).attach do |stream, chunk|
					if stream == :stdout
						@logger.info chunk
					else
						@logger.error chunk
					end
				end

				if container.wait()['StatusCode'] != 0
					@logger.error "Build exited non-zero: aborting"
					raise DockerRunError, command
				end
			ensure
				# This shouldn't be necessary given the AutoRemove option, but it's
				# easy to ensure.
				container.delete(force: true)
			end
		end

		def get_image(base)
			Docker::Image.create('fromImage' => "kyrofa/github-snap-builder:#{base}")
		end
	end
end