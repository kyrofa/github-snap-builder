require 'fileutils'
require 'github_snap_builder/builder_implementations/docker'
require_relative '../test_helpers'

module GithubSnapBuilder
	class DockerBuilderTest < SnapBuilderBaseTest
		def setup
			@mock_image = mock('image')
			@mock_image.stubs(:info).returns({'Created' => DateTime.now.to_s})

			@mock_old_image = mock('image')
			@mock_old_image.stubs(:info).returns({'Created' => DateTime.now.prev_day.prev_day.to_s})

			@mock_container = mock('container')
			Docker.stubs(:validate_version!)
		end

		def test_docker_missing
			Docker.expects(:validate_version!).raises(Excon::Error::Socket)

			assert_raises DockerVersionError do
				DockerBuilder.new('test-base')
			end
		end

		def test_build_no_existing_image
			Docker::Image.expects(:get).with("github-snap-builder:test-base").raises(Docker::Error::NotFoundError)

			# Now expect a new image to be built and tagged
			assert_image_created
			assert_successful_build
		end

		def test_build_old_image
			# Expect the old image to be fetched and then deleted
			Docker::Image.expects(:get).with("github-snap-builder:test-base").returns(@mock_old_image)
			@mock_old_image.expects(:remove).with(force: true)

			# Now expect a new image to be built and tagged
			assert_image_created
			assert_successful_build
		end

		def test_build_existing_image
			Docker::Image.expects(:get).with("github-snap-builder:test-base").returns(@mock_image)
			assert_successful_build
		end

		def test_build_failure
			Docker::Image.expects(:get).with("github-snap-builder:test-base").returns(@mock_image)

			# Expect container based on image to be fired up
			@mock_image.expects(:id).returns('1234')
			Docker::Container.expects(:create).with(
				'Cmd' => ['sh', '-c', "apt update -qq && snapcraft --destructive-mode"],
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

			# Mock the failure, but ensure container is still deleted
			@mock_container.expects(:wait).returns({'StatusCode' => 1})
			@mock_container.expects(:delete).with(force: true)

			builder = DockerBuilder.new('test-base')
			assert_raises DockerRunError do
				builder.build('test-project-dir')
			end
		end

		def test_release
			Docker::Image.expects(:get).with("github-snap-builder:test-base").returns(@mock_image)

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

			builder = DockerBuilder.new('test-base')
			builder.release("/foo/test.snap", "test-token", "test-channel")
		end

		private

		def assert_image_created
			# Now expect a new image to be built and tagged
			dockerdir = File.join File.dirname(File.dirname(__dir__)), 'docker'
			Docker::Image.expects(:build_from_dir).with(dockerdir, {
				dockerfile: 'Dockerfile.test-base'
			}).returns(@mock_image)
			@mock_image.expects(:tag).with(repo: 'github-snap-builder', tag: 'test-base')
		end

		def assert_successful_build
			# Expect container based on image to be fired up
			@mock_image.expects(:id).returns('1234')
			Docker::Container.expects(:create).with(
				'Cmd' => ['sh', '-c', "apt update -qq && snapcraft --destructive-mode"],
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
			@mock_container.expects(:wait).returns({'StatusCode' => 0})
			@mock_container.expects(:delete).with(force: true)

			builder = DockerBuilder.new('test-base')
			builder.build('test-project-dir')
		end
	end
end