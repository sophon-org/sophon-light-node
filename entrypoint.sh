#!/bin/sh

# set default value for NETWORK if not set
: "${NETWORK:=mainnet}"

mkdir -p "$HOME/.avail/$NETWORK/config"

if [ "$NETWORK" = "mainnet" ]; then
    CONFIG_FILE="config/mainnet.config.yml"
elif [ "$NETWORK" = "turing" ]; then
    CONFIG_FILE="config/turing.config.yml"
else
    echo "Error: Unknown NETWORK value '$NETWORK'"
    exit 1
fi

# replace placeholders with env vars
sed "s|\$HOME|$HOME|g; s|\$NETWORK|$NETWORK|g" /app/$CONFIG_FILE > "$HOME/.avail/$NETWORK/config/config.yml"

# execute original command
exec "$@"