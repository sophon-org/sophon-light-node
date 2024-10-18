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

if [ -n "$wallet" ]; then
    if ! [[ "$wallet" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        echo "🚫 ERROR: $wallet is not a valid EVM address" >&2
        exit 1
    fi
    # if --public-domain is not provided, exit with error
    if [ -z "$public_domain" ]; then
        echo "🚫 ERROR: \`--public-domain\` argument is missing" >&2
        exit 1
    fi
    
    # if --monitor-url is not provided, exit with error
    if [ -z "$monitor_url" ]; then
        # use default monitor URL
        monitor_url=htpps://stg-sophon-node-monitor.up.railway.app
    fi
    echo "🌎 Monitor URL is $monitor_url"

fi

# check if identity file exists
echo "🔍 Looking for identity file at $identity..."
if [ -f "$identity" ]; then
    echo "🔑 Identity found at $identity."
else
    echo "🚫 ERROR: identity.toml file not found at $identity." >&2
    exit 1
fi

# extract avail_secret_uri from identity.toml file
AVAIL_SECRET_URI=$(sed -n "s/^[[:space:]]*avail_secret_uri[[:space:]]*=[[:space:]]*'\(.*\)'/\1/p" "$identity")

# check if avail_secret_uri was extracted successfully
if [ -z "$AVAIL_SECRET_URI" ]; then
    echo "🚫 ERROR: Could not extract avail_secret_uri from $identity"
    exit 1
else
    echo "👍 Extracted avail_secret_uri!"
fi

# use Rust script to generate NODE_ID from avail_secret_uri
NODE_ID=$(./target/release/generate_node_id "$AVAIL_SECRET_URI")

if [ $? -ne 0 ] || [ -z "$NODE_ID" ]; then
    echo "🚫 ERROR: Failed to generate node ID" >&2
    exit 1
fi

# prepare JSON payload
JSON_PAYLOAD=$(jq -n \
  --arg id "$NODE_ID" \
  --arg url "$public_domain" \
  --arg delegateAddress "$wallet" \
  '{id: $id, url: $url, delegateAddress: $delegateAddress}')
# node info separately
echo "+$(printf '%*s' "100" | tr ' ' '-')+"
echo "| 🆔 Node ID: $NODE_ID"
echo "| 🌐 Public domain: $public_domain"
echo "| 👛 Delegate address: $wallet"
echo "+$(printf '%*s' "100" | tr ' ' '-')+"

# wait for the monitor service to be up
HEALTH_ENDPOINT="$monitor_url/health"

echo "🏥 Pinging health endpoint at: $HEALTH_ENDPOINT until it responds"
until curl -s "$HEALTH_ENDPOINT" > /dev/null; do
    echo "Waiting for monitor service to be up..."
    sleep 2
done

echo "✅ Monitor service is up!"

# call register endpoint with JSON payload
MONITOR_URL="$monitor_url/nodes"
echo "🚀 Registering node..."

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$MONITOR_URL" \
     -H "Content-Type: application/json" \
     -d "$JSON_PAYLOAD")
HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')
echo "Response: $RESPONSE_BODY"

if [ "$HTTP_STATUS" -eq 200 ]; then
    echo "✅ Node registered successfully!"
elif [ "$HTTP_STATUS" -eq 400 ]; then
    if [[ "$RESPONSE_BODY" == *"node ID already exists."* ]]; then
        echo "🚫  Node ID already exists. Make sure that you are the one that has registered it. Skipping registration..." >&2
    else
        echo "🚫 ERROR: Bad request. $RESPONSE_BODY" >&2
        exit 1
    fi
elif [ "$HTTP_STATUS" -eq 403 ]; then
    echo "🚫" >&2
    echo "🚫  [NOT ELIGIBLE FOR REWARDS] The operator wallet you provided doesn’t have any delegated guardian memberships. It will run but not participate in the rewards program. You can still get delegations and later join the reward program." >&2
    echo "🚫" >&2
elif [ "$HTTP_STATUS" -eq 500 ]; then
    echo "🚫 ERROR: Server error occurred. $RESPONSE_BODY." >&2
    exit 1
else
    echo "🚫 ERROR: Unexpected HTTP status code: $HTTP_STATUS" >&2
    echo "Response: $RESPONSE_BODY"
    exit 1
fi

exec "$@"


