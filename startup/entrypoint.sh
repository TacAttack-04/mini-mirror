#!/bin/bash
# /startup/entrypoint.sh

echo "Running some quick checks ..."
./startup/identity-test.sh

echo "${CRON_SCHEDULE:=0 */12 * * *} ./startup/aur-build-mirror.sh" > /schedule.cron
if [ "$CRON_TESTED" != "true" ]; then
    supercronic -test /schedule.cron
    export CRON_TESTED=true
fi
supercronic -debug /schedule.cron
