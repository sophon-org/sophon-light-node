FROM ubuntu:latest

ARG GITHUB_TOKEN

# Install minimal dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
        file \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Download and extract latest release
RUN set -x && \
    # Get latest release info
    GITHUB_BASE_URL="https://api.github.com/repos/sophon-org/sophon-light-node/releases" && \
    RELEASE_INFO=$(curl -s -H "Authorization: Bearer ${GITHUB_TOKEN}" ${GITHUB_BASE_URL}/latest) && \

    # Get the URL and name for the tar.gz file
    BINARY_FILE_ID=$(echo "${RELEASE_INFO}" | jq -r '.assets[0] | select(.name | endswith("tar.gz")) | .id') && \
    BINARY_FILE_NAME=$(echo "${RELEASE_INFO}" | jq -r '.assets[0] | select(.name | endswith("tar.gz")) | .name') && \

    # Download the tar.gz file
    curl ${curl_custom_flags} \ 
     -L \
     -H "Accept: application/octet-stream" \
     -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        "${GITHUB_BASE_URL}/assets/${BINARY_FILE_ID}" -o "${BINARY_FILE_NAME}" && \

    # Extract and set up
    ls -l && \
    file "${BINARY_FILE_NAME}" && \
    tar -xzvf "${BINARY_FILE_NAME}" && \
    rm "${BINARY_FILE_NAME}" && \
    chmod +x sophon-node

    ENTRYPOINT ["/bin/sh", "-c"]
    CMD ["/app/sophon-node --operator \"$OPERATOR_ADDRESS\" --destination \"$DESTINATION_ADDRESS\" --percentage \"$PERCENTAGE\" --identity \"$IDENTITY\" --public-domain \"$PUBLIC_DOMAIN\" --monitor-url \"$MONITOR_URL\" --network \"$NETWORK\" --auto-upgrade \"$AUTO_UPGRADE\""]