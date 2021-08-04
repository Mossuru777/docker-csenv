#!/bin/bash
set -e

echo "Starting for LiteSpeed WebServer..."
sudo /usr/local/lsws/bin/lswsctrl start

# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec "$@"
