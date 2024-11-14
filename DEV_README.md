
# Avail Light Client

## Documentation

This repo contains a Docker image that:
- downloads the latest release of the Sophon Light node
- runs the node which:
  - runs the node via Avail
  - registers the node on Sophon's monitor

This docker image is currently deployed on [Docker Hub: @sophonhub/sophon-light-node](https://hub.docker.com/repository/docker/sophonhub/sophon-light-node/general)

### Development
- The light node entrypoint is the `main.sh` script which runs 2 scripts:
  -  [availup.sh](https://github.com/availproject/availup/blob/main/availup.sh), which actually runs the light node and must expose both the API and WS externally (0.0.0.0) 
  -  `register_lc.sh`, to register itself on Sophon's monitor by making an endpoint call

### Registration
Nodes need to be registered on Sophon's monitor so we can track a node's activity to be able to reward node runners accordingly. 

The registration happens automatically and is done through an endpoint call to `POST /nodes` which receives. See required params on [README.md](README.md)
  
## Running a node directly

Note that `--operator` is only required if you want to participate on the rewards programme. If set, you must also set `--public-domain` and `--monitor-url`
```bash
./main.sh --operator YOUR_OPERATOR_ADDRESS --destination DESINATION_ADDRESS --percentage 0.5 --public-domain YOUR_PUBLIC_DOMAIN --monitor-url SOPHON_MONITOR_URL
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
    ./main.sh --operator YOUR_OPERATOR_ADDRESS --destination DESINATION_ADDRESS --percentage 0.5 --public-domain YOUR_PUBLIC_DOMAIN --monitor-url SOPHON_MONITOR_URL
    ```

## Continous deployment
When pushing to `main` brach, there are 2 Github worklows running:
- release.yml: this workflow performs several actions
  - increments Cargo.yaml version (and pushes the commit)
  - creates a git tag
  - build the release (cargo build)
  - compresses the binary files
  - creates the Github release
  - uploads the compressed file
- docker.yml
  - build the docker image
  - pushes the updated image to Dockerhub