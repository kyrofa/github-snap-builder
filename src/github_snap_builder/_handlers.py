import github3

from . import _snap_builder


def handle_pull_request(payload):
    pull_request_payload = payload["pull_request"]
    # pr_number = pull_request_payload["number"]
    owner, repo = pull_request_payload["base"]["repo"]["full_name"].split("/")

    head_url = pull_request_payload["head"]["repo"]["html_url"]
    base_url = pull_request_payload["base"]["repo"]["html_url"]
    commit_sha = pull_request_payload["head"]["sha"]

    app = _authenticated_github_app(payload)
    repo = app.repository(owner, repo)

    # status_reporter = _status_reporter.StatusReporter(
    #     repo, commit_sha, "http://example.com"
    # )
    builder = _snap_builder.SnapBuilder(base_url, head_url, commit_sha)
    builder.build_and_release()


def _authenticated_github_app(payload):
    app = github3.GitHub()

    with open(
        "/home/kyrofa/Downloads/snap-builder.2020-06-13.private-key.pem", "rb"
    ) as f:
        key = f.read()

    app.login_as_app_installation(key, 68748, payload["installation"]["id"])

    return app
