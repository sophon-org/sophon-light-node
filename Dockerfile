FROM ubuntu:latest

# Install minimal required packages
RUN apt-get update \
    && apt-get install -y curl jq \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

VOLUME ["/app/identity"]
ENV IDENTITY="/app/identity/identity.toml"
ENV APP_VERSION="1.0.0"
ENV GITHUB_TOKEN=""
ENV VERSION_CHECK_INTERVAL="3600"

COPY bootstrap.sh /app/bootstrap.sh
RUN chmod +x /app/bootstrap.sh

ENTRYPOINT ["/app/bootstrap.sh"]