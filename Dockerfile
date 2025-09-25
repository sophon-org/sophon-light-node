FROM ubuntu:latest

ARG BUILD_TYPE=prod

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    jq \
    file \
    coreutils \
    bc \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -g 1001 sophon && \
    useradd -u 1001 -g sophon -m -s /bin/bash sophon

WORKDIR /app

RUN echo "${BUILD_TYPE}" > environment

# download binary based on the image tag
RUN set -x && \
    GITHUB_BASE_URL="https://api.github.com/repos/sophon-org/sophon-light-node/releases" && \
    if [ "$(cat environment)" = "stg" ]; then \
    RELEASE_INFO=$(curl -s ${GITHUB_BASE_URL} | jq '[.[] | select(.prerelease == true)][0]'); \
    else \
    RELEASE_INFO=$(curl -s ${GITHUB_BASE_URL}/latest); \
    fi && \
    BINARY_FILE_ID=$(echo "${RELEASE_INFO}" | jq -r '.assets[0] | select(.name | endswith("tar.gz")) | .id') && \
    BINARY_FILE_NAME=$(echo "${RELEASE_INFO}" | jq -r '.assets[0] | select(.name | endswith("tar.gz")) | .name') && \
    curl -L -H "Accept: application/octet-stream" "${GITHUB_BASE_URL}/assets/${BINARY_FILE_ID}" -o "${BINARY_FILE_NAME}" && \
    tar -xzvf "${BINARY_FILE_NAME}" && \
    rm "${BINARY_FILE_NAME}" && \
    chmod +x sophon-node

RUN chown -R sophon:sophon /app && \
    chmod -R 775 /app

ENTRYPOINT ["/bin/sh", "-c"]
CMD ["/app/sophon-node ${OPERATOR_ADDRESS:+--operator $OPERATOR_ADDRESS} ${DESTINATION_ADDRESS:+--destination $DESTINATION_ADDRESS} ${PERCENTAGE:+--percentage $PERCENTAGE} ${IDENTITY:+--identity $IDENTITY} ${PUBLIC_DOMAIN:+--public-domain $PUBLIC_DOMAIN} ${MONITOR_URL:+--monitor-url $MONITOR_URL} ${NETWORK:+--network $NETWORK} ${AUTO_UPGRADE:+--auto-upgrade $AUTO_UPGRADE} ${OVERWRITE_CONFIG:+--overwrite-config $OVERWRITE_CONFIG}"]