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
		end

		def test_build_no_existing_image
			Docker::Image.expects(:get).with("github-snap-builder:test-base").raises(Docker::Error::NotFoundError)

			# Now expect a new image to be built and tagged
			assert_new_image
		end

		def test_build_existing_image
			Docker::Image.expects(:get).with("github-snap-builder:test-base").returns(@mock_image)
			@mock_image.expects(:run).with(["snapcraft", "--destructive-mode"], {
				'Env' => ['SNAPCRAFT_MANAGED_HOST=yes'],
				'WorkingDir' => '/snapcraft',
				'HostConfig' => {
					'Binds' => ["test-project-dir:/snapcraft"],
					'AutoRemove' => true,
				}
			}).returns(@mock_container)
			@mock_container.expects(:start)
			@mock_container.expects(:attach)
			@mock_container.expects(:delete).with(force: true)

			builder = DockerBuilder.new
			builder.build("test-base", "test-project-dir")
		end

		def test_build_old_image
			# Expect the old image to be fetched and then deleted
			Docker::Image.expects(:get).with("github-snap-builder:test-base").returns(@mock_old_image)
			@mock_old_image.expects(:remove).with(force: true)

			# Now expect a new image to be built and tagged
			assert_new_image
		end

		private

		def assert_new_image
			# Now expect a new image to be built and tagged
			dockerdir = File.join File.dirname(File.dirname(__dir__)), 'docker'
			Docker::Image.expects(:build_from_dir).with(dockerdir, {
				dockerfile: 'Dockerfile.test-base'
			}).returns(@mock_image)
			@mock_image.expects(:tag).with(repo: 'github-snap-builder', tag: 'test-base')

			@mock_image.expects(:run).with(["snapcraft", "--destructive-mode"], {
				'Env' => ['SNAPCRAFT_MANAGED_HOST=yes'],
				'WorkingDir' => '/snapcraft',
				'HostConfig' => {
					'Binds' => ["test-project-dir:/snapcraft"],
					'AutoRemove' => true,
				}
			}).returns(@mock_container)
			@mock_container.expects(:start)
			@mock_container.expects(:attach)
			@mock_container.expects(:delete).with(force: true)

			builder = DockerBuilder.new
			builder.build("test-base", "test-project-dir")
		end
	end
end