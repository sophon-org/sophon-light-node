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
if [ -f "./generate_node_id" ]; then
    GENERATE_NODE_ID="./generate_node_id"
else
    GENERATE_NODE_ID="./target/release/generate_node_id"
fi
NODE_ID=$($GENERATE_NODE_ID "$AVAIL_SECRET_URI")

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

# ensure public_domain starts with https:// if it doesn't contain http or https
if [[ ! "$public_domain" =~ ^http ]]; then
    public_domain="https://$public_domain"
fi

# wait for node to be up
HEALTH_ENDPOINT="$public_domain/v2/status"

# wait until API is ready and that the /status response contains the "available" property
echo "🏥 Pinging node's health endpoint at: $HEALTH_ENDPOINT until it responds"
until response=$(curl -s "$HEALTH_ENDPOINT") && echo "$response" | grep -q '"available":'; do
    echo "🕓 Waiting for node to be up (this can take ~1 min)"
    echo "🔗 Node health response: $response"
    sleep 5
done
echo "🔗 Node health response: $response"
echo "✅ Node is up!"

# call register endpoint with JSON payload
ADD_NODE_ENDPOINT="$monitor_url/nodes"
echo "🚀 Registering node..."

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$ADD_NODE_ENDPOINT" \
     -H "Content-Type: application/json" \
     -d "$JSON_PAYLOAD")
HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')
echo "☎️  Response: $RESPONSE_BODY"

if [ "$HTTP_STATUS" -eq 200 ]; then
    echo "✅ Node registered successfully!"
elif [ "$HTTP_STATUS" -eq 400 ]; then
    if [[ "$RESPONSE_BODY" == *"node ID already exists."* ]]; then
        echo "🔔 Node ID already registered. If you think this is a mistake, reach us out on our Discord channel. Skipping registration..." >&2
    else
        echo "🚫 ERROR: Bad request. $RESPONSE_BODY" >&2
        exit 1
    fi
elif [ "$HTTP_STATUS" -eq 403 ]; then
    echo "🔔" >&2
    echo "🔔  [NOT ELIGIBLE FOR REWARDS] The operator wallet you provided doesn’t have any delegated guardian memberships. It will run but not participate in the rewards program. You can still get delegations and later join the reward program." >&2
    echo "🔔" >&2
elif [ "$HTTP_STATUS" -eq 500 ]; then
    echo "🚫 ERROR: Server error occurred. $RESPONSE_BODY." >&2
    exit 1
else
    echo "🚫 ERROR: Unexpected HTTP status code: $HTTP_STATUS" >&2
    echo "☎️  Response: $RESPONSE_BODY"
    exit 1
fi