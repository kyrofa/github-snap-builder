require_relative 'test_helpers'
require_relative '../snap'

class SnapTest < SnapBuilderBaseTest
	def test_constructor
		Snap.any_instance.expects(:find_executable).with('snapcraft').returns('/snap/bin/snapcraft')
		snap_path = Tempfile.new(['test-snap', '.snap'])
		Snap.new(snap_path.path)
	end

	def test_missing_snap_file_is_error
		Snap.any_instance.expects(:find_executable).with('snapcraft').returns('/snap/bin/snapcraft')
		assert_raise MissingSnapFileError.new("non-existent.snap") do
			Snap.new("non-existent.snap")
		end
	end

	def test_missing_snapcraft_is_error
		Snap.any_instance.expects(:find_executable).with('snapcraft').returns('')
		snap_path = Tempfile.new(['test-snap', '.snap'])
		assert_raise MissingSnapcraftError do
			Snap.new(snap_path.path)
		end
	end

	def test_push_and_release
		Snap.any_instance.expects(:find_executable).with('snapcraft').returns('/snap/bin/snapcraft')
		snap_path = Tempfile.new(['test-snap', '.snap'])

		snap = Snap.new(snap_path.path)
		snap.expects(:snapcraft).with("push", snap_path.path, '--release', 'test-channel').returns(true)

		snap.push_and_release('test-channel')
	end

	def test_push_and_release_failure
		Snap.any_instance.expects(:find_executable).with('snapcraft').returns('/snap/bin/snapcraft')
		snap_path = Tempfile.new(['test-snap', '.snap'])

		snap = Snap.new(snap_path.path)
		snap.expects(:snapcraft).with("push", snap_path.path, '--release', 'test-channel').returns(false)

		assert_raise SnapPushError do
			snap.push_and_release('test-channel')
		end
	end
end