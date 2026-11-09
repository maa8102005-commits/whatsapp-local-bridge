"""Waits for new messages from the given chats, prints them as JSON lines (saving media), then exits.
Usage: python3 wait_chat.py CHAT_ID [CHAT_ID ...]
One person can have two ids (...@c.us and ...@lid), so pass both if you know both."""
import json
import os
import sys
import time
import urllib.request

from bridge import DATA, KEY

IDS = tuple(sys.argv[1:])
LOG = os.path.join(DATA, "events.jsonl")
POSITION = os.path.join(DATA, "wait.pos")
RECEIVED = os.path.join(DATA, "received")
QUIET_SECONDS = 12  # messages sent in a burst are returned together


def save_media(message):
    media = message.get("media") or {}
    url = media.get("url")
    extension = (media.get("mimetype") or "bin").split("/")[-1].split(";")[0]
    name = "%s_%s.%s" % (time.strftime("%Y%m%d-%H%M%S"), message.get("id", "x")[-8:], extension)
    path = os.path.join(RECEIVED, name)
    os.makedirs(RECEIVED, exist_ok=True)
    request = urllib.request.Request(url, headers={"X-Api-Key": KEY})
    with urllib.request.urlopen(request, timeout=30) as response, open(path, "wb") as out:
        out.write(response.read())
    return path


try:
    with open(POSITION) as f:
        position = int(f.read())
except (OSError, ValueError):
    position = os.path.getsize(LOG) if os.path.exists(LOG) else 0

collected, last_message = [], 0.0
while True:
    if os.path.exists(LOG) and os.path.getsize(LOG) > position:
        with open(LOG) as f:
            f.seek(position)
            chunk = f.read()
            position = f.tell()
        for line in chunk.splitlines():
            try:
                event = json.loads(line)
            except ValueError:
                continue
            message = event.get("payload") or {}
            if event.get("event") != "message" or message.get("fromMe") or message.get("from") not in IDS:
                continue
            item = {"time": event.get("_received"), "from": message.get("from"), "text": message.get("body") or ""}
            if message.get("hasMedia") and (message.get("media") or {}).get("url"):
                try:
                    item["media"] = save_media(message)
                except Exception as error:
                    item["media_error"] = str(error)
            collected.append(item)
            last_message = time.time()
    if collected and time.time() - last_message >= QUIET_SECONDS:
        for item in collected:
            print(json.dumps(item, ensure_ascii=False))
        with open(POSITION, "w") as f:
            f.write(str(position))
        break
    time.sleep(3)
