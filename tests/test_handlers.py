from github_snap_builder import _handlers

from unittest import mock


@mock.patch("github_snap_builder._handlers._authenticated_github_app", autospec=True)
@mock.patch("github_snap_builder._snap_builder.SnapBuilder", autospec=True)
def test_pull_request(mock_snap_builder, mock_app):
    build_mock = mock_snap_builder.return_value.build_and_release

    payload = dict(
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

    _handlers.handle_pull_request(payload)
    mock_snap_builder.assert_called_once_with(
        "https://example.com/test-base-repo",
        "https://example.com/test-head-repo",
        "1234",
    )
    build_mock.assert_called_once_with()
