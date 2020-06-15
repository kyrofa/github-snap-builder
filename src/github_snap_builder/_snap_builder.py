import contextlib
import glob
import pathlib
import subprocess
import tempfile

import git


class SnapBuilder:
    def __init__(self, base_url, head_url, commit_sha):
        self._base_url = base_url
        self._head_url = head_url
        self._commit_sha = commit_sha

    def build_and_release(self):
        with _cloned_git_repo(self._base_url, self._head_url, self._commit_sha) as directory:
            # Build the snaps
            subprocess.check_call(['snapcraft', 'remote-build'], cwd=directory)

            # Release the snaps
            snaps = glob.glob(pathlib.Path(directory) / "*.snap")
            if not snaps:
                print('No snaps found')
                return

            for snap in snaps:
                subprocess.check_call(['snapcraft', 'upload', snap, '--release=beta/pr-foo'])


@contextlib.contextmanager
def _cloned_git_repo(base_url, head_url, commit_sha):
    with tempfile.TemporaryDirectory() as tmpdir:
        # Clone from base so `git describe` has meaning
        repo = git.Repo.clone_from(base_url, tmpdir)

        # Add head as a remote and fetch it
        git.Remote.add(repo, "fork", head_url).fetch()

        # Now make sure we're on the proper commit
        repo.head.reference = commit_sha
        repo.head.reset(index=True, working_tree=True)

        yield tmpdir