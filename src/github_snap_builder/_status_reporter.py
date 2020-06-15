class StatusReporter:
    def __init__(self, repo, commit_sha: str, log_url: str):
        self._repo = repo
        self._commit_sha = commit_sha
        self._log_url = log_url

    def pending(self, message: str) -> None:
        self._create_status("pending", message)

    def success(self, message: str) -> None:
        self._create_status("success", message)

    def failure(self, message: str) -> None:
        self._create_status("failure", message)

    def error(self, message: str) -> None:
        self._create_status("error", message)

    def _create_status(self, state: str, description: str) -> None:
        self._repo.create_status(self._commit_sha, state, self._log_url, description, "Snap Builder")