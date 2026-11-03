"""Tiny service for practicing deployment and operations."""

import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


PAGE = """<!doctype html>
<html lang="uk">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>DevOps Playground</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 600px; margin: 12vh auto; padding: 0 24px; }
    button { padding: 12px 18px; font: inherit; cursor: pointer; }
    #result { margin-top: 20px; }
  </style>
</head>
<body>
  <h1>DevOps Playground</h1>
  <p>Натисни кнопку, щоб перевірити сервер. Відкрий консоль браузера, щоб побачити HTTP-статус.</p>
  <button id="check" type="button">Перевірити /health</button>
  <p id="result" role="status"></p>
  <script>
    document.getElementById('check').addEventListener('click', async () => {
      const result = document.getElementById('result');
      try {
        const response = await fetch('/health');
        console.log(response.status);
        result.textContent = `HTTP ${response.status}`;
      } catch (error) {
        console.error(error);
        result.textContent = 'Немає з’єднання із сервером';
      }
    });
  </script>
</body>
</html>
"""


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/":
            self.respond_html(PAGE)
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

    def respond_html(self, page):
        body = page.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    port = int(os.getenv("PORT", "8080"))
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    print(f"Listening on http://localhost:{port}", flush=True)
    server.serve_forever()
