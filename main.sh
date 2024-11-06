#!/bin/bash

# function to handle the signal
handle_sophonup_error() {
    echo "❌ Received error signal from sophonup.sh. Exiting main process"
    exit 1
}

# set up trap to catch SIGUSR1 and call the handler
trap 'handle_sophonup_error' SIGUSR1

start_sophonup() {
    # if wallet is provided, public_domain and monitor_url must be set
    if [ -n "$wallet" ]; then
        if [ -z "$public_domain" ]; then
            echo "🚫 ERROR: '--public-domain' is required when '--wallet' is specified."
            kill -SIGUSR1 "$$"
            exit 1
        fi
    fi
    NETWORK=$network ./sophonup.sh --wallet "$wallet" --identity ./identity --public-domain "$public_domain" --monitor-url "$monitor_url" &
}

# parse arguments
while [ $# -gt 0 ]; do
    if [[ $1 == "--"* ]]; then
        v="${1/--/}"
        v="${v//-/_}"
        eval "$v=\"$2\""
        shift
    fi
    shift
done

# set default network if not provided
if [ -z "$network" ]; then
    echo "🛜 No network selected. Defaulting to sophon."
    network="sophon"
else
    echo "🛜 Network selected: $network"
fi

if [ -z "$monitor_url" ]; then
    # use default monitor URL
    # monitor_url=https://monitor.sophon.xyz
    monitor_url=https://monitor-stg.sophon.xyz
    echo "🚨 WARNING: '--monitor-url' is not set. Defaulting to $monitor_url"
fi

HEALTH_ENDPOINT="$monitor_url/health"
CONFIG_ENDPOINT="$monitor_url/configs?network=$network"
LOCAL_CONFIG_FILE="$HOME/.avail/$network/config/config.yml"

while true; do
    # wait for the monitor service to be up
    echo "🏥 Pinging health endpoint at: $HEALTH_ENDPOINT until it responds"
    until curl -s "$HEALTH_ENDPOINT" > /dev/null; do
        echo "🕓 Waiting for monitor service to be up..."
        sleep 2
    done
    echo "✅ Monitor service is up!"

    # fetch latest config from Sophon's monitor
    echo "📩 Fetching latest configuration from $CONFIG_ENDPOINT"
    CONFIG_RESPONSE=$(curl -s -w "\n%{http_code}" "$CONFIG_ENDPOINT")
    HTTP_STATUS=$(echo "$CONFIG_RESPONSE" | tail -n1)
    RESPONSE_BODY=$(echo "$CONFIG_RESPONSE" | sed '$d')

    # check HTTP status
    if [ "$HTTP_STATUS" -ne 200 ]; then
        echo "❌ Couldn't fetch config [$HTTP_STATUS]: $RESPONSE_BODY. Exiting."
        exit 1
    else
        echo "📋 Configuration response: $RESPONSE_BODY"
    fi

    # if PORT is set, add http_server_port to the config
    CONFIG_TRANSFORM='
        to_entries[]
        | select(.key != "_id")  # Exclude the _id field
        | "\(.key)=" +
        (if (.value | type) == "string" then
            "\"" + .value + "\""
        elif (.value | type) == "array" then
            "[" + (.value | map("\"" + . + "\"") | join(",")) + "]"
        else
            .value | tostring
        end)
    '

    # if PORT is set, add http_server_port to the config
    if [ -n "$PORT" ]; then
        echo "🔌 PORT variable found: $PORT. Will configure http_server_port."
        # remove any existing http_server_port line if present and add new one
        LATEST_CONFIG=$(echo "$RESPONSE_BODY" | jq -r "$CONFIG_TRANSFORM" | grep -v "^http_server_port=")
        LATEST_CONFIG="${LATEST_CONFIG}"$'\n'"http_server_port=$PORT"
    else
        echo "⚠️  No PORT variable set. The node will use the default port from the config."
        LATEST_CONFIG=$(echo "$RESPONSE_BODY" | jq -r "$CONFIG_TRANSFORM")
    fi

    # replace $HOME with its actual value
    LATEST_CONFIG=$(echo "$LATEST_CONFIG" | sed "s|\$HOME|$HOME|g")

    if [ $? -ne 0 ]; then
        echo "❌ Error fetching configuration from $CONFIG_ENDPOINT"
        exit 1
    fi

    # if there's no config, this is the first time running the node so save the config and start node
    if [ ! -f "$LOCAL_CONFIG_FILE" ]; then
        echo "✍️  No local configuration found. Saving fetched configuration..."
        mkdir -p "$(dirname "$LOCAL_CONFIG_FILE")"
        echo "$LATEST_CONFIG" > "$LOCAL_CONFIG_FILE"
        start_sophonup
    else
        AVAIL_PID=$(pgrep -x "avail-light")
        
        echo "📋 Local configuration found. Checking for changes..."

        # compare fetched config with the local config
        if ! diff <(echo "$LATEST_CONFIG") "$LOCAL_CONFIG_FILE" >/dev/null; then
            echo "🆕 Configuration has changed. Restarting Sophonup process..."
            
            # check if the process is running before attempting to kill it
            if ps -p $AVAIL_PID > /dev/null 2>&1; then
                kill $AVAIL_PID
            else
                echo "⚠️  Process is not running; no need to kill."
            fi

            # update local config with the latest version
            echo "$LATEST_CONFIG" > "$LOCAL_CONFIG_FILE"
            
            start_sophonup
        else
            echo "🚜 No configuration changes detected. Process will continue running."
            if ! ps -p $AVAIL_PID > /dev/null 2>&1; then
                echo "🚨 Process is not running."
                start_sophonup
            fi
        fi
    fi

    # if VESION_CHECKER_INTERVAL env var is not set, default to 7 days
    if [ -z "$VERSION_CHECKER_INTERVAL" ]; then
        VERSION_CHECKER_INTERVAL=604800
    fi
    echo "🕒 Sleeping for $VERSION_CHECKER_INTERVAL seconds"
    sleep "$VERSION_CHECKER_INTERVAL"
done
