# ./startup/identity-test.sh
#!/bin/bash
set -e
echo "user: $(whoami)"
echo "home directory: $HOME"
ehco "working directory: $(pwd)"

if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Your user is set to root it must be changed"
    exit 1
fi
