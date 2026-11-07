"""Local stand-in for apt's HTTP proxy, for the setup-latex harness jobs.

apt is pointed at it with Acquire::http::Proxy and Acquire::https::Proxy, so
every request apt makes to a mirror, http or https, reaches it first:

  refuse   answers each request 503, and writes its request line to the log.
           A job that expects apt to contact no mirror asserts the log is
           empty.
  trickle  answers a GET 200 and sends one byte every 2 seconds, without
           end: a mirror that never fails, and never finishes. That is
           under apt's 15-second timeout, so only setup-latex's
           download-timeout-minutes can stop it. The response says it is
           5 MB long. In the harness apt failed at once both a length past
           its 10 MB limit for an InRelease file and a response with no
           length, so apt-get update ended in milliseconds instead of
           hanging. A CONNECT, for an https mirror, is refused 503 as in
           refuse mode.

Usage: python3 apt-proxy.py <refuse|trickle> <port> <logfile>
"""

import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MODE, PORT, LOG = sys.argv[1], int(sys.argv[2]), sys.argv[3]


class Handler(BaseHTTPRequestHandler):
    def record(self):
        with open(LOG, "a") as f:
            f.write(self.requestline + "\n")

    def refuse(self):
        self.record()
        self.send_response(503)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_CONNECT(self):
        self.refuse()

    def do_GET(self):
        if MODE != "trickle":
            self.refuse()
            return
        self.record()
        self.send_response(200)
        self.send_header("Content-Length", str(5 * 10**6))
        self.end_headers()
        try:
            while True:
                self.wfile.write(b"\0")
                self.wfile.flush()
                time.sleep(2)
        except (BrokenPipeError, ConnectionResetError):
            pass

    do_HEAD = refuse

    def log_message(self, *args):
        pass


if MODE not in ("refuse", "trickle"):
    sys.exit(f"unknown mode {MODE!r}: refuse or trickle")
open(LOG, "w").close()
ThreadingHTTPServer.daemon_threads = True
ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
