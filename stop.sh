#!/bin/sh
# Stops the bridge. Your login stays saved in data/sessions.
. "$(dirname "$0")/lib.sh"
[ -f data/hook.pid ] && kill "$(cat data/hook.pid)" 2>/dev/null
rm -f data/hook.pid
docker compose stop
echo "Stopped. Run sh start.sh to come back without scanning."
