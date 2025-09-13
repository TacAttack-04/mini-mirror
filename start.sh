#!/bin/bash
# Start lighttpd in background
lighttpd -f /etc/lighttpd/lighttpd.conf -D &

# Switch to builder user and run the AUR build script
su - builder -c "/home/builder/aur-build-mirror.sh"

# Keep lighttpd running
wait $LIGHTPD_PID
