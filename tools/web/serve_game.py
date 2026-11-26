"""Serve the extracted Godot web game on the local computer."""
import argparse
import webbrowser
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class GameHandler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".wasm": "application/wasm",
        ".pck": "application/octet-stream",
        ".js": "application/javascript",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8115)
    parser.add_argument("--no-browser", action="store_true")
    options = parser.parse_args()
    folder = Path(__file__).resolve().parent
    if not (folder / "index.html").is_file():
        parser.exit(1, "Run this launcher from the extracted web build.\n")
    try:
        server = ThreadingHTTPServer(
            ("127.0.0.1", options.port),
            partial(GameHandler, directory=str(folder)),
        )
    except OSError as exc:
        parser.exit(1, f"Cannot start the local server on port {options.port}: {exc}\n")
    with server:
        url = f"http://127.0.0.1:{server.server_port}/"
        print(url, flush=True)
        if not options.no_browser:
            webbrowser.open(url)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
