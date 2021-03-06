require 'fileutils'
require 'github_snap_builder/snap_builder'
require_relative 'test_helpers'

module GithubSnapBuilder
	class SnapBuilderTest < SnapBuilderBaseTest
		def setup
			SnapBuilder.any_instance.stubs(:build_implementation).returns(FakeBuildImplementation.new('test-base'))
			@mock_logger = mock('logger')
			@mock_repo = mock('repo')
			@mock_remotes = mock('remotes')
			@mock_remote = mock('remote')
			Rugged::Repository.stubs(:clone_at).with do |url, dir|
				File.write(File.join(dir, 'snapcraft.yaml'), 'base: test-base')
				url == 'base-url'
			end.returns(@mock_repo)
			@mock_repo.stubs(:remotes).returns(@mock_remotes)
			@mock_remotes.stubs(:create).with('fork', 'head-url').returns(@mock_remote)
			@mock_remote.stubs(:fetch)
			@mock_repo.stubs(:checkout)
		end

		def test_constructor
			SnapBuilder.new(@mock_logger, 'base-url', 'head-url', 'test-sha', 'fake')
		end

		def test_build
			builder = SnapBuilder.new(@mock_logger, 'base-url', 'head-url', 'test-sha', 'fake')
			fake = FakeBuildImplementation.new('test-base', ['test.snap'])
			builder.stubs(:build_implementation).returns(fake)

			assert_instance_of String, builder.build
		end

		def test_build_no_snaps
			builder = SnapBuilder.new(@mock_logger, 'base-url', 'head-url', 'test-sha', 'fake')
			assert_raises BuildFailedError do
				builder.build
			end
		end

		def test_build_no_new_snaps
			mock_repo = mock('repo')
			Rugged::Repository.expects(:clone_at).with do |url, dir|
				url == 'base-url'
			end.returns(mock_repo)
			mock_repo.expects(:remotes).returns(@mock_remotes)
			@mock_remotes.expects(:create).with('fork', 'head-url').returns(@mock_remote)
			@mock_remote.expects(:fetch)
			mock_repo.expects(:checkout).with do |sha, opts|
				# This existed before the build, so it should be factored out
				FileUtils.touch('test.snap')
				sha == 'test-sha' && opts == {strategy: :force}
			end

			builder = SnapBuilder.new(@mock_logger, 'base-url', 'head-url', 'test-sha', 'fake')
			assert_raises BuildFailedError do
				builder.build
			end
		end

		def test_build_multiple_snaps_takes_latest
			mock_repo = mock('repo')
			Rugged::Repository.expects(:clone_at).with do |url, dir|
				url == 'base-url'
			end.returns(mock_repo)
			mock_repo.expects(:remotes).returns(@mock_remotes)
			@mock_remotes.expects(:create).with('fork', 'head-url').returns(@mock_remote)
			@mock_remote.expects(:fetch)
			mock_repo.expects(:checkout).with do |sha, opts|
				# This existed before the build, so it should be factored out
				FileUtils.touch('test1.snap')
				sha == 'test-sha' && opts == {strategy: :force}
			end

			builder = SnapBuilder.new(@mock_logger, 'base-url', 'head-url', 'test-sha', 'fake')
			builder.stubs(:build_implementation).returns(
				FakeBuildImplementation.new('test-base', ['test2.snap']))

			assert_instance_of String, builder.build
		end

		def test_build_multiple_snaps_built_error
			builder = SnapBuilder.new(@mock_logger, 'base-url', 'head-url', 'test-sha', 'fake')
			builder.stubs(:build_implementation).returns(
				FakeBuildImplementation.new('test-base', ['test1.snap', 'test2.snap']))

			assert_raises TooManySnapsError do
				builder.build()
			end
		end

		def test_supported_build_types
			assert_equal ["docker"], SnapBuilder.supported_build_types
		end
	end

	class FakeBuildImplementation
		attr_reader :base

		def initialize(base, snap_names=nil)
			@base = base
			@snap_names = snap_names
		end

		def build(project_directory)
			unless @snap_names.nil? || @snap_names.empty?
				@snap_names.each do |f|
					FileUtils.touch(File.join(project_directory, f))
				end
			end
		end
	end
end