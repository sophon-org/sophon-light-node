#!/bin/bash
set -euo pipefail

# Constants
readonly DEFAULT_NETWORK="mainnet"
readonly DEFAULT_MONITOR_URL="https://monitor-stg.sophon.xyz"
readonly DEFAULT_VERSION_CHECKER_INTERVAL=86400  # 1 day
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_URL="https://gist.githubusercontent.com/fedealconada/94b7e114797e1c4041d708ff6c0ad3b3/raw/sophon.yml"

# Version checks
get_latest_version_info() {
    [ -n "${GITHUB_TOKEN:-}" ] || die "GITHUB_TOKEN is required"
    curl -s -H "Authorization: token $GITHUB_TOKEN" \
        https://api.github.com/repos/sophon-org/sophon-light-node/releases/latest
}

# Get minimum version from config
get_minimum_version() {
    local config_response
    
    config_response=$(curl -s "$CONFIG_URL")
    if [ $? -ne 0 ]; then
        echo "0.0.0"
    fi

    # Extract minimum_version from YAML
    local min_version
    min_version=$(echo "$config_response" | grep "sophon_minimum_required_version" | cut -d'"' -f2 || echo "")
    
    if [ -z "$min_version" ]; then
        echo "0.0.0"
    fi
    
    echo "$min_version"
}

get_current_version() {
    if [ -f "./sophon-node" ] && [ -x "./sophon-node" ]; then
        ./sophon-node --version 2>/dev/null || echo "0.0.0"
    else
        # If running locally, check in target/release
        if [ -f "./target/release/sophon-node" ] && [ -x "./target/release/sophon-node" ]; then
            ./target/release/sophon-node --version 2>/dev/null || echo "0.0.0"
        else
            echo "0.0.0"
        fi
    fi
}

compare_versions() {
    if [[ "$1" == "$2" ]]; then
        echo 0
    elif [[ "$(echo -e "$1\n$2" | sort -V | head -n1)" == "$1" ]]; then
        echo -1  # v1 is lower
    else
        echo 1   # v1 is higher
    fi
}

update_version() {
    local latest_version="$1"
    log "📥 Downloading version $latest_version..."

    # Get release info
    local release_info=$(get_latest_version_info)
    local asset_url=$(echo "$release_info" | jq -r '.assets[0].url')
    local binary_name=$(echo "$release_info" | jq -r '.assets[0].name')
    
    if [ -z "$asset_url" ] || [ "$asset_url" = "null" ]; then
        die "Error: No assets found in release"
    fi

    # Create temp directory for update
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"

    log "🔍 Downloading from: $asset_url"
    curl -L \
         -H "Authorization: token $GITHUB_TOKEN" \
         -H "Accept: application/octet-stream" \
         -o "$binary_name" \
         "$asset_url"

    # Verify download
    if [ ! -f "$binary_name" ] || [ ! -s "$binary_name" ]; then
        rm -rf "$temp_dir"
        die "Error: Download failed or file is empty"
    fi

    # Basic tar check
    if ! tar -tzf "$binary_name" >/dev/null 2>&1; then
        rm -rf "$temp_dir"
        die "Error: Downloaded file is not a valid tar.gz archive"
    fi

    # Extract archive
    log "📦 Extracting new version..."
    tar -xzf "$binary_name" || {
        rm -rf "$temp_dir"
        die "Error: Failed to extract archive"
    }

    # Look for the binary (assuming it's named sophon-node or has similar name)
    local extracted_binary
    for possible_name in "sophon-node" "sophon" "node"; do
        if [ -f "$possible_name" ]; then
            extracted_binary="$possible_name"
            break
        fi
    done

    if [ -z "${extracted_binary:-}" ]; then
        # If not found by name, take the first file that's not the archive
        extracted_binary=$(ls -1 | grep -v "$binary_name" | head -n1)
    fi

    if [ -z "${extracted_binary:-}" ]; then
        rm -rf "$temp_dir"
        die "Error: Could not find binary in archive"
    fi

    # Update binary
    log "🔄 Updating binary..."
    chmod +x "$extracted_binary"
    mv "$extracted_binary" "$SCRIPT_DIR/sophon-node"

    # Cleanup
    cd - > /dev/null
    rm -rf "$temp_dir"

    log "✅ Successfully updated to version $latest_version!"
    return 0
}

