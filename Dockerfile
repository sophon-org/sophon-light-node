FROM ubuntu:latest AS builder

WORKDIR /app

# install required packages
RUN apt-get update \
    && apt-get install -y gcc curl sed jq build-essential pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# install rust
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y

ENV PATH="/root/.cargo/bin:${PATH}"

COPY ./Cargo.toml .
COPY ./main.rs .

# build rust script
RUN cargo build --release

FROM ubuntu:latest AS runner

RUN apt-get update \
    && apt-get install -y curl sed jq \
    && rm -rf /var/lib/apt/lists/* && apt-get purge -y --auto-remove

WORKDIR /app

# volume for identity.yaml
VOLUME ["/app/identity"]
ENV IDENTITY="/app/identity/identity.toml"

COPY --from=builder /app/target/release/generate_node_id ./generate_node_id

COPY ./main.sh .
COPY ./sophonup.sh .
COPY ./register_lc.sh .

RUN chmod +x main.sh
RUN chmod +x register_lc.sh

CMD ["sh", "-c", "if [ -z \"$NETWORK\" ]; then \
                    if [ -z \"$APP_ID\" ]; then \
                        if [ -z \"$OPERATOR_ADDRESS\" ]; then \
                            ./main.sh --identity $IDENTITY; \
                        else \
                            if [ -z \"$MONITOR_URL\" ]; then \
                                ./main.sh --identity $IDENTITY --wallet $OPERATOR_ADDRESS --public-domain $PUBLIC_DOMAIN; \
                            else \
                                ./main.sh --identity $IDENTITY --wallet $OPERATOR_ADDRESS --monitor-url $MONITOR_URL --public-domain $PUBLIC_DOMAIN; \
                            fi; \
                        fi; \
                    else \
                        if [ -z \"$OPERATOR_ADDRESS\" ]; then \
                            ./main.sh --identity $IDENTITY --app_id $APP_ID; \
                        else \
                            if [ -z \"$MONITOR_URL\" ]; then \
                                ./main.sh --identity $IDENTITY --wallet $OPERATOR_ADDRESS --app_id $APP_ID --public-domain $PUBLIC_DOMAIN; \
                            else \
                                ./main.sh --identity $IDENTITY --wallet $OPERATOR_ADDRESS --app_id $APP_ID --monitor-url $MONITOR_URL --public-domain $PUBLIC_DOMAIN; \
                            fi; \
                        fi; \
                    fi; \
                else \
                    if [ -z \"$APP_ID\" ]; then \
                        if [ -z \"$OPERATOR_ADDRESS\" ]; then \
                            ./main.sh --identity $IDENTITY --network $NETWORK; \
                        else \
                            if [ -z \"$MONITOR_URL\" ]; then \
                                ./main.sh --identity $IDENTITY --wallet $OPERATOR_ADDRESS --network $NETWORK --public-domain $PUBLIC_DOMAIN; \
                            else \
                                ./main.sh --identity $IDENTITY --wallet $OPERATOR_ADDRESS --network $NETWORK --monitor-url $MONITOR_URL --public-domain $PUBLIC_DOMAIN; \
                            fi; \
                        fi; \
                    else \
                        if [ -z \"$OPERATOR_ADDRESS\" ]; then \
                            ./main.sh --identity $IDENTITY --network $NETWORK --app_id $APP_ID; \
                        else \
                            if [ -z \"$MONITOR_URL\" ]; then \
                                ./main.sh --identity $IDENTITY --wallet $OPERATOR_ADDRESS --network $NETWORK --app_id $APP_ID --public-domain $PUBLIC_DOMAIN; \
                            else \
                                ./main.sh --identity $IDENTITY --wallet $OPERATOR_ADDRESS --network $NETWORK --app_id $APP_ID --monitor-url $MONITOR_URL --public-domain $PUBLIC_DOMAIN; \
                            fi; \
                        fi; \
                    fi; \
                fi"]
