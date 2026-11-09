"""Receives WhatsApp events from the bridge and appends them to data/events.jsonl."""
import hmac
import http.server
import json
import os
import sys
import time

from bridge import DATA, SETTINGS

PATH = "/hook/" + SETTINGS["HOOK_TOKEN"]
LOG = os.path.join(DATA, "events.jsonl")


class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        if not hmac.compare_digest(self.path, PATH):
            self.send_response(404)
            self.end_headers()
            return
        body = self.rfile.read(int(self.headers.get("Content-Length") or 0))
        try:
            event = json.loads(body)
        except ValueError:
            self.send_response(400)
            self.end_headers()
            return
        event["_received"] = time.strftime("%Y-%m-%d %H:%M:%S")
        fd = os.open(LOG, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
        with os.fdopen(fd, "a") as f:
            f.write(json.dumps(event) + "\n")
        self.send_response(200)
        self.end_headers()

    def log_message(self, *args):
        pass


host = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
http.server.ThreadingHTTPServer((host, int(SETTINGS["HOOK_PORT"])), Handler).serve_forever()