check_version() {
    local auto_upgrade="${1:-false}"
    log "🔍 Checking version requirements..."
    
    # Get latest version
    local latest_version
    latest_version=$(get_latest_version_info | jq -r '.tag_name')

    # Get current version
    local current_version
    current_version=$(get_current_version)

    # Get minimum version
    local minimum_version
    minimum_version=$(get_minimum_version)

    log "🔔 Minimum required version: $minimum_version"
    log "🔔 Current version: $current_version"
    log "🔔 Latest version: $latest_version"

    # If current version is 0.0.0, assume it's a new installation
    if [ "$current_version" = "0.0.0" ]; then
        log "🚀 New installation detected"
        return 1
    fi
    
    # Check minimum version requirement first
    if [ $(compare_versions $current_version $minimum_version) -lt 0 ]; then
        die "Current version ($current_version) is below minimum required version ($minimum_version). Please update."
    fi
    
    # Check if update is available
    if [ $(compare_versions "$current_version" "$latest_version") -lt 0 ]; then
        if [ "$auto_upgrade" = "true" ]; then
            log "🔄 Auto-upgrade enabled. Upgrading from $current_version to $latest_version..."
            if update_version "$latest_version"; then
                return 0  # Signal to restart
            else
                log "❌ Update failed, continuing with current version"
                return 1
            fi
        else
            log "+$(printf '%*s' "100" | tr ' ' '-')+"
            log "| ⚠️  You are running version $current_version. Latest version is $latest_version"
            log "| ⚠️  Consider upgrading or use --auto-upgrade true to enable automatic updates. If you're using the Docker image, you can set \`AUTO_UPGRADE=true\` in your environment."
            log "+$(printf '%*s' "100" | tr ' ' '-')+"
            return 1
        fi
    else
        log "✅ Running latest version: $current_version"
        return 1
    fi
}

# Function definitions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

die() {
    log "❌ $1" >&2
    exit 1
}

validate_requirements() {
    [ -f "$SCRIPT_DIR/register_lc.sh" ] || die "register_lc.sh not found"
    chmod +x "$SCRIPT_DIR/register_lc.sh"    
    command -v jq >/dev/null 2>&1 || die "jq is required but not installed"
    command -v curl >/dev/null 2>&1 || die "curl is required but not installed"
}

parse_args() {
    # Initialize variables with defaults
    network="$DEFAULT_NETWORK"
    monitor_url="$DEFAULT_MONITOR_URL"
    operator=""
    destination=""
    percentage=""
    public_domain=""
    identity="$HOME/.avail/identity/identity.toml"
    auto_upgrade="false" 
    VERSION_CHECKER_INTERVAL="${VERSION_CHECKER_INTERVAL:-$DEFAULT_VERSION_CHECKER_INTERVAL}"

    # Parse command line arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --operator)
                operator="$2"
                shift 2
                ;;
            --destination)
                destination="$2"
                shift 2
                ;;
            --percentage)
                percentage="$2"
                shift 2
                ;;
            --identity)
                identity="$2"
                shift 2
                ;;
            --public-domain)
                public_domain="$2"
                shift 2
                ;;
            --monitor-url)
                monitor_url="$2"
                shift 2
                ;;
            --network)
                network="$2"
                shift 2
                ;;
            --auto-upgrade)
                auto_upgrade="$2"
                shift 2
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    # Export variables for child scripts
    export network monitor_url operator destination percentage public_domain identity auto_upgrade
}

