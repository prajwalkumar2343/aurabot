"""
Base HTTP handler with CORS support.
"""

import json
from datetime import datetime
from http.server import BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse

from api.cors import is_allowed_origin, get_cors_headers


class BaseHandler(BaseHTTPRequestHandler):
    """Base HTTP handler with common CORS and response handling."""

    def log_message(self, format, *args):
        """Log HTTP requests."""
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {format % args}")

    def _get_origin(self):
        """Get the Origin header from the request."""
        return self.headers.get("Origin", "")

    def send_json_response(self, data: dict, status: int = 200):
        """Send a JSON response with CORS headers."""
        origin = self._get_origin()
        cors_headers = get_cors_headers(origin)

        self.send_response(status)
        self.send_header("Content-Type", "application/json")

        for key, value in cors_headers.items():
            self.send_header(key, value)

        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

    def do_OPTIONS(self):
        """Handle CORS preflight requests."""
        origin = self._get_origin()
        cors_headers = get_cors_headers(origin)

        self.send_response(200)

        for key, value in cors_headers.items():
            self.send_header(key, value)

        self.end_headers()

    def parse_query(self):
        """Parse query string from URL."""
        parsed = urlparse(self.path)
        return parse_qs(parsed.query)

    def parse_json_body(self):
        """Parse JSON body from request."""
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length).decode() if content_length > 0 else ""
        return json.loads(body) if body else {}

    def get_client_ip(self):
        """Get client IP address."""
        forwarded = self.headers.get("X-Forwarded-For")
        if forwarded:
            return forwarded.split(",")[0].strip()
        return self.client_address[0]
