#!/bin/bash
set -e

echo -n "Starting for LiteSpeed WebServer..."
sudo /usr/local/lsws/bin/lswsctrl start
echo "OK."

# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec "$@"
