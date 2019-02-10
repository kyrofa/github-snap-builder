require 'fileutils'
require_relative 'test_helpers'
require_relative '../snap_builder'

class SnapBuilderTest < SnapBuilderBaseTest
	def test_constructor
		SnapBuilder.any_instance.expects(:find_executable).with('snapcraft').returns('/snap/bin/snapcraft')
		SnapBuilder.new('foo', 'bar')
	end

	def test_missing_snapcraft_is_error
		SnapBuilder.any_instance.expects(:find_executable).with('snapcraft').returns('')
		assert_raise MissingSnapcraftError do
			SnapBuilder.new('foo', 'bar')
		end
	end

	def test_build
		SnapBuilder.any_instance.expects(:find_executable).with('snapcraft').returns('/snap/bin/snapcraft')
		Rugged::Repository.expects(:clone_at).with(
			'test-url', '.', {checkout_branch: 'test-sha'})
		builder = SnapBuilder.new('test-url', 'test-sha')
		builder.expects(:snapcraft).with() do
			FileUtils.touch('test.snap')
		end

		assert_instance_of Snap, builder.build()
	end

	def test_build_no_snaps
		SnapBuilder.any_instance.expects(:find_executable).with('snapcraft').returns('/snap/bin/snapcraft')
		Rugged::Repository.expects(:clone_at).with(
			'test-url', '.', {checkout_branch: 'test-sha'})
		builder = SnapBuilder.new('test-url', 'test-sha')
		builder.expects(:snapcraft).with()

		assert_raises BuildFailedError do
			builder.build()
		end
	end

	def test_build_no_new_snaps
		SnapBuilder.any_instance.expects(:find_executable).with('snapcraft').returns('/snap/bin/snapcraft')
		Rugged::Repository.expects(:clone_at).with('test-url', '.', {checkout_branch: 'test-sha'}) do
			# This existed before the build, so it should be factored out
			FileUtils.touch('test.snap')
		end

		builder = SnapBuilder.new('test-url', 'test-sha')
		builder.expects(:snapcraft).with()

		assert_raises BuildFailedError do
			builder.build()
		end
	end

	def test_build_multiple_snaps_takes_latest
		SnapBuilder.any_instance.expects(:find_executable).with('snapcraft').returns('/snap/bin/snapcraft')
		Rugged::Repository.expects(:clone_at).with('test-url', '.', {checkout_branch: 'test-sha'}) do
			FileUtils.touch('test1.snap')
		end
		builder = SnapBuilder.new('test-url', 'test-sha')
		builder.expects(:snapcraft).with() do
			FileUtils.touch('test2.snap')
		end

		assert_instance_of Snap, builder.build()
	end

	def test_build_multiple_snaps_built_error
		SnapBuilder.any_instance.expects(:find_executable).with('snapcraft').returns('/snap/bin/snapcraft')
		Rugged::Repository.expects(:clone_at).with(
			'test-url', '.', {checkout_branch: 'test-sha'})
		builder = SnapBuilder.new('test-url', 'test-sha')
		builder.expects(:snapcraft).with() do
			FileUtils.touch('test1.snap')
			FileUtils.touch('test2.snap')
		end

		assert_raises TooManySnapsError do
			builder.build()
		end
	end
end