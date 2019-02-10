require 'fileutils'
require 'tmpdir'
require 'tempfile'
require 'rugged'
require 'github_snap_builder'
require 'github_snap_builder/snap_builder_base'
require 'github_snap_builder/snap'

module GithubSnapBuilder
	class SnapBuilder < SnapBuilderBase
		def initialize(clone_url, commit_sha)
			super()
			@clone_url = clone_url
			@commit_sha = commit_sha
		end

		def build
			Dir.mktmpdir do |tempdir|
				Dir.chdir(tempdir) do
					# First of all, clone the repository and get on the proper hash
					repo = Rugged::Repository.clone_at(@clone_url, '.',)
					repo.checkout(@commit_sha, {strategy: :force})

					# Factor out any snaps that existed before we build the new one
					existing_snaps = Dir.glob('*.snap')

					# Now build the snap
					snapcraft('--destructive-mode')

					# Grab the filename of the snap we just built
					new_snaps = Dir.glob('*.snap') - existing_snaps
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
					Snap.new snap_file.path
				end
			end
		end
	end
end