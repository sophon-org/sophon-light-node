#!/bin/bash
set -euo pipefail

# Constants
readonly DEFAULT_NETWORK="mainnet"
readonly PROD_MONITOR_URL="https://monitor.sophon.xyz"
readonly STG_MONITOR_URL="https://monitor-stg.sophon.xyz"
readonly DEFAULT_VERSION_CHECKER_INTERVAL=86400  # 1 day
readonly DEFAULT_ENV="prod"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CONFIG_URL="https://raw.githubusercontent.com/sophon-org/sophon-light-node/refs/heads/main/src/light-node/config.yml"

# Version checks
get_latest_version_info() {
    if [ $1 = "stg" ]; then
        result=$(curl -s -H "Cache-Control: no-cache" https://api.github.com/repos/sophon-org/sophon-light-node/releases |
            jq '[.[] | select(.prerelease == true)][0]')
        if [ -z "$result" ]; then
            echo "No staging release found."
            exit 1
        fi
        echo "$result"
    else
        curl -s -H "Cache-Control: no-cache" https://api.github.com/repos/sophon-org/sophon-light-node/releases/latest
    fi
}

get_latest_version() {
    # returns raw tag without the 'v' prefix
    echo $(get_latest_version_info $1 | jq -r '.tag_name' | sed 's/^v//')
}

get_minimum_version() {
    local config_response
    
    config_response=$(curl -s "$CONFIG_URL")
    if [ $? -ne 0 ]; then
        echo "0.0.0"
    fi

    local min_version
    min_version=$(echo "$config_response" | grep "sophon_minimum_required_version" | cut -d'"' -f2 || echo "")
    
    if [ -z "$min_version" ]; then
        echo "0.0.0"
    fi
    
    # strip any -stg suffix for minimum version comparison
    echo "$min_version" | sed 's/-stg$//'
}

get_current_version() {
    local version="0.0.0"
    
    if [ -f "./sophon-node" ] && [ -x "./sophon-node" ]; then
        version=$(./sophon-node --version 2>/dev/null || echo "0.0.0")
    elif [ -f "./target/release/sophon-node" ] && [ -x "./target/release/sophon-node" ]; then
        version=$(./target/release/sophon-node --version 2>/dev/null || echo "0.0.0")
    fi

    # remove 'v' prefix if present
    echo "$version" | sed 's/^v//'
}

compare_versions() {
    # remove the -stg suffix if present and v prefix for comparison
    local v1=$(echo "$1" | sed 's/^v//; s/-stg$//')
    local v2=$(echo "$2" | sed 's/^v//; s/-stg$//')

    if [[ -z "$v1" || -z "$v2" ]]; then
        echo "Error: Missing version input" >&2
        return 1
    fi

    if [[ "$v1" == "$v2" ]]; then
        echo 0
    elif [[ "$(echo -e "$v1\n$v2" | sort -V | head -n1)" == "$v1" ]]; then
        echo -1  # v1 is lower
    else
        echo 1   # v1 is higher
    fi
}

