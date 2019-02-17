require 'date'
require 'shellwords'
require 'docker'
require 'github_snap_builder'

module GithubSnapBuilder
	class DockerBuilder
		def initialize(base)
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
			# Grab (or build) the image for this base
			image = get_image(@base)
			options = {'Image' => image.id, 'Cmd' => command}.merge(options)

			begin
				# Create a new container, mounting in the current working directory
				# (which is the build directory), and run snapcraft on it.
				container = Docker::Container.create options

				yield container if block_given?

				container.tap(&:start).attach do |stream, chunk|
					puts "#{stream}: #{chunk}"
				end

				if container.wait()['StatusCode'] != 0
					raise DockerRunError, command
				end
			ensure
				# This shouldn't be necessary given the AutoRemove option, but it's
				# easy to ensure.
				container.delete(force: true)
			end
		end

		def dockerdir
			gem_root = File.dirname(File.dirname(File.dirname(__dir__)))
			File.join(gem_root, 'docker')
		end

		def dockerfile_name(base)
			"Dockerfile.#{base}"
		end

		def get_image(base)
			repo = 'github-snap-builder'
			tag = base

			begin
				image = Docker::Image.get("#{repo}:#{tag}")
				created = DateTime.parse(image.info["Created"])

				# The image is only considered valid if it's under a day old
				if DateTime.now < created.next_day
					return image
				else
					image.remove(force: true)
				end
			rescue Docker::Error::NotFoundError
				# Do nothing
			end

			# If we got here, then either no image exists, or the one that did
			# was too old and was pruned. Either way, create a new one.
			image = Docker::Image.build_from_dir dockerdir, {
				dockerfile: dockerfile_name(base)
			}
			image.tag(repo: repo, tag: tag)
			return image
		end
	end
end