#!/bin/bash

# Check if version parameter is provided
if [ $# -ne 1 ]; then
    echo "Error: Version number required"
    echo "Usage: $0 <version_number>"
    echo "Example: $0 1.2.3"
    exit 1
fi

VERSION=$1

# Validate version format (must be X.Y.Z)
if ! [[ $VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Version must be in format X.Y.Z (e.g., 1.2.3)"
    exit 1
fi

# Check if we're in the right directory (should have Cargo.toml)
if [ ! -f "Cargo.toml" ]; then
    echo "Error: Cargo.toml not found"
    echo "Please run this script from the project root directory"
    exit 1
fi

# Update version in Cargo.toml
echo "Updating version in Cargo.toml..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS uses BSD sed which requires an empty string after -i
    sed -i '' "s/^version = \".*\"/version = \"${VERSION}\"/" Cargo.toml
else
    # Linux version of sed
    sed -i "s/^version = \".*\"/version = \"${VERSION}\"/" Cargo.toml
fi

# Build release version
echo "Building release version..."
cargo build --release

# Check if build was successful
if [ $? -ne 0 ]; then
    echo "Error: Build failed"
    exit 1
fi

# Check if required binaries exist
if [ ! -f "target/release/sophon-node" ] || [ ! -f "target/release/generate_node_id" ]; then
    echo "Error: Required binaries not found in target/release/"
    exit 1
fi

# Create release directory if it doesn't exist
mkdir -p release

# Copy binaries
echo "Copying binaries to release directory..."
cp target/release/sophon-node release/
cp target/release/generate_node_id release/

# Create tarball
echo "Creating tarball..."
cd release/
tar -czf "../sophon-light-node-${VERSION}.tar.gz" *
cd ..

# Check if gh command is available
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed"
    echo "Please install it first: https://cli.github.com/"
    exit 1
fi

# Create GitHub release
echo "Creating GitHub release v${VERSION}..."
gh release create "v${VERSION}" \
    --title "Version ${VERSION}" \
    --notes "" \
    --prerelease=false \
    --generate-notes=false \
    "sophon-light-node-${VERSION}.tar.gz"

echo "Release v${VERSION} created successfully!"