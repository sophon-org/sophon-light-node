#!/bin/bash

download_and_run() {
    if [ -z "$GITHUB_TOKEN" ]; then
        echo "❌ Error: GITHUB_TOKEN is required"
        exit 1
    fi

    echo "🚀 Bootstrapping Sophon Light Node..."

    # Get latest release info
    RELEASE_INFO=$(curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/sophon-org/sophon-light-node/tags)
    echo "🔍 Latest release info: $RELEASE_INFO"
    RELEASE_VERSION=$(echo "$RELEASE_INFO" | jq -r '.[0].name')
    echo "🔍 Latest release version: $RELEASE_VERSION"
    BINARY_URL=$(echo "$RELEASE_INFO" | jq -r '.assets[] | select(.name=="sophon-node") | .browser_download_url')

    echo "📥 Downloading version $RELEASE_VERSION..."

    # Download the binary
    curl -L -H "Authorization: token $GITHUB_TOKEN" -o sophon-node.new "$BINARY_URL"
    chmod +x sophon-node.new

    # If we already have a running binary, replace it gracefully
    if [ -f "sophon-node" ]; then
        mv sophon-node.new sophon-node
    else
        mv sophon-node.new sophon-node
    fi
}

# Function to check version and update if needed
check_for_updates() {
    local current_version="${APP_VERSION:-0.0.0}"
    
    echo "🔍 Checking for updates..."
    
    # Get the latest version from monitor service
    version_info=$(curl -s "${MONITOR_URL}/version")
    if [ $? -ne 0 ]; then
        echo "⚠️ Failed to check updates. Will retry later."
        return 1
    fi
    
    latest_version=$(echo "$version_info" | jq -r '.version')
    
    echo "📊 Current version: $current_version"
    echo "📊 Latest version: $latest_version"
    
    # Compare versions
    if [ "$latest_version" != "$current_version" ]; then
        echo "🆕 New version available!"
        download_and_run
        
        # Update the version
        export APP_VERSION="$latest_version"

        # Restart with same arguments
        exec ./sophon-node $CURRENT_ARGS
    fi
}

# Store original arguments
CURRENT_ARGS=""

# Construct arguments based on environment variables
if [ -n "$IDENTITY" ]; then
    CURRENT_ARGS="$CURRENT_ARGS --identity $IDENTITY"
fi

if [ -n "$OPERATOR_ADDRESS" ]; then
    CURRENT_ARGS="$CURRENT_ARGS --wallet $OPERATOR_ADDRESS"
fi

if [ -n "$PUBLIC_DOMAIN" ]; then
    CURRENT_ARGS="$CURRENT_ARGS --public-domain $PUBLIC_DOMAIN"
fi

if [ -n "$MONITOR_URL" ]; then
    CURRENT_ARGS="$CURRENT_ARGS --monitor-url $MONITOR_URL"
fi

if [ -n "$NETWORK" ]; then
    CURRENT_ARGS="$CURRENT_ARGS --network $NETWORK"
fi

if [ -n "$APP_ID" ]; then
    CURRENT_ARGS="$CURRENT_ARGS --app_id $APP_ID"
fi

# Initial download and start
download_and_run

# Start the binary
./sophon-node $CURRENT_ARGS &
SOPHON_PID=$!

# Check for updates every X seconds
VERSION_CHECK_INTERVAL=${VERSION_CHECK_INTERVAL:-3600}  # Default to 1 hour
while true; do
    sleep $VERSION_CHECK_INTERVAL
    check_for_updates
done