update_version() {
    local env="$1"
    local latest_version="$2"
    log "📥 Downloading version $latest_version..."

    # Get release info
    local release_info=$(get_latest_version_info $env)
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
    log "🔍 Checking version requirements..."
    local env="$1"
    local auto_upgrade="${2:-false}"


    # if staging environment, we skip the version check
    if [ "$env" = "stg" ]; then
        log "🔍 Skipping version check for staging environment"
        return 1
    fi

    local latest_version current_version minimum_version
    { 
        latest_version=$(get_latest_version $env)
        current_version=$(get_current_version)
        minimum_version=$(get_minimum_version)
    } 2>/dev/null

    # If current version is 0.0.0, assume it's a new installation
    if [ "$current_version" = "0.0.0" ]; then
        log "🚀 New installation detected"
        return 1
    fi
    
    # If below minimum version - die
    if [ $(compare_versions $current_version $minimum_version) -lt 0 ]; then
        die "Current version ($current_version) is below minimum required version ($minimum_version). Node process will be terminated."
    fi

    # Check if update is available
    if [ $(compare_versions $current_version $latest_version) -lt 0 ]; then
       if [ "$auto_upgrade" = "true" ]; then
           log "$(box "🔔 [VERSION OUTDATED]" "🔄 Auto-upgrade enabled. Upgrading from $current_version to $latest_version...")"
           if update_version "$env" "$latest_version"; then
               return 0  # Signal to restart
           else
               log "❌ Update failed, continuing with current version."
               return 1
           fi
       else
           log "$(box "🔔 [VERSION OUTDATED]" "🔔 Minimum required version: $minimum_version
| 🔔 Current version: $current_version
| 🔔 Latest version: $latest_version
| 🔔 Consider upgrading or use --auto-upgrade true to enable automatic updates.")"
           return 1
       fi
   fi

   log "✅ Running latest version: $current_version"
   return 1
}

# Function definitions
box() {
    local title="$1"
    local message="${2:-}"
    
    if [ -z "$message" ]; then
        # only print title
        cat << EOF

+$(printf '%*s' "100" | tr ' ' '-')+
| $title
+$(printf '%*s' "100" | tr ' ' '-')+
EOF
    else
        # print title and message
        cat << EOF

+$(printf '%*s' "100" | tr ' ' '-')+
| $title
| $message
+$(printf '%*s' "100" | tr ' ' '-')+
EOF
    fi
}

log() {
    local message="$(date '+%Y-%m-%d %H:%M:%S') $1"
    echo -e "$message"
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
    
    # validate operator-related parameters
    if [ -n "${operator:-}" ]; then
        [ -n "${percentage:-}" ] || die "\`percentage\` parameter is required when operator is set"
        [[ "$percentage" =~ ^[0-9]+(\.[0-9]{1,2})?$ ]] || die "\`percentage\` must be a decimal value with at most 2 decimal places"
        [ -n "${public_domain:-}" ] || die "\`public-domain\` parameter is required when operator is set"
        [ -n "${identity:-}" ] || die "\`identity\` parameter is required"
        [ -n "${monitor_url:-}" ] || die "\`monitor-url\` parameter is required"
    fi
}

detect_environment() {
    # try environment config file in current directory
    if [ -f "environment" ]; then
        cat environment
    else
        # default to prod for local development
        echo "prod"
    fi
}

parse_args() {
    # Initialize variables with defaults
    env="$DEFAULT_ENV"
    network="$DEFAULT_NETWORK"
    operator=""
    destination=""
    percentage=""
    public_domain=""
    identity="$HOME/.avail/identity/identity.toml"
    auto_upgrade="false"
    overwrite_config="true"
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
            --overwrite-config)
                overwrite_config="$2"
                shift 2
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    # read the baked-in environment that can't be overridden
    env=$(detect_environment)
    log "🔍 Environment: $env"

    # set monitor_url based on baked-in environment
    case "$env" in
        stg)
            monitor_url="$STG_MONITOR_URL"
            ;;
        *)
            monitor_url="$PROD_MONITOR_URL"
            ;;
    esac
    log "🔍 Monitor URL: $monitor_url"

    # export variables for child scripts
    export env network monitor_url operator destination percentage public_domain identity auto_upgrade
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
            log "☀️ Node is up! First available block: $first_block"
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
        
        if [ -n "$availup_pid" ]; then
            log "🔍 Debug: Killing availup process $availup_pid"
            kill "$availup_pid" 2>/dev/null || true
        fi

        if [ -n "$avail_light_pid" ]; then
            log "🔍 Debug: Killing avail-light process $avail_light_pid"
            kill "$avail_light_pid" 2>/dev/null || true
        fi
        exit 1
    }

    check_process_health() {
        # Only care about SIGCHLD if avail-light process dies
        if [ -n "$avail_light_pid" ] && ! ps -p $avail_light_pid > /dev/null 2>&1; then
            cleanup_and_exit "Avail-light process died unexpectedly"
        fi
    }

    # Check if we need custom config
    config_file=$(create_avail_config)

    # Convert true/false to yes/no for upgrade parameter
    avail_upgrade_value=$([ "$auto_upgrade" = "true" ] && echo "y" || echo "n")

    # Start availup in background
    curl -sL1 avail.sh | bash -s -- \
        --network "$network" \
        --config "$config_file" \
        --upgrade $avail_upgrade_value \
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
        cleanup_and_exit
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
        log "$(box "🔔 [NOT ELIGIBLE FOR REWARDS]" "🔔 You have not provided an operator address. Your Sophon Light Node will run but not participate in the rewards program.")"
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

