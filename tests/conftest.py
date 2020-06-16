import pytest

from github_snap_builder import _server


@pytest.fixture
def client():
    _server._APP.config["TESTING"] = True
    with _server._APP.test_client() as c:
        yield c
