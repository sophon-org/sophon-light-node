
# Avail Light Client

## Documentation

This repo contains a Docker image that:
- runs an Avail Light client
- registers the client on Sophon's monitor

This docker image is currently deployed on [Docker Hub: @sophonhub/sophon-light-node](https://hub.docker.com/repository/docker/sophonhub/sophon-light-node/general)

### Development
- The light client is ran using the `sophonup.sh` script which has been modified from the original ([sophonup.sh](https://github.com/availproject/availup/blob/main/availup.sh)) to:
  - exposes API end WS externally (0.0.0.0).
  - register itself on Sophon's monitor by making an endpoint call

### Registration
Nodes need to be registered on Avail's monitor so we can track a node's activity to be able to reward node runners accordingly. 

The registration happens automatically when using this Docker image and is done through an endpoint call to `POST /nodes` which receives:
- node ID address (automatically generated)
- domain URL: it reads the `PUBLIC_DOMAIN` env. If using the Railway template, this is automatically populated with `RAILWAY_SERVICE_URL` environment variable that is injected on deployments). *If you want to use other infra than Railway you need to define `PUBLIC_DOMAIN` manually with your domain URL*
- **delegated wallet address** this is a required address you need to pass so we establish the link between the node running and who's running it
  
## Running a node

**Running on Docker**
```bash
# copy .env.example on .env file 
# (make sure you set the ENV variables)
cp .env.example .env

# build docker image
docker build -t sophon-light-node .

# run image
docker run --env-file .env sophon-light-node
```

**Running directly**
Note that `--wallet` is only required if you want to participate on the rewards programme. If set, you must also set `--public-domain` and `--monitor-url`  
```bash
./sophonup.sh --wallet YOUR_DELEGATED_WALLET --public-domain YOUR_PUBLIC_DOMAIN --monitor-url SOPHON_MONITOR_URL
```

## Format

```bash
cargo fmt
```

## Running

1. **Build the project**:
    ```bash
    cargo build --release
    ```

2. **Run the script**:

    ```bash
    ./sophonup.sh --wallet YOUR_DELEGATE_WALLET ./identity --monitor-url SOPHON_MONITOR_URL --public-domain YOUR_PUBLIC_DOMAIN
    ```

## Update image
To update image on DockerHub:
```bash
$ docker build --platform linux/amd64 -t sophon-light-node .
$ docker tag sophon-light-node sophonhub/sophon-light-node:latest
$ docker push sophonhub/sophon-light-node:latest
```