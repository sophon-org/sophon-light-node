#!/bin/bash
set -euo pipefail

# Function definitions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1"
}

die() {
    log "🛑 $1" >&2
    exit 1
}

validate_requirements() {
    command -v jq >/dev/null 2>&1 || die "jq is required but not installed"
    command -v curl >/dev/null 2>&1 || die "curl is required but not installed"
    
    [ -n "${operator:-}" ] || die "\`operator\` parameter is required"
    
    # validate operator-related parameters
    if [ -n "${operator:-}" ]; then
        [ -n "${percentage:-}" ] || die "\`percentage\` parameter is required when operator is set"
        [[ "$percentage" =~ ^[0-9]+(\.[0-9]{1,2})?$ ]] || die "\`percentage\` must be a decimal value with at most 2 decimal places"
        [ -n "${public_domain:-}" ] || die "\`public-domain\` parameter is required when operator is set"
        [ -n "${identity:-}" ] || die "\`identity\` parameter is required"
        [ -n "${monitor_url:-}" ] || die "\`monitor-url\` parameter is required"
    fi
}

parse_args() {
    while [ $# -gt 0 ]; do
        if [[ $1 == "--"* ]]; then
            local key="${1/--/}"
            key="${key//-/_}"
            eval "$key=\"$2\""
            shift 2
        else
            shift
        fi
    done
}

extract_secret_uri() {
    local identity_file="$1"
    local secret_uri
    
    [ -f "$identity_file" ] || die "identity.toml file not found at $identity_file"
    
    secret_uri=$(sed -n "s/^[[:space:]]*avail_secret_uri[[:space:]]*=[[:space:]]*'\(.*\)'/\1/p" "$identity_file")
    [ -n "$secret_uri" ] || die "Could not extract avail_secret_uri from $identity_file"
    
    echo "$secret_uri"
}

generate_node_id() {
    local secret_uri="$1"
    local generator_path
    local node_id
    
    generator_path=$([ -f "./generate_node_id" ] && echo "./generate_node_id" || echo "./release/generate_node_id")
    [ -f "$generator_path" ] || die "generate_node_id binary not found"
    
    node_id=$("$generator_path" "$secret_uri") || die "Failed to generate node ID"
    [ -n "$node_id" ] || die "Generated node ID is empty"
    
    echo "$node_id"
}

register_node() {
    local endpoint="$1"
    local payload="$2"
    local response
    local http_status
    
    log "🔗 Registering node at $endpoint with payload: $payload"
    response=$(curl -s -w "\n%{http_code}" -X POST "$endpoint" \
         -H "Content-Type: application/json" \
         -d "$payload")
    
    http_status=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | sed '$d')
    warning_message=$(echo "$response_body" | jq -r '.warning // empty')
    
    case $http_status in
        200)
            log "☎️  Response: $response_body"
            if [ -n "$warning_message" ]; then
                log "⚠️"
                log "⚠️ Warning: $warning_message"
                log "⚠️"
            fi
            log "✅ Node registered/sync'd successfully!"
            ;;
        400)
            die " Bad request: $response_body"
            ;;
        403)
            log "⚠️  [NOT ELIGIBLE FOR REWARDS] The operator wallet has no delegated guardian memberships."
            log "⚠️  Node will run but won't participate in rewards program. You can get delegations later."
            return 0
            ;;
        500)
            die "Server error: $response_body"
            ;;
        *)
            die "Unexpected HTTP status code: $http_status"
            ;;
    esac
}

main() {
    log "📝 Registering Light Node on Sophon's monitor"

    parse_args "$@"
    validate_requirements
    
    # Normalize public_domain format
    [[ "$public_domain" =~ ^http ]] || public_domain="https://$public_domain"
    
    # Extract and validate secret URI
    log "🔍 Processing identity file at $identity..."
    secret_uri=$(extract_secret_uri "$identity")
    
    # Generate node ID
    node_id=$(generate_node_id "$secret_uri")
    
    # Prepare registration payload
    json_payload=$(jq -n \
    --arg identity "$node_id" \
    --arg url "$public_domain" \
    --arg operator "$operator" \
    --argjson percentage "$percentage" \
    '{identity: $identity, url: $url, operator: $operator, percentage: $percentage}')

    if [ -n "${destination:-}" ]; then
        json_payload=$(echo "$json_payload" | jq --arg destination "$destination" '.destination = $destination')
    fi

    # Display node info
    log "+$(printf '%*s' "100" | tr ' ' '-')+"
    log "| 🆔 Node identity: $node_id"
    log "| 🌐 Public domain: $public_domain"
    log "| 👛 Operator address: $operator"
    log "| 🏦 Destination address: ${destination:-N/A}"
    log "| 💰 Percentage: $percentage%"
    log "| 📡 Monitor URL: $monitor_url"
    log "+$(printf '%*s' "100" | tr ' ' '-')+"
    
    # Register node
    register_node "$monitor_url/nodes" "$json_payload"
}

main "$@"