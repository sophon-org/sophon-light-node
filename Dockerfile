FROM ubuntu:latest

# install required packages
RUN apt-get update \
    && apt-get install -y gcc curl sed jq build-essential pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# install rust
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /app

COPY ./availup.sh .
COPY ./register_lc.sh .

COPY ./Cargo.toml .
COPY ./main.rs .

# volume for identity.yaml
VOLUME ["/app/identity"]
ENV IDENTITY="/app/identity/identity.toml"

# set default port
ENV PORT=7007

# build rust script
RUN cargo build --release

RUN chmod +x availup.sh
RUN chmod +x register_lc.sh

CMD ["sh", "-c", "if [ -z \"$NETWORK\" ]; then \
                    if [ -z \"$APP_ID\" ]; then \
                        if [ -z \"$DELEGATED_WALLET\" ]; then \
                            ./availup.sh --identity $IDENTITY; \
                        else \
                            ./availup.sh --identity $IDENTITY --wallet $DELEGATED_WALLET --monitor-url $MONITOR_URL --public-domain $PUBLIC_DOMAIN; \
                        fi; \
                    else \
                        if [ -z \"$DELEGATED_WALLET\" ]; then \
                            ./availup.sh --identity $IDENTITY --app_id $APP_ID; \
                        else \
                            ./availup.sh --identity $IDENTITY --wallet $DELEGATED_WALLET --app_id $APP_ID --monitor-url $MONITOR_URL --public-domain $PUBLIC_DOMAIN; \
                        fi; \
                    fi; \
                else \
                    if [ -z \"$APP_ID\" ]; then \
                        if [ -z \"$DELEGATED_WALLET\" ]; then \
                            ./availup.sh --identity $IDENTITY --network $NETWORK; \
                        else \
                            ./availup.sh --identity $IDENTITY --wallet $DELEGATED_WALLET --network $NETWORK --monitor-url $MONITOR_URL --public-domain $PUBLIC_DOMAIN; \
                        fi; \
                    else \
                        if [ -z \"$DELEGATED_WALLET\" ]; then \
                            ./availup.sh --identity $IDENTITY --network $NETWORK --app_id $APP_ID; \
                        else \
                            ./availup.sh --identity $IDENTITY --wallet $DELEGATED_WALLET --network $NETWORK --app_id $APP_ID --monitor-url $MONITOR_URL --public-domain $PUBLIC_DOMAIN; \
                        fi; \
                    fi; \
                fi"]

