#!/bin/bash
# /startup/entrypoint.sh

echo "Running some quick checks ..."
./startup/identity-test.sh

: "${CRON_SCHEDULE:=0 */12 * * *}"  # default to every 12 hours
# sudo echo "$CRON_SCHEDULE /startup/aur-build-mirror.sh >> /var/log/cron.log 2>&1" | crontab -
# exec crond -n -p /tmp/crond.pid

# Parse cron schedule to seconds (basic example for */12 hours)
INTERVAL_HOURS=$(echo "$CRON_SCHEDULE" | grep -o '\*/[0-9]*' | cut -d'/' -f2)
INTERVAL_SECONDS=$((${INTERVAL_HOURS:-12} * 3600))

# Run once immediately (optional)
/builder/startup/aur-build-mirror.sh

# Then run in loop
while true; do
    sleep $INTERVAL_SECONDS
    /startup/aur-build-mirror.sh
done
