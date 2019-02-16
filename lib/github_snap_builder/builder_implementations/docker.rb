require 'date'
require 'docker'
require 'github_snap_builder'

module GithubSnapBuilder
	class DockerBuilder
		def build(base, project_directory)
			# Grab (or build) the image for this base
			image = get_image(base)

			# Create a new container, mounting in the current working directory
			# (which is the build directory), and run snapcraft on it.
			container = image.run(["snapcraft", "--destructive-mode"], {
				'Env' => ['SNAPCRAFT_MANAGED_HOST=yes'],
				'WorkingDir' => '/snapcraft',
				'HostConfig' => {
					'Binds' => ["#{project_directory}:/snapcraft"],
					'AutoRemove' => true,
				}
			})

			container.tap(&:start).attach do |stream, chunk|
				puts "#{stream}: #{chunk}"
			end

			# This shouldn't be necessary given the AutoRemove option, but it's
			# easy to ensure.
			container.delete(force: true)
		end

		private

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