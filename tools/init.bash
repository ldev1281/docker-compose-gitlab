#!/usr/bin/env bash
set -Eeuo pipefail

# -------------------------------------
# GitLab setup script
# -------------------------------------

# Get the absolute path of script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
VOL_DIR="${SCRIPT_DIR}/../vol"
BACKUP_TASKS_SRC_DIR="${SCRIPT_DIR}/../etc/limbo-backup/rsync.conf.d"
BACKUP_TASKS_DST_DIR="/etc/limbo-backup/rsync.conf.d"

REQUIRED_TOOLS="docker limbo-backup.bash"
REQUIRED_NETS="proxy-client-gitlab"
BACKUP_TASKS="10-gitlab.conf.bash"

CURRENT_GITLAB_VERSION="18.3.6-ee.0"






check_requirements() {
    missed_tools=()
    for cmd in $REQUIRED_TOOLS; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missed_tools+=("$cmd")
        fi
    done

    if ((${#missed_tools[@]})); then
        echo "Required tools not found:" >&2
        for cmd in "${missed_tools[@]}"; do
            echo "  - $cmd" >&2
        done
        echo "Hint: run dev-prod-init.recipe from debian-setup-factory" >&2
        echo "Abort"
        exit 127
    fi
}

create_networks() {
    for net in $REQUIRED_NETS; do
        if docker network inspect "$net" >/dev/null 2>&1; then
            echo "Required network already exists: $net"
        else
            echo "Creating required docker network: $net (driver=bridge)"
            docker network create --driver bridge --internal "$net" >/dev/null
        fi
    done
}

create_backup_tasks() {
    for task in $BACKUP_TASKS; do
        src_file="${BACKUP_TASKS_SRC_DIR}/${task}"
        dst_file="${BACKUP_TASKS_DST_DIR}/${task}"

        if [[ ! -f "$src_file" ]]; then
            echo "Warning: backup task not found: $src_file" >&2
            continue
        fi

        cp "$src_file" "$dst_file"
        echo "Created backup task: $dst_file"
    done
}

# Load existing configuration from .env file
load_existing_env() {
    set -o allexport
    source "$ENV_FILE"
    set +o allexport
}

# Prompt user to confirm or update configuration
prompt_for_configuration() {
    echo "Please enter configuration values (press Enter to keep current/default value):"
    echo ""

    GITLAB_VERSION=${CURRENT_GITLAB_VERSION}

    read -p "GITLAB_APP_HOSTNAME [${GITLAB_APP_HOSTNAME:-gitlab.example.com}]: " input
    GITLAB_APP_HOSTNAME=${input:-${GITLAB_APP_HOSTNAME:-gitlab.example.com}}

    read -p "GITLAB_EXTERNAL_URL [${GITLAB_EXTERNAL_URL:-https://$GITLAB_APP_HOSTNAME}]: " input
    GITLAB_EXTERNAL_URL=${input:-${GITLAB_EXTERNAL_URL:-https://$GITLAB_APP_HOSTNAME}}

    read -p "GITLAB_SSH_PORT [${GITLAB_SSH_PORT:-22}]: " input
    GITLAB_SSH_PORT=${input:-${GITLAB_SSH_PORT:-22}}

    read -p "GITLAB_INTERNAL_HTTP_PORT [${GITLAB_INTERNAL_HTTP_PORT:-8182}]: " input
    GITLAB_INTERNAL_HTTP_PORT=${input:-${GITLAB_INTERNAL_HTTP_PORT:-8182}}

    read -p "GITLAB_SHM_SIZE [${GITLAB_SHM_SIZE:-256m}]: " input
    GITLAB_SHM_SIZE=${input:-${GITLAB_SHM_SIZE:-256m}}

    echo ""
    echo "SMTP settings:"
    read -p "GITLAB_SMTP_HOST [${GITLAB_SMTP_HOST:-smtp.mailgun.org}]: " input
    GITLAB_SMTP_HOST=${input:-${GITLAB_SMTP_HOST:-smtp.mailgun.org}}

    read -p "GITLAB_SMTP_PORT [${GITLAB_SMTP_PORT:-587}]: " input
    GITLAB_SMTP_PORT=${input:-${GITLAB_SMTP_PORT:-587}}

    read -p "GITLAB_SMTP_USERNAME [${GITLAB_SMTP_USERNAME:-gitlab@sandbox123.mailgun.org}]: " input
    GITLAB_SMTP_USERNAME=${input:-${GITLAB_SMTP_USERNAME:-gitlab@sandbox123.mailgun.org}}

    read -p "GITLAB_SMTP_PASSWORD [${GITLAB_SMTP_PASSWORD:-password}]: " input
    GITLAB_SMTP_PASSWORD=${input:-${GITLAB_SMTP_PASSWORD:-password}}

    read -p "GITLAB_SMTP_AUTH (plain/login/cram_md5) [${GITLAB_SMTP_AUTH:-login}]: " input
    GITLAB_SMTP_AUTH=${input:-${GITLAB_SMTP_AUTH:-login}}

    read -p "GITLAB_SMTP_STARTTLS (true/false) [${GITLAB_SMTP_STARTTLS:-true}]: " input
    GITLAB_SMTP_STARTTLS=${input:-${GITLAB_SMTP_STARTTLS:-true}}

    read -p "GITLAB_SMTP_TLS (true/false) [${GITLAB_SMTP_TLS:-false}]: " input
    GITLAB_SMTP_TLS=${input:-${GITLAB_SMTP_TLS:-false}}

    read -p "GITLAB_EMAIL_DISPLAY_NAME [${GITLAB_EMAIL_DISPLAY_NAME:-GitLab}]: " input
    GITLAB_EMAIL_DISPLAY_NAME=${input:-${GITLAB_EMAIL_DISPLAY_NAME:-GitLab}}

    echo ""
    echo "Registry:"
    read -p "GITLAB_REGISTRY_URL [${GITLAB_REGISTRY_URL:-registry.example.com}]: " input
    GITLAB_REGISTRY_URL=${input:-${GITLAB_REGISTRY_URL:-registry.example.com}}

    read -p "GITLAB_INTERNAL_REGISTRY_PORT [${GITLAB_INTERNAL_REGISTRY_PORT:-5005}]: " input
    GITLAB_INTERNAL_REGISTRY_PORT=${input:-${GITLAB_INTERNAL_REGISTRY_PORT:-5005}}

    echo ""
    echo "Authentik OIDC:"
    read -p "GITLAB_AUTHENTIK_LABEL [${GITLAB_AUTHENTIK_LABEL:-Authentik}]: " input
    GITLAB_AUTHENTIK_LABEL=${input:-${GITLAB_AUTHENTIK_LABEL:-Authentik}}

    read -p "GITLAB_AUTHENTIK_URL [${GITLAB_AUTHENTIK_URL:-authentik.example.com}]: " input
    GITLAB_AUTHENTIK_URL=${input:-${GITLAB_AUTHENTIK_URL:-authentik.example.com}}

    read -p "GITLAB_AUTHENTIK_SLUG [${GITLAB_AUTHENTIK_SLUG:-gitlab}]: " input
    GITLAB_AUTHENTIK_SLUG=${input:-${GITLAB_AUTHENTIK_SLUG:-gitlab}}

    read -p "GITLAB_AUTHENTIK_CLIENT_ID [${GITLAB_AUTHENTIK_CLIENT_ID:-}]: " input
    GITLAB_AUTHENTIK_CLIENT_ID=${input:-${GITLAB_AUTHENTIK_CLIENT_ID:-}}

    read -p "GITLAB_AUTHENTIK_CLIENT_SECRET [${GITLAB_AUTHENTIK_CLIENT_SECRET:-}]: " input
    GITLAB_AUTHENTIK_CLIENT_SECRET=${input:-${GITLAB_AUTHENTIK_CLIENT_SECRET:-}}
}

# Display configuration and ask user to confirm
confirm_and_save_configuration() {
    CONFIG_LINES=(
        "# GitLab"
        "GITLAB_VERSION=${GITLAB_VERSION}"
        "GITLAB_APP_HOSTNAME=${GITLAB_APP_HOSTNAME}"
        "GITLAB_EXTERNAL_URL=${GITLAB_EXTERNAL_URL}"
        "GITLAB_SSH_PORT=${GITLAB_SSH_PORT}"
        "GITLAB_INTERNAL_HTTP_PORT=${GITLAB_INTERNAL_HTTP_PORT}"
        "GITLAB_SHM_SIZE=${GITLAB_SHM_SIZE}"
        ""
        "# SMTP"
        "GITLAB_SMTP_ENABLE=true"
        "GITLAB_SMTP_HOST=${GITLAB_SMTP_HOST}"
        "GITLAB_SMTP_PORT=${GITLAB_SMTP_PORT}"
        "GITLAB_SMTP_USERNAME=${GITLAB_SMTP_USERNAME}"
        "GITLAB_SMTP_PASSWORD='${GITLAB_SMTP_PASSWORD}'"
        "GITLAB_SMTP_AUTH=${GITLAB_SMTP_AUTH}"
        "GITLAB_SMTP_STARTTLS=${GITLAB_SMTP_STARTTLS}"
        "GITLAB_SMTP_TLS=${GITLAB_SMTP_TLS}"
        "GITLAB_EMAIL_DISPLAY_NAME=${GITLAB_EMAIL_DISPLAY_NAME}"
        ""
        "# Registry"
        "GITLAB_REGISTRY_URL=${GITLAB_REGISTRY_URL}"
        "GITLAB_INTERNAL_REGISTRY_PORT=${GITLAB_INTERNAL_REGISTRY_PORT}"
        ""
        "# Authentik OIDC"
        "GITLAB_AUTHENTIK_LABEL=${GITLAB_AUTHENTIK_LABEL}"
        "GITLAB_AUTHENTIK_URL=${GITLAB_AUTHENTIK_URL}"
        "GITLAB_AUTHENTIK_SLUG=${GITLAB_AUTHENTIK_SLUG}"
        "GITLAB_AUTHENTIK_CLIENT_ID=${GITLAB_AUTHENTIK_CLIENT_ID}"
        "GITLAB_AUTHENTIK_CLIENT_SECRET=${GITLAB_AUTHENTIK_CLIENT_SECRET}"
    )

    echo ""
    echo "The following environment configuration will be saved:"
    echo "-----------------------------------------------------"
    for line in "${CONFIG_LINES[@]}"; do
        echo "$line"
    done
    echo "-----------------------------------------------------"
    echo ""

    while :; do
        read -p "Proceed with this configuration? (y/n): " CONFIRM
        [[ "$CONFIRM" == "y" ]] && break
        [[ "$CONFIRM" == "n" ]] && { echo "Configuration aborted by user."; exit 1; }
    done

    printf "%s\n" "${CONFIG_LINES[@]}" >"$ENV_FILE"
    echo ".env file saved to $ENV_FILE"
    echo ""
}

# Set up containers
setup_containers() {
    echo "Stopping all containers and removing volumes..."
    docker compose down -v

    if [ -d "$VOL_DIR" ]; then
        echo "The 'vol' directory exists:"
        echo " - In case of a new install type 'y' to clear its contents. WARNING! This will remove all previous configuration files and stored data."
        echo " - In case of an upgrade/installing a new application type 'n' (or press Enter)."
        read -p "Clear it now? (y/N): " CONFIRM
        echo ""
        if [[ "$CONFIRM" == "y" ]]; then
            echo "Clearing 'vol' directory..."
            rm -rf "${VOL_DIR:?}"/*
        fi
    fi

    echo "Starting containers..."
    docker compose up -d

    echo "Waiting 20 seconds for services to initialize..."
    sleep 20
    docker exec gitlab-app bash -lc "test -f /etc/gitlab/initial_root_password && cat /etc/gitlab/initial_root_password || true"
    echo ""
    echo "By default, you can access GitLab at ${GITLAB_EXTERNAL_URL} and log in via Authentik."
    echo "In case something goes wrong with the configuration or you need to log in as admin,"
    echo "you can use the URL:"
    echo "${GITLAB_EXTERNAL_URL}/users/sign_in?auto_sign_in=false"
    echo "to log in using the built-in authentication."
    echo ""
    
}

# -----------------------------------
# Main logic
# -----------------------------------
check_requirements

if [ -f "$ENV_FILE" ]; then
    echo ".env file found. Loading existing configuration."
    load_existing_env
else
    echo ".env file not found. Generating defaults."
fi

prompt_for_configuration
confirm_and_save_configuration
create_networks
create_backup_tasks
setup_containers