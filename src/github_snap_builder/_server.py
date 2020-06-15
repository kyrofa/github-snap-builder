import hmac

import flask

from . import _handlers

_APP = flask.Flask(__name__)

_event_handlers = {
    "pull_request": _handlers.handle_pull_request,
}


@_APP.route("/", methods=['GET', 'POST'])
def _root():
    if flask.request.method == "POST":
        _verify_webhook_signature(flask.request)
        _handle_post(flask.request)
        print('post')
        return "post"
        # # GitHub sends the secret key in the payload header
        # if utils.match_webhook_secret(request):
        # 	event = request.headers["X-GitHub-Event"]
        # 	app.logger.debug(f"Request Headers:\n{request.headers}")
        # 	app.logger.debug(f"Request body:\n{request.json}")
        # 	event_to_action = {
        # 		"pull_request": handlers.handle_pull_request,
        # 		"integration_installation": handlers.handle_integration_installation,
        # 		"integration_installation_repositories": handlers.handle_integration_installation_repo,
        # 		"installation_repositories": handlers.handle_integration_installation_repo,
        # 		"ping": handlers.handle_ping,
        # 		"issue_comment": handlers.handle_issue_comment,
        # 		"installation": handlers.handle_installation,
        # 	}
        # 	supported_event = event in event_to_action
        # 	if supported_event:
        # 		return event_to_action[event](request)
        # 	else:
        # 		return handlers.handle_unsupported_requests(request)
        # else:
        # 	app.logger.info("Received an unauthorized request")
        # 	return handlers.handle_unauthorized_requests()
    else:
        # Will be using this to get logs
        print('get')
        return "get"


def _main():
    _APP.run()


def _verify_webhook_signature(request):
    signature = request.headers.get('X-Hub-Signature')
    if not signature:
        flask.abort(403)

    sha_name, signature = signature.split('=')
    mac = hmac.new("test-secret".encode(), msg=request.data, digestmod=sha_name)

    if not hmac.compare_digest(str(mac.hexdigest()), str(signature)):
        flask.abort(403)


def _handle_post(request):
    event = request.headers.get('X-Github-Event')
    if not event:
        flask.abort(500)

    try:
        _event_handlers[event](flask.request.get_json())
    except KeyError:
        flask.abort(404)