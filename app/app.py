"""
Tiny demo web service used as the "workload" for the container security demo.

The application itself is intentionally trivial - the point of this project
is the container build/scan pipeline (Trivy + Dockle), not the app logic.
"""

from __future__ import annotations

import datetime
import platform

from flask import Flask, jsonify

app = Flask(__name__)


@app.get("/")
def hello() -> "flask.Response":
    """Basic greeting endpoint."""
    return jsonify(
        message="Hello from the container-security-scan demo app!",
        author="Dileep Kumar Tamminana",
    )


@app.get("/healthz")
def healthz() -> "flask.Response":
    """
    Health check endpoint.

    Used by the Dockerfile HEALTHCHECK instruction so the container runtime
    can detect a hung or unresponsive process.
    """
    return jsonify(
        status="ok",
        time=datetime.datetime.utcnow().isoformat() + "Z",
        python=platform.python_version(),
    )


if __name__ == "__main__":
    # Bind to 0.0.0.0 inside the container so the port mapping works;
    # debug is left off (default) so this is safe-ish for a demo image.
    app.run(host="0.0.0.0", port=8080)