create_avail_config() {
    local config_dir="$HOME/.avail/$network/config"
    local config_file="$config_dir/config.yml"
    
    if [ -e "$config_file" ] && [ "$overwrite_config" != "true" ]; then
        echo "$config_file"
    else
        # Create config directory if it doesn't exist
        mkdir -p "$config_dir"

        # Download config file
        curl -s -H "Cache-Control: no-cache" "$CONFIG_URL" -o "$config_file"

        # if PORT is set, update the port in the config file
        if [ -n "${PORT:-}" ] && [ "$PORT" != "7007" ]; then
            temp_file=$(mktemp)
            sed "s/http_server_port = .*/http_server_port = $PORT/" "$config_file" > "$temp_file"
            mv "$temp_file" "$config_file"
        fi
        echo "$config_file"
    fi
}

cleanup() {
    log "🧹 Cleaning up..."
    
    if [ -n "${availup_pid:-}" ]; then
        kill "$availup_pid" 2>/dev/null || true
    fi
    
    if [ -n "${avail_light_pid:-}" ]; then
        kill "$avail_light_pid" 2>/dev/null || true
    fi

    # clean temporary files
    rm -f /tmp/health_response
    find /tmp -name "sophon-*" -mtime +1 -delete 2>/dev/null || true
}

check_memory_details() {
    if [ -z "$avail_light_pid" ]; then
        return 1
    fi
    
    local stats=$(ps -p "$avail_light_pid" -o rss=,vsz=,%mem=)
    read rss vsz mem <<< "$stats"
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') RSS:${rss}KB VSZ:${vsz}KB MEM:${mem}%" >> memory_trends.log
    
    if [ "$previous_rss" -gt 0 ] && [ "$rss" -gt "$previous_rss" ]; then
        log "🔔 Memory increased: ${previous_rss}KB -> ${rss}KB (Δ=$((rss - previous_rss))KB)"
    fi
    previous_rss=$rss
}

check_process_memory() {
   pgrep -f "avail-light" | xargs ps -o rss= -p | awk '{printf "%.2f", $1/1024}'
}

declare -i previous_rss=0

main() {

    log "$(box "🚀 Starting Sophon Light Node")"
    
    trap cleanup EXIT

    parse_args "$@"
    validate_requirements
    
    wait_for_monitor
    check_version "$env" "$auto_upgrade" || true
    run_node
    
    # Version checking
    previous=0
    while true; do
        log "💤 Next version check in $VERSION_CHECKER_INTERVAL seconds..."

        sleep "$VERSION_CHECKER_INTERVAL"
        
        # check memory usage
        current=$(check_process_memory)
        if [ -n "$current" ] && [ $(echo "$previous > 0" | bc) -eq 1 ]; then
            diff=$(echo "$current - $previous" | bc)
            log "📊 RSS: ${current}MB (Δ${diff}MB)"
        fi
        previous=$current

        if check_version "$env" "$auto_upgrade" && [ "$?" -eq 0 ]; then
            log "🔄 Version update required, restarting node..."
            cleanup
            exec "$0" "$@"
        fi
    done
}

main "$@"