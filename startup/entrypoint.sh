#!/bin/bash
# /startup/entrypoint.sh

echo "Running some quick checks ..."
./startup/identity-test.sh

su - myuser -c 'echo "0 * * * * /home/myuser/myscript.sh" | crontab -'

: "${CRON_SCHEDULE:=0 */12 * * *}"  # default to every 12 hours
su - builder -c "echo '$CRON_SCHEDULE /startup/aur-build-mirror.sh >> /var/log/cron.log 2>&1' | crontab -"
exec crond -n
