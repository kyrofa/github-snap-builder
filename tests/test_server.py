import hmac

import github_snap_builder

from unittest import mock


def test_webhook_signature(client):
    mac = hmac.new("test-secret".encode(), digestmod="sha1")
    response = client.post("/", headers={"X-Hub-Signature": f"sha1={mac.hexdigest()}"})

    # Status code will be 500 since we're not sending any data, but as long as
    # it's not 4xx we're good
    assert response.status_code == 500


def test_no_webhook_signature(client):
    response = client.post("/")
    assert response.status_code == 403

    response = client.post("/", headers={"X-Hub-Signature": "sha1=nope"})
    assert response.status_code == 403


@mock.patch("github_snap_builder._server._verify_webhook_signature", autospec=True)
def test_unhandled_event(mock_verify, client):
    response = client.post("/", headers={"X-Github-Event": "unhandled"})
    assert response.status_code == 404


@mock.patch("github_snap_builder._server._verify_webhook_signature", autospec=True)
def test_handler_called(mock_verify, client):
    mock_handler = mock.MagicMock()
    github_snap_builder._server._event_handlers["test_event"] = mock_handler

    json = dict(
        installation=dict(id=1),
        pull_request=dict(
            number=1,
            base=dict(
                repo=dict(
                    full_name="test-owner/test-base-repo",
                    html_url="https://example.com/test-base-repo",
                )
            ),
            head=dict(
                sha="1234", repo=dict(html_url="https://example.com/test-head-repo")
            ),
        ),
    )

    response = client.post("/", headers={"X-Github-Event": "test_event"}, json=json,)
    assert response.status_code == 200
    mock_handler.assert_called_once_with(json)
