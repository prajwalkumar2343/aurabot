"""
Base HTTP handler with CORS support.
"""

import json
import time
from datetime import datetime
from http.server import BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse

from api.auth import is_authorized, requires_auth
from api.cors import get_cors_headers
from config import MAX_REQUEST_BYTES


class RequestBodyError(ValueError):
    """Client request body could not be accepted."""

    def __init__(self, message: str, status: int = 400):
        super().__init__(message)
        self.status = status

RATE_LIMITS = {}
MAX_REQUESTS_PER_MINUTE = 60

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

        try:
            self.send_response(status)
            self.send_header("Content-Type", "application/json")

            for key, value in cors_headers.items():
                self.send_header(key, value)

            self.end_headers()
            self.wfile.write(json.dumps(data).encode())
        except (BrokenPipeError, ConnectionAbortedError):
            print("[WARN] Client disconnected before response could be sent")

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
        if hasattr(self, "_cached_json_body"):
            return self._cached_json_body

        try:
            content_length = int(self.headers.get("Content-Length", 0))
        except ValueError as exc:
            raise RequestBodyError("Invalid Content-Length") from exc

        if content_length > MAX_REQUEST_BYTES:
            raise RequestBodyError("Request body too large", 413)

        body = self.rfile.read(content_length).decode("utf-8") if content_length > 0 else ""
        try:
            self._cached_json_body = json.loads(body) if body else {}
        except json.JSONDecodeError as exc:
            raise RequestBodyError("Invalid JSON body") from exc
        return self._cached_json_body

    def get_client_ip(self):
        """Get client IP address."""
        forwarded = self.headers.get("X-Forwarded-For")
        if forwarded:
            return forwarded.split(",")[0].strip()
        return self.client_address[0]

    def check_rate_limit(self) -> bool:
        """Rate limit clients by IP using a simple rolling window."""
        client_ip = self.get_client_ip()
        current_time = time.time()

        reqs = RATE_LIMITS.get(client_ip, [])
        reqs = [req_time for req_time in reqs if current_time - req_time < 60]

        if len(reqs) >= MAX_REQUESTS_PER_MINUTE:
            self.send_json_response({"error": "Too Many Requests"}, 429)
            return False

        reqs.append(current_time)
        RATE_LIMITS[client_ip] = reqs
        return True

    def require_authorization(self, path: str = None) -> bool:
        """Require Authorization for protected routes when configured."""
        request_path = path or urlparse(self.path).path
        if not requires_auth(request_path):
            return True

        if not self.check_rate_limit():
            return False

        if is_authorized(self.headers):
            return True

        self.send_json_response({"error": "Unauthorized"}, 401)
        return False