wait_for_node() {
    local public_domain="$1"
    # ensure public_domain starts with https:// if it doesn't contain http or https
    if [[ ! "$public_domain" =~ ^http ]]; then
        public_domain="https://$public_domain"
    fi
    local health_endpoint="$public_domain/v2/status"
    local timeout=300  # 5 minutes
    local interval=5
    local start_time
    local elapsed_time=0
    
    start_time=$(date +%s)
    
    log "🏥 Waiting for node at: $health_endpoint to be ready... ($timeout seconds remaining)"
    while [ $elapsed_time -lt $timeout ]; do
        if status_code=$(curl -s -w "%{http_code}" -o /tmp/health_response "$health_endpoint") && \
           [ "$status_code" = "200" ] && \
           response=$(cat /tmp/health_response) && \
           first_block=$(echo "$response" | jq -r '.blocks.available.first') && \
           [ "$first_block" != "null" ]; then
            log "☀️  Node is up! First available block: $first_block"
            return 0
        fi
        
        elapsed_time=$(($(date +%s) - start_time))
        remaining=$((timeout - elapsed_time))
        
        [ -n "${response:-}" ] && log "🔗 Node health response: $response"
        log "🏥 Waiting for node at: $health_endpoint to be ready... ($remaining seconds remaining)"
        sleep $interval
    done
    
    die "Timeout waiting for node to start"
}

run_node() {
    log "🏁 Running availup..."
    availup_pid=""
    avail_light_pid=""

    cleanup_and_exit() {
        local message="$1"
        log "🔍 Debug: Cleanup triggered with message: $message"
        
        if [ -n "$availup_pid" ] && ps -p $availup_pid > /dev/null 2>&1; then
            log "🔍 Debug: Killing availup process $availup_pid"
            kill $availup_pid 2>/dev/null || log "🔍 Debug: Kill failed"
        fi

        if [ -n "$avail_light_pid" ] && ps -p $avail_light_pid > /dev/null 2>&1; then
            log "🔍 Debug: Killing avail-light process $avail_light_pid"
            kill $avail_light_pid 2>/dev/null || log "🔍 Debug: Kill failed"
        fi
        exit 1
    }

    check_process_health() {
        # Only care about SIGCHLD if avail-light process dies
        if [ -n "$avail_light_pid" ] && ! ps -p $avail_light_pid > /dev/null 2>&1; then
            cleanup_and_exit "Avail-light process died unexpectedly"
        fi
    }

    # Start availup in background
    curl -sL1 avail.sh | bash -s -- \
        --network "$network" \
        --config_url "$CONFIG_URL" \
        --upgrade $auto_upgrade \
        --identity "$identity" > >(while read -r line; do
            log "$line"
        done) \
    2> >(while read -r line; do
            log "$line"
        done) &

    availup_pid=$!
    log "🔍 Availup started with PID: $availup_pid"
    
    # Set up traps
    trap 'cleanup_and_exit "Node terminated by SIGINT"' SIGINT
    trap 'cleanup_and_exit "Node terminated by SIGTERM"' SIGTERM
    trap 'check_process_health' SIGCHLD

    # Wait a bit for avail-light to start
    sleep 5
    
    # Get avail-light process PID
    avail_light_pid=$(pgrep -f "avail-light")
    if [ -n "$avail_light_pid" ]; then
        log "🔍 Avail-light process found with PID: $avail_light_pid"
    else
        log "❌ Avail-light process not found"
        cleanup_and_exit "Failed to start avail-light"
    fi

    # Only register if operator is provided
    if [ -n "$operator" ]; then
        if [ -z "$public_domain" ]; then
            die "public-domain is required when operator is specified"
        fi
        
        # Wait for node to be ready before registration
        wait_for_node "$public_domain"
        
        "$SCRIPT_DIR/register_lc.sh" \
            --operator "$operator" \
            --destination "$destination" \
            --percentage "$percentage" \
            --identity "$identity" \
            --public-domain "$public_domain" \
            --monitor-url "$monitor_url" || {
                kill $availup_pid 2>/dev/null || true
                die "Registration failed - node terminated"
            }
    else
        log "🚫" >&2
        log "🚫  [NOT ELIGIBLE FOR REWARDS] You have not provided an operator. Your Sophon light node will run but not participate in the rewards program." >&2
        log "🚫" >&2
    fi
}

