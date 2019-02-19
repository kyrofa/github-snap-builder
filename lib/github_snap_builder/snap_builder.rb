require 'fileutils'
require 'tmpdir'
require 'tempfile'
require 'yaml'
require 'rugged'
require 'github_snap_builder'

Dir[File.join(__dir__, 'builder_implementations', '*.rb')].each {|file| require file }

module GithubSnapBuilder
	class SnapBuilder
		def initialize(logger, base_url, head_url, commit_sha, build_type)
			@logger = logger
			@base_url = base_url
			@head_url = head_url
			@commit_sha = commit_sha
			@build_type = build_type
			@base = 'core16'
		end

		def build
			Dir.mktmpdir do |tempdir|
				# First of all, clone the repository and get on the proper hash. Make
				# sure to include the base repo so `git describe` has meaning.
				repo = Rugged::Repository.clone_at(@base_url, tempdir)
				remote = repo.remotes.create('fork', @head_url)
				remote.fetch
				repo.checkout(@commit_sha, {strategy: :force})

				# Before we can actually build the snap, we must first determine the
				# base to use. The default is "core".
				snapcraft_yaml = snapcraft_yaml_location(tempdir)
				@base = YAML.safe_load(File.read(snapcraft_yaml)).fetch("base", @base)
				if @base == "core"
					@base = "core16"
				end

				# Factor out any snaps that existed before we build the new one
				snaps_glob = File.join(tempdir, '*.snap')
				existing_snaps = Dir.glob(snaps_glob)

				# Now build the snap
				build_implementation.build(tempdir)

				# Grab the filename of the snap we just built
				new_snaps = Dir.glob(snaps_glob) - existing_snaps
				if new_snaps.empty?
					raise BuildFailedError
				elsif new_snaps.length > 1
					raise TooManySnapsError, new_snaps
				end

				# The directory we're in right now will be removed shortly. Copy the
				# snap somewhere that will live forever, and hand it to the Snap class
				# (which will remove it when it's done with it).
				snap_file = Tempfile.create [@commit_sha, '.snap']
				FileUtils.cp new_snaps[0], snap_file
				snap_file.path
			end
		end

		def release(snap_path, token, channel)
			build_implementation.release(snap_path, token, channel)
		end

		def self.supported_build_types
			Dir[File.join(__dir__, 'builder_implementations', '*.rb')].collect do |f|
				File.basename(f, File.extname(f))
			end
		end

		private

		def build_implementation
			GithubSnapBuilder.const_get("#{@build_type.capitalize}Builder").new(@logger, @base)
		end

		def snapcraft_yaml_location(project_dir)
			["snapcraft.yaml", ".snapcraft.yaml", File.join("snap", "snapcraft.yaml")].each do |f|
				path = File.join(project_dir, f)
				if File.file? path
					return path
				end
			end

			raise MissingSnapcraftYaml
		end
	end
end