#!/bin/bash

if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ Error: GITHUB_TOKEN is required"
    exit 1
fi

echo "🚀 Bootstrapping Sophon Light Node..."

RELEASE_VERSION=$(curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/sophon-org/sophon-light-node/releases/latest | jq -r .tag_name)

echo "📥 Downloading version $RELEASE_VERSION..."

git clone -q -c advice.detachedHead=false --depth=1 --single-branch --branch $RELEASE_VERSION https://oauth2:${GITHUB_TOKEN}@github.com/your-org/sophon-light-node.git .

chmod +x main.sh
exec ./main.sh "$@"