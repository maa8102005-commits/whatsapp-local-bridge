"""Shared helpers: loads .env and calls the local bridge."""
import json
import os
import urllib.request

ROOT = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(ROOT, "data")


def load_settings():
    settings = {}
    with open(os.path.join(ROOT, ".env")) as f:
        for line in f:
            if "=" in line and not line.startswith("#"):
                key, value = line.strip().split("=", 1)
                settings[key] = value
    return settings


SETTINGS = load_settings()
KEY = SETTINGS["WAHA_API_KEY"]
BASE = "http://127.0.0.1:" + SETTINGS["WAHA_PORT"]


def api(path, body=None, timeout=60):
    headers = {"X-Api-Key": KEY}
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(BASE + path, data=data, headers=headers)
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.load(response)
