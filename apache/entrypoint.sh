#!/bin/bash
set -e

echo "Starting for Apache WebServer..."
sudo /etc/init.d/apache2 start

# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec "$@"
