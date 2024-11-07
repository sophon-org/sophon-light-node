FROM ubuntu:latest

# Install required packages
RUN apt-get update \
    && apt-get install -y curl sed jq git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# volume for identity.yaml
VOLUME ["/app/identity"]
ENV IDENTITY="/app/identity/identity.toml"

ENV APP_VERSION="1.0.0"
ENV GITHUB_TOKEN=""

COPY bootstrap.sh /app/bootstrap.sh
RUN chmod +x /app/bootstrap.sh

ENTRYPOINT ["/app/bootstrap.sh"]