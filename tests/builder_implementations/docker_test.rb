require 'fileutils'
require 'github_snap_builder/builder_implementations/docker'
require_relative '../test_helpers'

module GithubSnapBuilder
	class DockerBuilderTest < SnapBuilderBaseTest
		def setup
			@mock_image = mock('image')
			@mock_container = mock('container')
			@mock_logger = mock('logger')
			@mock_logger.stubs(:info)
			@mock_logger.stubs(:error)
			Docker.stubs(:validate_version!)
		end

		def test_docker_missing
			Docker.expects(:validate_version!).raises(Excon::Error::Socket)

			assert_raises DockerVersionError do
				DockerBuilder.new(@mock_logger, 'test-base')
			end
		end

		def test_build_success
			assert_build 0
		end

		def test_build_failure
			assert_raises DockerRunError do
				assert_build 1
			end
		end

		def test_release
			Docker::Image.expects(:create).with('fromImage' => 'kyrofa/github-snap-builder:test-base').returns(@mock_image)

			# Expect container based on image to be fired up
			@mock_image.expects(:id).returns('1234')
			Docker::Container.expects(:create).with(
				'Cmd' => ['sh', '-c', "snapcraft login --with /token && snapcraft push test.snap --release=test-channel"],
				'Image' => '1234',
				'Env' => ['SNAPCRAFT_MANAGED_HOST=yes'],
				'WorkingDir' => '/snapcraft',
				'HostConfig' => {
					'Binds' => ["/foo:/snapcraft"],
					'AutoRemove' => true,
				}
			).returns(@mock_container)
			@mock_container.expects(:store_file).with('/token', 'test-token')
			@mock_container.expects(:start)
			@mock_container.expects(:attach)
			@mock_container.expects(:wait).returns({'StatusCode' => 0})
			@mock_container.expects(:delete).with(force: true)

			builder = DockerBuilder.new(@mock_logger, 'test-base')
			builder.release("/foo/test.snap", "test-token", "test-channel")
		end

		private

		def assert_build(status_code)
			Docker::Image.expects(:create).with('fromImage' => 'kyrofa/github-snap-builder:test-base').returns(@mock_image)

			# Expect container based on image to be fired up
			@mock_image.expects(:id).returns('1234')
			Docker::Container.expects(:create).with(
				'Cmd' => ['sh', '-c', "apt update -qq && snapcraft"],
				'Image' => '1234',
				'Env' => ['SNAPCRAFT_MANAGED_HOST=yes'],
				'WorkingDir' => '/snapcraft',
				'HostConfig' => {
					'Binds' => ["test-project-dir:/snapcraft"],
					'AutoRemove' => true,
				}
			).returns(@mock_container)
			@mock_container.expects(:start)
			@mock_container.expects(:attach)
			@mock_container.expects(:wait).returns({'StatusCode' => status_code})
			@mock_container.expects(:delete).with(force: true)

			builder = DockerBuilder.new(@mock_logger, 'test-base')
			builder.build('test-project-dir')
		end
	end
end