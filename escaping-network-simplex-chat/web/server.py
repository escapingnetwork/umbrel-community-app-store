#!/usr/bin/env python3
"""
SimpleX Gateway Web Server
- Serves the static dashboard
- Provides /api/address that talks to the local simplex-chat JSON API
  to return the current user's contact link.
"""

import asyncio
import base64
import io
import json
import os
import time
from http.server import HTTPServer, SimpleHTTPRequestHandler
from threading import Thread
import qrcode
import websockets

WEB_DIR = "/app/web"
DAEMON_WS = "ws://127.0.0.1:5226"

# Cache the address for a while
_address_cache = {"address": None, "qr_svg": None, "timestamp": 0}
CACHE_TTL = 30  # seconds


async def get_my_address():
    """Connect to local daemon and ask for our contact address."""
    try:
        async with websockets.connect(DAEMON_WS, open_timeout=3) as ws:
            # Send command to show our address
            corr_id = str(int(time.time() * 1000))
            cmd = {
                "corrId": corr_id,
                "cmd": "/address"
            }
            await ws.send(json.dumps(cmd))

            # Wait for response (the daemon usually replies with a string containing the address)
            async for message in ws:
                try:
                    data = json.loads(message)
                    if data.get("corrId") == corr_id:
                        resp = data.get("resp", {})
                        # The response can be a string or structured
                        if isinstance(resp, str):
                            # Try to extract simplex: link
                            if "simplex:" in resp or "https://simplex.chat/contact" in resp:
                                return resp.strip()
                        elif isinstance(resp, dict):
                            # Sometimes it's under 'user' or other keys
                            for v in resp.values():
                                if isinstance(v, str) and ("simplex:" in v or "contact#" in v):
                                    return v.strip()
                except Exception:
                    pass
                # If we got a plain string response containing the link
                if isinstance(message, str) and ("simplex:" in message or "contact#" in message):
                    return message.strip()
    except Exception as e:
        print(f"[server] Failed to get address from daemon: {e}")
    return None


def generate_qr_svg(address: str) -> str:
    """Generate a clean SVG QR code as a data URL."""
    if not address:
        return ""
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=8,
        border=2,
    )
    qr.add_data(address)
    qr.make(fit=True)

    img = qr.make_image(fill_color="black", back_color="white")

    # Use SVG
    svg_buffer = io.StringIO()
    img.save(svg_buffer, kind='SVG')
    svg_str = svg_buffer.getvalue()

    # Make it a data URL
    svg_base64 = base64.b64encode(svg_str.encode('utf-8')).decode('ascii')
    return f"data:image/svg+xml;base64,{svg_base64}"


def get_cached_address():
    now = time.time()
    if _address_cache["address"] and (now - _address_cache["timestamp"] < CACHE_TTL):
        return _address_cache["address"], _address_cache["qr_svg"]

    try:
        loop = asyncio.new_event_loop()
        address = loop.run_until_complete(get_my_address())
        loop.close()
    except Exception:
        address = None

    qr_svg = generate_qr_svg(address) if address else ""

    if address:
        _address_cache["address"] = address
        _address_cache["qr_svg"] = qr_svg
        _address_cache["timestamp"] = now

    return address, qr_svg


class GatewayHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def do_GET(self):
        if self.path == "/api/address":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()

            address, qr_svg = get_cached_address()
            data = {
                "address": address,
                "qr_svg": qr_svg,
                "ready": address is not None
            }
            self.wfile.write(json.dumps(data).encode())
            return

        # Default static file serving
        super().do_GET()

    def log_message(self, format, *args):
        # Reduce noise
        pass


def run_server(port=8080):
    server = HTTPServer(("", port), GatewayHandler)
    print(f"[server] Serving on port {port}")
    server.serve_forever()


if __name__ == "__main__":
    run_server()