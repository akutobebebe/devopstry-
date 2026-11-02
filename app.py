"""Tiny service for practicing deployment and operations."""

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/":
            self.respond(200, {"message": "Hello from devops-playground"})
        elif self.path == "/health":
            self.respond(200, {"status": "ok"})
        elif self.path == "/info":
            self.respond(200, {"environment": os.getenv("APP_ENV", "local")})
        else:
            self.respond(404, {"error": "not found"})

    def respond(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    print(f"Listening on http://localhost:{port}", flush=True)
    server.serve_forever()
