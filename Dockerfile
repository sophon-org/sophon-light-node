ARG MONITOR_ENV=prod
FROM ubuntu:latest

# Re-declare the ARG after FROM to use in RUN commands
ARG MONITOR_ENV

# Make ARG available as ENV var for runtime
ENV MONITOR_ENV=${MONITOR_ENV}

# Install minimal dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
        file \
        coreutils \
        bc \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN set -x && \
    GITHUB_BASE_URL="https://api.github.com/repos/sophon-org/sophon-light-node/releases" && \
    if [ "${MONITOR_ENV}" = "stg" ]; then \
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

ENTRYPOINT ["/bin/sh", "-c"]
CMD ["/app/sophon-node ${MONITOR_ENV:+--env $MONITOR_ENV} ${OPERATOR_ADDRESS:+--operator $OPERATOR_ADDRESS} ${DESTINATION_ADDRESS:+--destination $DESTINATION_ADDRESS} ${PERCENTAGE:+--percentage $PERCENTAGE} ${IDENTITY:+--identity $IDENTITY} ${PUBLIC_DOMAIN:+--public-domain $PUBLIC_DOMAIN} ${MONITOR_URL:+--monitor-url $MONITOR_URL} ${NETWORK:+--network $NETWORK} ${AUTO_UPGRADE:+--auto-upgrade $AUTO_UPGRADE}"]
