#!/bin/bash

while [ $# -gt 0 ]; do
    if [[ $1 == "--"* ]]; then
        v="${1/--/}"
        v="${v//-/_}"
        eval "$v=\"$2\""
        shift
    fi
    shift
done

# get public domain from the environment
if [ -z "$monitor_url" ]; then
    echo "❌ ERROR: public_domain is not set"
    exit 1
fi

# MONITOR_URL="https://stg-sophon-node-monitor.up.railway.app"
HEALTH_ENDPOINT="$monitor_url/health"
CONFIG_ENDPOINT="$monitor_url/configs"
LOCAL_CONFIG_FILE="$HOME/.avail/mainnet/config/config.yml"

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
    CONFIG_RESPONSE=$(curl -s "$CONFIG_ENDPOINT")

    # Use jq to transform JSON into the desired format
    LATEST_CONFIG=$(echo "$CONFIG_RESPONSE" | jq -r '
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
    ')

    # replace $HOME with its actual value
    LATEST_CONFIG=$(echo "$LATEST_CONFIG" | sed "s|\$HOME|$HOME|g")

    if [ $? -ne 0 ]; then
        echo "❌ Error fetching configuration from $CONFIG_ENDPOINT"
        exit 1
    fi

    # if there's no config, this is the first time running the node so save the config and start node
    if [ ! -f "$LOCAL_CONFIG_FILE" ]; then
        echo "✍️  No local configuration found. Saving fetched configuration..."
        # if the local config file doesn't exist, create it
        mkdir -p "$(dirname "$LOCAL_CONFIG_FILE")"
        echo "$LATEST_CONFIG" > "$LOCAL_CONFIG_FILE"

        # start light client
        ./sophonup.sh --wallet $wallet --identity ./identity --public-domain $public_domain --monitor-url $monitor_url &
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

            # start light client
            ./sophonup.sh --wallet $wallet --identity ./identity --public-domain $public_domain --monitor-url $monitor_url &
        else
            echo "🚜 No configuration changes detected. Process will continue running."
            if ! ps -p $AVAIL_PID > /dev/null 2>&1; then
                echo "🚨 Process is not running. Starting Sophonup process..."

                # start the light client process
                ./sophonup.sh --wallet $wallet --identity ./identity --public-domain $public_domain --monitor-url $monitor_url &
            fi
        fi
    fi

    # wait for 1 day (86400 seconds)
    # sleep 86400 
    sleep 60 
done