wait_for_monitor() {
    local health_endpoint="$monitor_url/health"

    # Wait for monitor service
    log "🕐 Waiting for monitor service to be up..."
    until curl -s "$health_endpoint" > /dev/null; do
        log "🕐 Waiting for monitor service to be up..."
        sleep 2
    done
    
    log "✅ Monitor service is up!"
}

check_avail_config() {
    local config_endpoint="$monitor_url/configs?network=$network"
    local config_file="$HOME/.avail/$network/config/config.yml"
    local config_response
    local http_status
    
    # Fetch latest config
    log "📩 Fetching latest configuration from $config_endpoint"
    config_response=$(curl -s -w "\n%{http_code}" "$config_endpoint")
    http_status=$(echo "$config_response" | tail -n1)
    
    if [ "$http_status" -ne 200 ]; then
        die "Failed to fetch config: $(echo "$config_response" | sed '$d')"
    fi
    
    # Transform config
    CONFIG_TRANSFORM='
        to_entries[]
        | select(.key != "_id")  # Exclude the _id field
        | "\(.key)=" +
        (if (.value | type) == "string" then
            "\"" + .value + "\""
        elif (.value | type) == "array" then
            "[" + (.value | map("\"" + . + "\"") | join(",")) + "]"
        else
            .value | tostring
        end)
    '
    
    # if PORT is set, add http_server_port to the config
    if [ -n "${PORT:-}" ]; then
        log "🔌 PORT variable found: $PORT. Will configure http_server_port."
        # remove any existing http_server_port line if present and add new one
        LATEST_CONFIG=$(echo "$config_response" | sed '$d' | jq -r "$CONFIG_TRANSFORM" | grep -v "^http_server_port=")
        LATEST_CONFIG="${LATEST_CONFIG}"$'\n'"http_server_port=$PORT"
    else
        LATEST_CONFIG=$(echo "$config_response" | sed '$d' | jq -r "$CONFIG_TRANSFORM")
    fi
    
    # replace $HOME with its actual value
    LATEST_CONFIG=$(echo "$LATEST_CONFIG" | sed "s|\$HOME|$HOME|g")
    
    # Create config directory if it doesn't exist
    mkdir -p "$(dirname "$config_file")"
    
    # Check if config has changed
    if [ -f "$config_file" ]; then
        if ! diff <(echo "$LATEST_CONFIG") "$config_file" >/dev/null; then
            log "🆕 Configuration has changed. Updating..."
            echo "$LATEST_CONFIG" > "$config_file"
        else
            log "✅ Configuration up to date"
        fi
    else
        log "📝 Creating initial configuration..."
        echo "$LATEST_CONFIG" > "$config_file"
    fi
}

cleanup() {
    log "🧹 Cleaning up..."
    rm -f /tmp/health_response
    pkill -f "avail-light" || true
}

main() {
    log "+$(printf '%*s' "100" | tr ' ' '-')+"
    log "| 🚀 Starting Sophon Light Node"
    log "+$(printf '%*s' "100" | tr ' ' '-')+"

    trap cleanup EXIT
    
    validate_requirements
    parse_args "$@"
    
    wait_for_monitor
    check_version "$auto_upgrade" || true
    run_node

    # Version checking
    while true; do
        log "💤 Next version check in $VERSION_CHECKER_INTERVAL seconds..."
        sleep "$VERSION_CHECKER_INTERVAL"
        
        if check_version "$auto_upgrade" && [ "$?" -eq 0 ]; then
            log "🔄 Version update required, restarting node..."
            cleanup
            exec "$0" "$@"
        fi
    done
}

main "$@"