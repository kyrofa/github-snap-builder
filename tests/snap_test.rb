require 'github_snap_builder/snap'
require_relative 'test_helpers'

module GithubSnapBuilder
	class SnapTest < SnapBuilderBaseTest
		def setup
			Snap.any_instance.stubs(:find_executable).with('snapcraft').returns('/snap/bin/snapcraft')
		end

		def test_constructor
			snap_path = Tempfile.new(['test-snap', '.snap'])
			Snap.new(snap_path.path)
		end

		def test_missing_snap_file_is_error
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
			snap_path = Tempfile.new(['test-snap', '.snap'])

			snap = Snap.new(snap_path.path)
			snap.expects(:snapcraft).with("push", snap_path.path, '--release', 'test-channel').returns(true)
			Open3.expects(:capture3).with('snapcraft', 'login', '--with', '-', stdin_data: 'token').returns(['', '', 0])

			snap.push_and_release('token', 'test-channel')
		end

		def test_authentication_failure
			snap_path = Tempfile.new(['test-snap', '.snap'])

			snap = Snap.new(snap_path.path)
			Open3.expects(:capture3).with('snapcraft', 'login', '--with', '-', stdin_data: 'token').returns(['', 'bad error', 1])

			assert_raise AuthenticationError.new('bad error') do
				snap.push_and_release('token', 'test-channel')
			end
		end

		def test_push_and_release_failure
			snap_path = Tempfile.new(['test-snap', '.snap'])

			snap = Snap.new(snap_path.path)
			snap.expects(:snapcraft).with("push", snap_path.path, '--release', 'test-channel').returns(false)
			Open3.expects(:capture3).with('snapcraft', 'login', '--with', '-', stdin_data: 'token').returns(['', '', 0])

			assert_raise SnapPushError do
				snap.push_and_release('token', 'test-channel')
			end
		end
	end
end