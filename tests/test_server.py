import hmac

from unittest import mock

def test_webhook_signature(client):
    mac = hmac.new("test-secret".encode(), digestmod='sha1')
    response = client.post('/', headers={'X-Hub-Signature': f'sha1={mac.hexdigest()}'})

    # Status code will be 500 since we're not sending any data, but as long as
    # it's not 4xx we're good
    assert response.status_code == 500


def test_no_webhook_signature(client):
    response = client.post('/')
    assert response.status_code == 403

    response = client.post('/', headers={'X-Hub-Signature': f'sha1=nope'})
    assert response.status_code == 403


@mock.patch('github_snap_builder._server._verify_webhook_signature', autospec=True)
def test_unhandled_event(mock_verify, client):
    response = client.post('/', headers={'X-Github-Event': "unhandled"})
    assert response.status_code == 404


@mock.patch('github_snap_builder._server._verify_webhook_signature', autospec=True)
@mock.patch('github_snap_builder._handlers._authenticated_github_app', autospec=True)
@mock.patch('github_snap_builder._snap_builder.SnapBuilder', autospec=True)
def test_pull_request(mock_snap_builder, mock_app, mock_verify, client):
    build_mock = mock_snap_builder.return_value.build_and_release

    response = client.post('/', headers={'X-Github-Event': "pull_request"}, json=dict(
        installation=dict(id=1),
        pull_request=dict(
            number=1,
            base=dict(repo=dict(full_name='test-owner/test-base-repo', html_url="https://example.com/test-base-repo")),
            head=dict(sha="1234", repo=dict(html_url="https://example.com/test-head-repo")),
        )
    ))
    assert response.status_code == 200
    mock_snap_builder.assert_called_once_with('https://example.com/test-base-repo', 'https://example.com/test-head-repo', '1234')
    build_mock.assert_called_once_with()