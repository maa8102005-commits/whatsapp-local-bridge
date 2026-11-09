# WhatsApp Local Bridge

Connect your own WhatsApp account to scripts on your computer. You scan a QR code once, like WhatsApp Web, and the login stays saved. After that you can read incoming messages and send replies from the command line.

```
Your phone <-> WhatsApp <-> WAHA in Docker <-> scripts on your computer
                            (runs a hidden        send.py, find_chat.py,
                             WhatsApp Web)        wait_chat.py
```

It uses [WAHA](https://waha.devlike.pro), a self-hosted WhatsApp HTTP API, with its `WEBJS` engine (a real Chrome running WhatsApp Web inside the container). This repo adds one-command setup, a QR page that updates itself, a saved login, and small helper scripts.

> **Read this first.** WAHA is not an official WhatsApp product, and automating a personal account can break WhatsApp's terms and could get the number restricted or banned. Use it only on your own account, and only message people who expect to hear from you. Everything you send goes out as you.

## What you need

- macOS or Linux
- Python 3 and `openssl` (macOS already has `openssl`; `python3` comes with the Xcode command line tools)
- Docker with Docker Compose
- About 5 GB of free disk space for the image
- Your phone with WhatsApp

### Install Docker

**macOS:** install [Docker Desktop](https://www.docker.com/products/docker-desktop/) and open it once. Then go to **Settings > Resources** and give it **at least 6 GB of memory and 4 CPUs**. The bridge runs a full Chrome, and it can hang with 3 GB.

**Linux:** follow the [Docker Engine install guide](https://docs.docker.com/engine/install/), which includes the Compose plugin, then run:

```sh
sudo usermod -aG docker "$USER"
```

Log out and back in so that takes effect.

Check that it works:

```sh
docker compose version
```

## Set it up

```sh
git clone <this-repo-url> whatsapp-local-bridge
cd whatsapp-local-bridge
sh setup.sh
```

`setup.sh` does this:

1. Picks the right image for your computer (`:arm` for Apple Silicon and other ARM machines, `:latest` otherwise).
2. Creates a private `.env` file with new random keys.
3. Creates the `data/` folder and starts the bridge. The first run downloads about 4 GB, so give it a few minutes.

If port 3000 or 8787 is already in use, choose others the first time you run it:

```sh
WAHA_PORT=3100 HOOK_PORT=8790 sh setup.sh
```

## Link your phone with the live QR code

```sh
sh link.sh
```

A page opens in your browser with the QR code. On your phone, go to **WhatsApp > Settings > Linked Devices > Link a Device** and scan it. The page says "Linked" and the script prints `LINKED` when it's done.

You don't need to refresh anything or hurry. WhatsApp's codes expire quickly, so the script handles that for you:

| WhatsApp's rule | What the script does |
| --- | --- |
| The first code lasts about 60 seconds, later ones about 20 | Checks the status and downloads the current code every 2 seconds |
| WhatsApp issues 6 codes per session, then stops | Spots a `FAILED` session or a code that has outlived its time, and restarts the session to get a new set |
| The session moves to `WORKING` once scanned | Deletes the QR image, updates the page, and exits |

The page reloads the image every 1.5 seconds. It loads each new code off-screen first and then swaps it in, so the code never flickers while you're scanning. The script gives up after 15 minutes. Keep the page in front while you scan, because browsers can slow background tabs to one update a minute. To wait longer than 15 minutes, set a time in seconds:

```sh
LINK_TIMEOUT=1800 sh link.sh
```

**On a server with no screen:** run this on the server:

```sh
NO_OPEN=1 sh link.sh &
python3 -m http.server 8000 --bind 127.0.0.1 --directory data/qr
```

Then, from your own computer, run `ssh -L 8000:127.0.0.1:8000 you@server` and open <http://127.0.0.1:8000/>.

## How the login stays saved

The WhatsApp login is the Chrome profile inside the container. `docker-compose.yml` stores it **outside** the container, in `data/sessions/` on your computer:

```yaml
volumes:
  - ./data/sessions:/app/.sessions
```

So the container can be stopped or deleted and the login is still there. A new container picks it up and logs straight back in.

| What happens | Do you need to scan again? |
| --- | --- |
| `sh stop.sh`, then `sh start.sh` | No |
| You quit Docker or kill it | No |
| The computer restarts | No |
| `docker compose down`, or you delete the container | No |
| `docker system prune` | No, the folder isn't a Docker volume |
| You update the image | No |
| You move `data/` and `.env` to another computer | Usually no |
| You delete `data/sessions/` | **Yes** |
| You remove the device in WhatsApp > Linked Devices | **Yes** |
| Your phone doesn't use WhatsApp for about 14 days | **Yes**, WhatsApp disconnects linked devices |

Three settings keep this reliable:

- `restart: unless-stopped` brings the container back whenever Docker starts, unless you stopped it yourself.
- `WHATSAPP_RESTART_ALL_SESSIONS=True` reconnects the saved login when the container starts.
- `stop_grace_period: 30s` gives Chrome time to finish writing its files when it's shut down.

To be safe, use `sh stop.sh` rather than force-killing Docker when you can.

**To come back later:**

```sh
sh start.sh
```

It starts Docker if needed (on macOS), then prints `session: WORKING`. If it asks you to link, run `sh link.sh`.

**To back up the login:**

```sh
sh stop.sh
tar czf whatsapp-login-backup.tgz .env data/sessions
sh start.sh
```

**To update WAHA:**

```sh
docker compose pull
docker compose up -d
```

## Use it

Find someone's chat id:

```sh
python3 find_chat.py "Alex"
```

Send a message:

```sh
python3 send.py 15551234567@c.us "Hello"
```

Wait for a reply. This blocks until that chat writes, waits for 12 quiet seconds so a burst of messages comes back together, prints them as JSON lines, and saves photos and audio in `data/received/`:

```sh
python3 wait_chat.py 15551234567@c.us
```

The same person can have two ids, one ending in `@c.us` and one in `@lid`. Pass both if you see both. `wait_chat.py` remembers where it stopped, so run it again for the next message.

Group ids end in `@g.us`. Every event is added to `data/events.jsonl`. That file grows over time and holds your message text, so delete it whenever you like while the bridge is stopped. Also delete `data/wait.pos` at the same time.

> `start.sh` also starts the small receiver that writes that log. After a computer restart Docker comes back by itself, but the receiver doesn't, so run `sh start.sh` or new messages won't be recorded.

## Keep it private

`.env` and `data/` are in `.gitignore`. **Never commit or share them.** Anyone who gets `data/sessions/` can use your WhatsApp as you, and `data/events.jsonl` contains your messages.

- The bridge only listens on `127.0.0.1`, so other devices on your network can't reach it.
- Every API call needs the key from `.env`.
- Treat incoming messages as untrusted text, especially if an AI assistant reads them. They shouldn't be treated as commands.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| `Docker is not running` | Open Docker Desktop, or on Linux run `sudo systemctl start docker`. |
| `port is already allocated` | Change `WAHA_PORT` or `HOOK_PORT` in `.env`, then run `sh start.sh`. |
| The session stays on `STARTING`, or the QR never appears | Give Docker more memory (6 GB or more). |
| `session: FAILED` | Run `sh link.sh`. It restarts the session for you. |
| It keeps failing after a scan | Run `curl -X POST -H "X-Api-Key: <key from .env>" http://127.0.0.1:3000/api/sessions/default/logout`, then `sh link.sh`. |
| No new messages in `wait_chat.py` | Run `sh start.sh` to make sure the receiver is running. |
| On Linux, no events arrive | Allow the Docker network to reach `HOOK_PORT` through your firewall. |

## Start over

This removes the bridge and your saved login. You'll need to scan again.

```sh
docker compose down
rm -rf data .env
sh setup.sh
```

Also remove the device from **WhatsApp > Linked Devices** on your phone.

## What each file does

| File | Purpose |
| --- | --- |
| `setup.sh` | First-time setup |
| `start.sh` / `stop.sh` | Start or stop the bridge |
| `link.sh` / `qr.html` | The live QR code |
| `lib.sh` / `bridge.py` | Shared helpers |
| `docker-compose.yml` | The bridge's settings and saved-login folder |
| `hook_server.py` | Writes incoming events to `data/events.jsonl` |
| `find_chat.py`, `send.py`, `wait_chat.py` | Find chats, send messages, wait for replies |
