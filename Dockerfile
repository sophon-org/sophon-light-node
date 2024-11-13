# syntax=docker/dockerfile:1.4

# Build stage 
FROM rust:latest AS builder 
WORKDIR /usr/src/sophon

# Create a dummy project and fetch deps with cargo cache
RUN USER=root cargo init
COPY Cargo.toml Cargo.lock ./
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    cargo fetch

# Build the project with cache
COPY . .
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=/usr/src/sophon/target \
    cargo build --release --bin sophon-node --bin generate_node_id && \
    cp target/release/sophon-node /usr/src/sophon/sophon-node && \
    cp target/release/generate_node_id /usr/src/sophon/generate_node_id

# Final stage 
FROM ubuntu:latest

# Install minimal dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
        sed \
        file \
    && rm -rf /var/lib/apt/lists/*

# Create app directory 
WORKDIR /app

# Copy only the binary 
COPY --from=builder /usr/src/sophon/sophon-node /app/sophon-node 
COPY --from=builder /usr/src/sophon/generate_node_id /app/generate_node_id
COPY src/light-node/main.sh /app/main.sh
COPY src/light-node/register_lc.sh /app/register_lc.sh
RUN chmod +x /app/sophon-node /app/generate_node_id /app/main.sh /app/register_lc.sh

# Change entrypoint to use main.sh
ENTRYPOINT ["/bin/sh", "-c", "exec /app/main.sh \
    ${OPERATOR_ADDRESS:+--operator $OPERATOR_ADDRESS} \
    ${DESTINATION_ADDRESS:+--destination $DESTINATION_ADDRESS} \
    ${PERCENTAGE:+--percentage $PERCENTAGE} \
    ${IDENTITY:+--identity $IDENTITY} \
    ${PUBLIC_DOMAIN:+--public-domain $PUBLIC_DOMAIN} \
    ${MONITOR_URL:+--monitor-url $MONITOR_URL} \
    ${NETWORK:+--network $NETWORK} \
    ${AUTO_UPGRADE:+--auto-upgrade $AUTO_UPGRADE} \
    $*"]

# Health check can stay the same
# HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \ 
#     CMD curl -f http://localhost:${PORT:-7007}/v2/status || exit 1