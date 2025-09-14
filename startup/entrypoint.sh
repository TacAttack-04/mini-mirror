# /startup/entrypoint.sh
#!/bin/bash

echo "Running some quick checks ..."
./identity-test.sh

: "${CRON_SCHEDULE:=0 */12 * * *}"  # default to every 12 hours
echo "$CRON_SCHEDULE /aur-build-mirror.sh >> /var/log/cron.log 2>&1" > /etc/crontab
crond -n
