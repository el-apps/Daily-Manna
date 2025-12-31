#!/usr/bin/env python3
"""Simple HTTP server with CORS support for Flutter web.

This server is needed to handle CORS headers when serving the Flutter web app
in production environments. Flutter web may load assets or make requests that
require proper CORS headers to function correctly.
"""

import http.server
import socketserver
import sys
from pathlib import Path


class CORSRequestHandler(http.server.SimpleHTTPRequestHandler):
    """HTTP request handler with CORS headers."""

    def end_headers(self):
        """Add CORS headers before ending the response."""
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        super().end_headers()

    def do_OPTIONS(self):
        """Handle OPTIONS requests for CORS preflight."""
        self.send_response(200)
        self.end_headers()


def main():
    """Start the CORS-enabled HTTP server."""
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    host = "0.0.0.0"

    with socketserver.TCPServer((host, port), CORSRequestHandler) as httpd:
        print(f"Serving on {host}:{port}")
        httpd.serve_forever()


if __name__ == "__main__":
    main()
