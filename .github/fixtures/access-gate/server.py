"""Local stand-in for a Cloudflare Access gate, for the deploy-cloudflare harness jobs.

Each path answers the way one real configuration would, so the probe can be run
against every shape it must tell apart without a Cloudflare account:

  /gated/...      302 to the team's login domain (a correctly gated Worker)
  /wrong-org/...  302 to a different *.cloudflareaccess.com (wrong Access org)
  /public/...     200 with content (a public site, or the alarm case for a
                  private one)
  /same-host/...  307 back to this host (asset html_handling, not Access)
  /no-location    302 with no Location header
  /missing        404 (no Worker on this hostname)
  /broken         500 (retried by the probe, then fails)
  /mixed-case     302 to the team domain in mixed case with an explicit :443
  /userinfo       302 whose real host is not the team domain, hidden behind
                  `\\@team-domain` userinfo

A request whose Host starts with `harness-<shape>.` is answered as
/<shape><path>, so that a workers.dev hostname such as
harness-gated.<subdomain>.workers.dev, pointed at this server in /etc/hosts,
answers like that shape on every path. That is how the action itself, which
only ever requests workers.dev hostnames, is run against a gated and a public
Worker.

Usage: python3 server.py <port> [<certfile> <keyfile>]   (TLS with both files)
"""

import ssl
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TEAM = "https://quantecon-harness.cloudflareaccess.com"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path
        label = self.headers.get("Host", "").split(".", 1)[0]
        if label.startswith("harness-"):
            path = "/" + label[len("harness-"):] + path
        if path.startswith("/gated"):
            self.reply(302, {"Location": f"{TEAM}/cdn-cgi/access/login/site?redirect_url={path}"})
        elif path.startswith("/wrong-org"):
            self.reply(302, {"Location": "https://someone-else.cloudflareaccess.com/cdn-cgi/access/login/site"})
        elif path.startswith("/public"):
            self.reply(200, {"Content-Type": "text/html"}, b"<h1>private report</h1>")
        elif path.startswith("/same-host"):
            self.reply(307, {"Location": "/public/"})
        elif path == "/no-location":
            self.reply(302, {})
        elif path == "/broken":
            self.reply(500, {})
        elif path == "/userinfo":
            self.reply(302, {"Location": "https://evil.example\\@quantecon-harness.cloudflareaccess.com/"})
        elif path == "/mixed-case":
            self.reply(302, {"Location": "https://QuantEcon-Harness.CloudflareAccess.com:443/cdn-cgi/access/login/site"})
        else:
            self.reply(404, {})

    def reply(self, code, headers, body=b""):
        self.send_response(code)
        for name, value in headers.items():
            self.send_header(name, value)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        # No headers yet when the request line itself was malformed.
        host = self.headers.get("Host", "") if getattr(self, "headers", None) else ""
        sys.stderr.write(f"server: {host} " + (fmt % args) + "\n")


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Handler)
    if len(sys.argv) == 4:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(sys.argv[2], sys.argv[3])
        server.socket = context.wrap_socket(server.socket, server_side=True)
    server.serve_forever()
