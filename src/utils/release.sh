#!/bin/bash

# Get current version from Cargo.toml and increment patch version
CURRENT_VERSION=$(cargo metadata --no-deps --format-version 1 | jq -r '.packages[0].version')

if [ -z "$CURRENT_VERSION" ]; then
    echo "Error: Could not get current version from Cargo.toml"
    exit 1
fi

# Split version into parts
IFS='.' read -ra VERSION_PARTS <<< "$CURRENT_VERSION"
if [ ${#VERSION_PARTS[@]} -ne 3 ]; then
    echo "Error: Current version is not in format X.Y.Z"
    exit 1
fi

# Increment patch version
((VERSION_PARTS[2]++))
NEW_VERSION="${VERSION_PARTS[0]}.${VERSION_PARTS[1]}.${VERSION_PARTS[2]}"

echo "Current version: $CURRENT_VERSION"
echo "New version: $NEW_VERSION"

# Ask for confirmation
read -p "Proceed with release? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Release cancelled"
    exit 1
fi

# Update version in Cargo.toml
echo "Updating version in Cargo.toml..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS uses BSD sed which requires an empty string after -i
    sed -i '' "s/^version = \".*\"/version = \"${NEW_VERSION}\"/" Cargo.toml
else
    # Linux version of sed
    sed -i "s/^version = \".*\"/version = \"${NEW_VERSION}\"/" Cargo.toml
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
tar -czf "../binaries-${NEW_VERSION}.tar.gz" *
cd ..

# Check if gh command is available
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed"
    echo "Please install it first: https://cli.github.com/"
    exit 1
fi

# Create GitHub release
echo "Creating GitHub release v${NEW_VERSION}..."
gh release create "v${NEW_VERSION}" \
    --title "Version ${NEW_VERSION}" \
    --notes "" \
    --prerelease=false \
    --generate-notes=false \
    "binaries-${NEW_VERSION}.tar.gz"

echo "Release v${NEW_VERSION} created successfully!"