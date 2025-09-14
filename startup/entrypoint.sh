#!/bin/bash
# /startup/entrypoint.sh

echo "Running some quick checks ..."
./startup/identity-test.sh

: "${CRON_SCHEDULE:=0 */12 * * *}"  # default to every 12 hours
echo "$CRON_SCHEDULE /startup/aur-build-mirror.sh >> /var/log/cron.log 2>&1" > /etc/crontab
crond -n
