#!/bin/bash

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NOCOLOR='\033[0m'

# Function to print colored output
print_color() {
    echo -e "${1}${2}${NOCOLOR}"
}

check_privileges() {
    local TIMEOUT=5  # Timeout for sudo authentication in seconds
    
    # Function to check if command exists
    command_exists() {
        command -v "$1" >/dev/null 2>&1
    }
    
    # Check if id command exists
    if ! command_exists "id"; then
        print_color "$RED" "Error: 'id' command not found. Cannot check user privileges."
        return 1
    fi
    
    # Get current user ID and name
    local current_uid=$(id -u)
    local current_user=$(id -un)
    
    # Check if running as root
    if [ "$current_uid" -eq 0 ]; then
        print_color "$GREEN" "Script is running as root user"
        return 0
    fi
    
    # Check if sudo command exists
    if ! command_exists "sudo"; then
        print_color "$RED" "Error: 'sudo' command not found. Cannot escalate privileges."
        return 1
    fi
    
    # Check sudo group membership
    if ! groups "$current_user" 2>/dev/null | grep -q '\bsudo\b'; then
        if ! groups "$current_user" 2>/dev/null | grep -q '\bwheel\b'; then
            print_color "$RED" "Error: User '$current_user' is not in sudo or wheel group"
            return 1
        fi
    fi
    
    # Check sudo privileges without password
    if sudo -n true 2>/dev/null; then
        print_color "$GREEN" "User has sudo privileges and is already authenticated"
        return 0
    fi
    
    # Quick sudo check with shorter timeout
    # print_color "$YELLOW" "Requesting sudo access..."
    # if ! timeout "$TIMEOUT" sudo -v; then
    #     print_color "$RED" "Sudo authentication failed"
    #     return 1
    # fi
    
    # Set up minimal sudo refresh in background
    (while sleep 240; do sudo -n true; done) &
    SUDO_KEEP_ALIVE_PID=$!
    trap 'kill $SUDO_KEEP_ALIVE_PID 2>/dev/null' EXIT
    
    print_color "$GREEN" "Sudo access confirmed"
    return 0
}


check_system_info() {
    local os_release="/etc/os-release"
    
    if [ ! -f "$os_release" ]; then
        print_color "$RED" "Error: $os_release file not found. Unable to determine system information."
        return 1
    fi
    
    if [ ! -r "$os_release" ]; then
        print_color "$RED" "Error: Cannot read $os_release. Check permissions."
        return 1
    fi
    
    # Source the OS release file
    . "$os_release"
    
    # Check if required variables exist
    if [ -z "$NAME" ]; then
        print_color "$YELLOW" "Warning: Distribution name not found"
        NAME="Unknown"
    fi
    
    if [ -z "$VERSION" ]; then
        print_color "$YELLOW" "Warning: Version information not found"
        VERSION="Unknown"
    fi
    
    if [ -z "$VERSION_CODENAME" ]; then
        print_color "$YELLOW" "Warning: Version codename not found"
        VERSION_CODENAME="Unknown"
    fi
    
    # Display system information
    print_color "$BLUE" "System Information:"
    print_color "$BLUE" "├─ Distribution: $NAME"
    print_color "$BLUE" "├─ Version: $VERSION"
    print_color "$BLUE" "└─ Codename: $VERSION_CODENAME"
    
    # Additional system information
    if command -v uname >/dev/null 2>&1; then
        local kernel_version=$(uname -r)
        print_color "$BLUE" "Additional Information:"
        print_color "$BLUE" "└─ Kernel Version: $kernel_version"
    fi
    
    return 0
}

check_ubuntu_version() {
    if [ ! -f /etc/os-release ]; then
        print_color "$RED" "/etc/os-release file not found. Unable to determine distribution."
        exit 1
    fi

    . /etc/os-release
    
    # Check if it's Ubuntu
    if [ "$NAME" != "Ubuntu" ]; then
        print_color "$RED" "This system is not Ubuntu. Found: $NAME"
        exit 1
    fi

    # Convert version to comparable number (e.g., 20.04 -> 2004)
    version_number=$(echo "$VERSION_ID" | sed 's/\.//g')
    min_version=2000  # Ubuntu 20.00

    if [ "$version_number" -ge "$min_version" ]; then
        print_color "$GREEN" "Distribution is Ubuntu $VERSION_ID. Proceeding..."
    else
        print_color "$RED" "Ubuntu version $VERSION_ID is not supported. Version 20.00 or newer required."
        exit 1
    fi
}

# Function to check command success
# check_success() {
#     if [ $? -eq 0 ]; then
#         print_color "$GREEN" "Success: $1"
#     else
#         print_color "$RED" "Error: $1 failed"
#         exit 1
#     fi
# }

check_system_compatibility() {
    local required_arch="x86_64"
    local min_ram_mb=4096  # 4GB minimum RAM
    local min_disk_mb=20480  # 20GB minimum disk space
    local compatible=true
    
    print_color "$BLUE" "Performing system compatibility checks..."
    
    # Check architecture
    if ! command -v uname >/dev/null 2>&1; then
        print_color "$RED" "Error: 'uname' command not found. Cannot check system architecture."
        return 1
    fi
    
    local arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)
            print_color "$GREEN" "✓ Architecture: $arch (Compatible)"
            ;;
        aarch64|arm64)
            print_color "$YELLOW" "⚠ Architecture: $arch (Compatible but may have limited package availability)"
            compatible=false
            ;;
        *)
            print_color "$RED" "✗ Architecture: $arch (Not compatible - x86_64 required)"
            compatible=false
            ;;
    esac
    
    # Check RAM
    if command -v free >/dev/null 2>&1; then
        local total_ram_kb=$(free | awk '/^Mem:/{print $2}')
        local total_ram_mb=$((total_ram_kb / 1024))
        
        if [ "$total_ram_mb" -lt "$min_ram_mb" ]; then
            print_color "$RED" "✗ RAM: ${total_ram_mb}MB (Minimum ${min_ram_mb}MB required)"
            compatible=false
        else
            print_color "$GREEN" "✓ RAM: ${total_ram_mb}MB (Sufficient)"
        fi
    else
        print_color "$YELLOW" "⚠ Cannot check RAM: 'free' command not available"
    fi
    
    # Check available disk space
    if command -v df >/dev/null 2>&1; then
        local available_space_kb=$(df -k . | awk 'NR==2 {print $4}')
        local available_space_mb=$((available_space_kb / 1024))
        
        if [ "$available_space_mb" -lt "$min_disk_mb" ]; then
            print_color "$RED" "✗ Disk Space: ${available_space_mb}MB (Minimum ${min_disk_mb}MB required)"
            compatible=false
        else
            print_color "$GREEN" "✓ Disk Space: ${available_space_mb}MB (Sufficient)"
        fi
    else
        print_color "$YELLOW" "⚠ Cannot check disk space: 'df' command not available"
    fi
    
    # Check virtualization support
    if command -v grep >/dev/null 2>&1; then
        if grep -E -c '(vmx|svm)' /proc/cpuinfo >/dev/null 2>&1; then
            print_color "$GREEN" "✓ Virtualization: Supported"
        else
            print_color "$YELLOW" "⚠ Virtualization: Not detected"
            compatible=false
        fi
    else
        print_color "$YELLOW" "⚠ Cannot check virtualization support"
    fi
    
    if [ "$compatible" = true ]; then
        print_color "$GREEN" "System compatibility check passed"
        return 0
    else
        print_color "$YELLOW" "System compatibility check failed - some features may not work correctly"
        return 1
    fi
}

disable_cdrom_sources() {
    local SOURCES_LIST="/etc/apt/sources.list"
    local BACKUP_DIR="/etc/apt/sources.list.d/backups"
    local BACKUP_FILE="${BACKUP_DIR}/sources.list.$(date +%Y%m%d_%H%M%S).bak"
    local TEMP_FILE="/tmp/sources.list.tmp"
    
    # Check if running with necessary privileges
    if [ "$(id -u)" -ne 0 ]; then
        if ! command -v sudo >/dev/null 2>&1; then
            print_color "$RED" "Error: This function requires root privileges and sudo is not available"
            return 1
        fi
    fi
    
    # Check if sources.list exists and is readable
    if [ ! -f "$SOURCES_LIST" ]; then
        print_color "$RED" "Error: Sources list file not found: $SOURCES_LIST"
        return 1
    fi
    
    if [ ! -r "$SOURCES_LIST" ]; then
        print_color "$RED" "Error: Cannot read sources list file: $SOURCES_LIST"
        return 1
    fi
    
    # Create backup directory if it doesn't exist
    if [ ! -d "$BACKUP_DIR" ]; then
        if ! sudo mkdir -p "$BACKUP_DIR"; then
            print_color "$RED" "Error: Failed to create backup directory: $BACKUP_DIR"
            return 1
        fi
    fi
    
    # Create backup
    if ! sudo cp -f "$SOURCES_LIST" "$BACKUP_FILE"; then
        print_color "$RED" "Error: Failed to create backup of sources.list"
        return 1
    fi
    print_color "$GREEN" "Created backup: $BACKUP_FILE"
    
    # Create temporary file
    if ! sudo cp -f "$SOURCES_LIST" "$TEMP_FILE"; then
        print_color "$RED" "Error: Failed to create temporary file"
        return 1
    fi
    
    # Process the file
    local modified=false
    while IFS= read -r line; do
        if echo "$line" | grep -qE '^[^#].*cdrom:'; then
            modified=true
            echo "# $line"
        else
            echo "$line"
        fi
    done < "$TEMP_FILE" | sudo tee "$SOURCES_LIST" > /dev/null
    
    # Clean up temporary file
    rm -f "$TEMP_FILE"
    
    # Verify changes
    if [ "$modified" = true ]; then
        print_color "$GREEN" "Successfully commented out CD-ROM repositories in $SOURCES_LIST"
        
        # Verify file integrity
        if ! sudo apt-get update -qq 2>/dev/null; then
            print_color "$RED" "Warning: sources.list may have syntax errors. Restoring backup..."
            if ! sudo cp -f "$BACKUP_FILE" "$SOURCES_LIST"; then
                print_color "$RED" "Error: Failed to restore backup"
                return 1
            fi
            print_color "$GREEN" "Backup restored successfully"
            return 1
        fi
    else
        print_color "$YELLOW" "No CD-ROM repositories found in $SOURCES_LIST"
    fi
    
    return 0
}

cleanup_docker() {
    local STOP_TIMEOUT=30
    local INCLUDE_VOLUMES=false
    local INCLUDE_NETWORKS=false
    local ERROR_COUNT=0
    
    # Parse arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --timeout) STOP_TIMEOUT="$2"; shift ;;
            --include-volumes) INCLUDE_VOLUMES=true ;;
            --include-networks) INCLUDE_NETWORKS=true ;;
            *) echo "Unknown parameter: $1"; return 1 ;;
        esac
        shift
    done
    
    # Check if Docker is installed
    if ! command -v docker &>/dev/null; then
        print_color "$GREEN" "Docker is not installed on this system."
        return 0
    fi
    
    # Check if Docker daemon is running
    if ! docker info &>/dev/null; then
        print_color "$RED" "Docker daemon is not running."
        return 1
    fi
    
    print_color "$GREEN" "Docker is installed. Starting cleanup..."
    
    # Initialize counters
    local containers_stopped=0
    local containers_removed=0
    local images_removed=0
    local volumes_removed=0
    local networks_removed=0
    
    # Stop running containers
    local running_containers=$(docker ps -q)
    if [ -n "$running_containers" ]; then
        print_color "$YELLOW" "Stopping running containers..."
        while IFS= read -r container_id; do
            if docker stop -t "$STOP_TIMEOUT" "$container_id" &>/dev/null; then
                ((containers_stopped++))
            else
                print_color "$RED" "Failed to stop container: $container_id"
                ((ERROR_COUNT++))
            fi
        done <<< "$running_containers"
    fi
    
    # Remove containers
    local all_containers=$(docker ps -a -q)
    if [ -n "$all_containers" ]; then
        print_color "$YELLOW" "Removing containers..."
        while IFS= read -r container_id; do
            if docker rm -f "$container_id" &>/dev/null; then
                ((containers_removed++))
            else
                print_color "$RED" "Failed to remove container: $container_id"
                ((ERROR_COUNT++))
            fi
        done <<< "$all_containers"
    fi
    
    # Remove images
    local images=$(docker images -a -q)
    if [ -n "$images" ]; then
        print_color "$YELLOW" "Removing images..."
        while IFS= read -r image_id; do
            if docker rmi -f "$image_id" &>/dev/null; then
                ((images_removed++))
            else
                print_color "$RED" "Failed to remove image: $image_id"
                ((ERROR_COUNT++))
            fi
        done <<< "$images"
    fi
    
    # Remove volumes if requested
    if [ "$INCLUDE_VOLUMES" = true ]; then
        local volumes=$(docker volume ls -q)
        if [ -n "$volumes" ]; then
            print_color "$YELLOW" "Removing volumes..."
            while IFS= read -r volume_id; do
                if docker volume rm -f "$volume_id" &>/dev/null; then
                    ((volumes_removed++))
                else
                    print_color "$RED" "Failed to remove volume: $volume_id"
                    ((ERROR_COUNT++))
                fi
            done <<< "$volumes"
        fi
    fi
    
    # Remove custom networks if requested
    if [ "$INCLUDE_NETWORKS" = true ]; then
        local networks=$(docker network ls --format "{{.ID}}" -f "type=custom")
        if [ -n "$networks" ]; then
            print_color "$YELLOW" "Removing custom networks..."
            while IFS= read -r network_id; do
                if docker network rm "$network_id" &>/dev/null; then
                    ((networks_removed++))
                else
                    print_color "$RED" "Failed to remove network: $network_id"
                    ((ERROR_COUNT++))
                fi
            done <<< "$networks"
        fi
    fi
    
    # Print statistics
    print_color "$GREEN" "\nDocker cleanup completed."
    print_color "$BLUE" "\nCleanup Statistics:"
    echo "Containers stopped: $containers_stopped"
    echo "Containers removed: $containers_removed"
    echo "Images removed: $images_removed"
    [ "$INCLUDE_VOLUMES" = true ] && echo "Volumes removed: $volumes_removed"
    [ "$INCLUDE_NETWORKS" = true ] && echo "Networks removed: $networks_removed"
    
    if [ "$ERROR_COUNT" -gt 0 ]; then
        print_color "$YELLOW" "\nWarning: There were $ERROR_COUNT errors during cleanup"
        return 1
    fi
    
    return 0
}

cleanup_docker_system() {
    local ERROR_COUNT=0
    local NETWORKS_REMOVED=0
    local PACKAGES_REMOVED=0
    
    # Protected networks that should not be removed
    local PROTECTED_NETWORKS=("bridge" "host" "none")
    
    # Docker packages to remove
    local DOCKER_PACKAGES=(
        "docker"
        "docker.io"
        "docker-ce"
        "docker-ce-cli"
        "containerd.io"
        "docker-buildx-plugin"
        "docker-compose-plugin"
        "containerd"
        "runc"
    )
    
    # Function to check if network is protected
    is_protected_network() {
        local network_name="$1"
        for protected in "${PROTECTED_NETWORKS[@]}"; do
            if [ "$network_name" = "$protected" ]; then
                return 0
            fi
        done
        return 1
    }
    
    # Remove custom networks
    print_color "$YELLOW" "Removing custom Docker networks..."
    
    # Get all networks
    local networks
    if ! networks=$(docker network ls --format "{{.ID}}:{{.Name}}" 2>/dev/null); then
        print_color "$RED" "Failed to list Docker networks"
        return 1
    fi
    
    # Process each network
    while IFS=: read -r network_id network_name; do
        if [ -n "$network_id" ] && ! is_protected_network "$network_name"; then
            print_color "$YELLOW" "Removing network: $network_name"
            if docker network rm "$network_id" &>/dev/null; then
                ((NETWORKS_REMOVED++))
                print_color "$GREEN" "Successfully removed network: $network_name"
            else
                print_color "$RED" "Failed to remove network: $network_name"
                ((ERROR_COUNT++))
            fi
        fi
    done <<< "$networks"
    
    # Remove old Docker packages
    print_color "$YELLOW" "Removing old Docker packages..."
    
    # Check which packages are installed
    local packages_to_remove=()
    for package in "${DOCKER_PACKAGES[@]}"; do
        if dpkg -l "$package" 2>/dev/null | grep -q '^ii'; then
            packages_to_remove+=("$package")
        fi
    done
    
    # Remove installed packages
    if [ ${#packages_to_remove[@]} -gt 0 ]; then
        if apt-get remove -y "${packages_to_remove[@]}" &>/dev/null; then
            PACKAGES_REMOVED=${#packages_to_remove[@]}
            print_color "$GREEN" "Successfully removed ${#packages_to_remove[@]} Docker packages"
            
            # Clean up package manager
            apt-get autoremove -y &>/dev/null
            apt-get clean &>/dev/null
        else
            print_color "$RED" "Failed to remove Docker packages"
            ((ERROR_COUNT++))
        fi
    else
        print_color "$GREEN" "No Docker packages to remove"
    fi
    
    # Print summary
    print_color "$GREEN" "\nCleanup Summary:"
    echo "Networks removed: $NETWORKS_REMOVED"
    echo "Packages removed: $PACKAGES_REMOVED"
    
    if [ "$ERROR_COUNT" -gt 0 ]; then
        print_color "$YELLOW" "Completed with $ERROR_COUNT errors"
        return 1
    fi
    
    return 0
}

update_package_list() {
    local TIMEOUT=300  # 5 minutes timeout
    local MIN_SPACE_MB=500
    local start_time=$(date +%s)
    local updated_sources=0
    local failed_sources=0
    
    # Check for apt/dpkg locks
    if fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; then
        print_color "$RED" "Package system is locked. Please wait for other package operations to complete"
        return 1
    fi
    
    # Create temporary files for output capture
    local temp_stdout=$(mktemp)
    local temp_stderr=$(mktemp)
    
    # Cleanup function
    cleanup() {
        rm -f "$temp_stdout" "$temp_stderr"
    }
    trap cleanup EXIT
    
    print_color "$YELLOW" "Updating package lists..."
    
    # Clean partial files
    sudo rm -f /var/lib/apt/lists/partial/* >/dev/null 2>&1
    
    # Update package lists with timeout
    if timeout "$TIMEOUT" sudo apt-get update >"$temp_stdout" 2>"$temp_stderr"; then
        # Count updated and failed sources
        updated_sources=$(grep -c "Get:" "$temp_stdout")
        failed_sources=$(grep -c "Err:" "$temp_stdout")
        
        # Calculate duration
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        print_color "$BLUE" "\nUpdate Summary:"
        echo "Duration: $duration seconds"
        echo "Updated sources: $updated_sources"
        echo "Failed sources: $failed_sources"
        
        if [ "$failed_sources" -gt 0 ]; then
            print_color "$YELLOW" "\nWarnings/Errors:"
            grep "Err:" "$temp_stdout" | while read -r line; do
                echo "- $line"
            done
            return 1
        else
            print_color "$GREEN" "Package lists updated successfully"
            return 0
        fi
    else
        local exit_code=$?
        print_color "$RED" "Failed to update package lists"
        
        if [ $exit_code -eq 124 ]; then
            print_color "$RED" "Update process timed out after $TIMEOUT seconds"
        fi
        
        if [ -s "$temp_stderr" ]; then
            print_color "$YELLOW" "\nError messages:"
            cat "$temp_stderr" | while read -r line; do
                echo "- $line"
            done
        fi
        
        return 1
    fi
}

install_docker() {
    local TIMEOUT=300  # 5 minutes timeout
    local RETRY_COUNT=3
    local RETRY_DELAY=5
    local ERROR_COUNT=0
    
    # Prerequisites packages
    local PREREQ_PACKAGES=(
        "apt-transport-https"
        "ca-certificates"
        "curl"
        "software-properties-common"
        "gnupg"
        "lsb-release"
    )
    
    # Docker packages
    local DOCKER_PACKAGES=(
        "docker-ce"
        "docker-ce-cli"
        "containerd.io"
    )
    
    # Function to retry commands
    retry_command() {
        local cmd="$1"
        local retry=0
        
        while [ $retry -lt $RETRY_COUNT ]; do
            if eval "$cmd"; then
                return 0
            fi
            ((retry++))
            print_color "$YELLOW" "Command failed, retrying in $RETRY_DELAY seconds... ($retry/$RETRY_COUNT)"
            sleep $RETRY_DELAY
        done
        return 1
    }
    
    # Check system requirements
    print_color "$BLUE" "Checking system requirements..."
    
    # Check if running as root or with sudo
    if [ "$(id -u)" -ne 0 ]; then
        if ! command -v sudo >/dev/null 2>&1; then
            print_color "$RED" "This script requires root privileges or sudo access"
            return 1
        fi
    fi
    
    # Check system architecture
    if [ "$(uname -m)" != "x86_64" ]; then
        print_color "$YELLOW" "Warning: System architecture is not x86_64, some features might not work"
    fi
    
    # Check internet connection
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        print_color "$RED" "No internet connection available"
        return 1
    fi
    
    # Install prerequisites
    print_color "$YELLOW" "Installing prerequisites..."
    if ! retry_command "sudo apt-get install -y ${PREREQ_PACKAGES[*]}"; then
        print_color "$RED" "Failed to install prerequisites"
        return 1
    fi
    
    # Add Docker's GPG key
    print_color "$YELLOW" "Adding Docker's GPG key..."
    if ! retry_command "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"; then
        print_color "$RED" "Failed to add Docker's GPG key"
        return 1
    fi
    
    # Add Docker repository
    print_color "$YELLOW" "Adding Docker repository..."
    local UBUNTU_CODENAME=$(lsb_release -cs)
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package list
    print_color "$YELLOW" "Updating package list..."
    if ! retry_command "sudo apt-get update"; then
        print_color "$RED" "Failed to update package list"
        return 1
    fi
    
    # Install Docker
    print_color "$YELLOW" "Installing Docker..."
    if ! retry_command "sudo apt-get install -y ${DOCKER_PACKAGES[*]}"; then
        print_color "$RED" "Failed to install Docker"
        return 1
    fi
    
    # Configure Docker service
    print_color "$YELLOW" "Configuring Docker service..."
    if ! systemctl is-active docker >/dev/null 2>&1; then
        if ! retry_command "sudo systemctl start docker"; then
            print_color "$RED" "Failed to start Docker service"
            ((ERROR_COUNT++))
        fi
    fi
    
    if ! systemctl is-enabled docker >/dev/null 2>&1; then
        if ! retry_command "sudo systemctl enable docker"; then
            print_color "$RED" "Failed to enable Docker service"
            ((ERROR_COUNT++))
        fi
    fi
    
    # Install Docker Compose
    print_color "$YELLOW" "Installing Docker Compose..."
    local COMPOSE_VERSION
    if ! COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4); then
        print_color "$RED" "Failed to get Docker Compose version"
        ((ERROR_COUNT++))
    else
        local COMPOSE_URL="https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)"
        if ! retry_command "sudo curl -L \"${COMPOSE_URL}\" -o /usr/local/bin/docker-compose"; then
            print_color "$RED" "Failed to download Docker Compose"
            ((ERROR_COUNT++))
        else
            sudo chmod +x /usr/local/bin/docker-compose
        fi
    fi
    
    # Add user to docker group
    print_color "$YELLOW" "Adding user to docker group..."
    if ! retry_command "sudo usermod -aG docker $USER"; then
        print_color "$RED" "Failed to add user to docker group"
        ((ERROR_COUNT++))
    fi
    
    # Verify installation
    print_color "$YELLOW" "Verifying installation..."
    local VERIFY_COMMANDS=(
        "docker --version"
        "docker-compose --version"
        "docker info"
    )
    
    for cmd in "${VERIFY_COMMANDS[@]}"; do
        if ! eval "$cmd" >/dev/null 2>&1; then
            print_color "$RED" "Verification failed for: $cmd"
            ((ERROR_COUNT++))
        fi
    done
    
    # Print summary
    print_color "$BLUE" "\nInstallation Summary:"
    if [ $ERROR_COUNT -eq 0 ]; then
        print_color "$GREEN" "Docker installation completed successfully"
        print_color "$YELLOW" "Please log out and log back in for group changes to take effect"
        return 0
    else
        print_color "$RED" "Installation completed with $ERROR_COUNT errors"
        return 1
    fi
}

configure_docker_daemon() {
    local DAEMON_JSON="/etc/docker/daemon.json"
    local ERROR_COUNT=0
    
    print_color "$YELLOW" "Checking Docker daemon configuration..."
    
    # Backup existing configuration if it exists
    if [ -f "$DAEMON_JSON" ]; then
        local backup_file="${DAEMON_JSON}.backup-$(date +%Y%m%d_%H%M%S)"
        print_color "$YELLOW" "Backing up existing daemon.json..."
        if ! sudo cp -f "$DAEMON_JSON" "$backup_file"; then
            print_color "$RED" "Failed to backup existing daemon.json"
            return 1
        fi
        print_color "$GREEN" "Backup created: $backup_file"
    fi
    
    # Create new configuration
    print_color "$YELLOW" "Creating new daemon configuration..."
    local config_content=$(cat <<'EOF'
{
    "storage-driver": "overlay2",
    "iptables": false
}
EOF
)
    
    if ! echo "$config_content" | sudo tee "$DAEMON_JSON" > /dev/null; then
        print_color "$RED" "Failed to write daemon configuration"
        return 1
    fi
    
    # Verify JSON syntax
    if command -v jq >/dev/null 2>&1; then
        if ! sudo cat "$DAEMON_JSON" | jq empty; then
            print_color "$RED" "Invalid JSON syntax in daemon.json"
            if [ -f "$backup_file" ]; then
                print_color "$YELLOW" "Restoring backup..."
                sudo cp -f "$backup_file" "$DAEMON_JSON"
            fi
            return 1
        fi
    fi
    
    # Set proper permissions
    if ! sudo chmod 644 "$DAEMON_JSON"; then
        print_color "$RED" "Failed to set daemon.json permissions"
        return 1
    fi
    
    print_color "$GREEN" "Docker daemon configuration updated successfully"
    return 0
}


verify_docker_installation() {
    local TIMEOUT=60  # Timeout for docker operations
    local RETRY_COUNT=3
    local RETRY_DELAY=5
    local TEST_IMAGE="hello-world"
    local CONTAINER_NAME="docker-test-$(date +%s)"
    local ERROR_COUNT=0
    
    print_color "$BLUE" "Starting Docker installation verification..."
    
    # Check if Docker daemon is running
    if ! systemctl is-active --quiet docker; then
        print_color "$YELLOW" "Docker daemon is not running. Attempting to start..."
        if ! sudo systemctl start docker; then
            print_color "$RED" "Failed to start Docker daemon"
            return 1
        fi
        sleep 5  # Wait for daemon to initialize
    fi
    
    # Function to cleanup test containers and images
    cleanup_test_resources() {
        local force=$1
        
        # Remove test container if it exists
        if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
            sudo docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1
        fi
        
        # Remove test image if force cleanup requested
        if [ "$force" = "true" ] && docker images "${TEST_IMAGE}" --format '{{.Repository}}' | grep -q "^${TEST_IMAGE}$"; then
            sudo docker rmi -f "${TEST_IMAGE}" >/dev/null 2>&1
        fi
    }
    
    # Ensure cleanup on script exit
    trap 'cleanup_test_resources true' EXIT
    
    # Check Docker client version
    print_color "$YELLOW" "Checking Docker version..."
    if ! docker_version=$(sudo docker version --format '{{.Server.Version}}' 2>/dev/null); then
        print_color "$RED" "Failed to get Docker version"
        ((ERROR_COUNT++))
    else
        print_color "$GREEN" "Docker version: $docker_version"
    fi
    
    # Check Docker info
    print_color "$YELLOW" "Checking Docker system information..."
    if ! sudo docker info >/dev/null 2>&1; then
        print_color "$RED" "Failed to get Docker system information"
        ((ERROR_COUNT++))
    fi
    
    # Check network connectivity
    print_color "$YELLOW" "Checking Docker network connectivity..."
    if ! sudo docker network ls >/dev/null 2>&1; then
        print_color "$RED" "Failed to list Docker networks"
        ((ERROR_COUNT++))
    fi
    
    # Pull and run test container
    print_color "$YELLOW" "Running test container..."
    local retry=0
    local success=false
    
    while [ $retry -lt $RETRY_COUNT ] && [ "$success" = "false" ]; do
        # Clean up any previous attempts
        cleanup_test_resources false
        
        # Pull the test image with timeout
        if ! timeout $TIMEOUT sudo docker pull "${TEST_IMAGE}"; then
            print_color "$YELLOW" "Failed to pull test image (attempt $((retry+1))/$RETRY_COUNT)"
            ((retry++))
            sleep $RETRY_DELAY
            continue
        fi
        
        # Run the test container
        if ! timeout $TIMEOUT sudo docker run --name "${CONTAINER_NAME}" "${TEST_IMAGE}"; then
            print_color "$YELLOW" "Failed to run test container (attempt $((retry+1))/$RETRY_COUNT)"
            ((retry++))
            sleep $RETRY_DELAY
            continue
        fi
        
        success=true
    done
    
    if [ "$success" = "false" ]; then
        print_color "$RED" "Failed to verify Docker installation after $RETRY_COUNT attempts"
        ((ERROR_COUNT++))
    fi
    
    # Check container logs
    if [ "$success" = "true" ]; then
        print_color "$YELLOW" "Checking container logs..."
        if ! sudo docker logs "${CONTAINER_NAME}" | grep -q "Hello from Docker!"; then
            print_color "$RED" "Test container output verification failed"
            ((ERROR_COUNT++))
        fi
    fi
    
    # Additional checks
    print_color "$YELLOW" "Performing additional checks..."
    
    # Check Docker socket permissions
    if [ ! -S /var/run/docker.sock ]; then
        print_color "$RED" "Docker socket file not found"
        ((ERROR_COUNT++))
    elif [ ! -r /var/run/docker.sock ] || [ ! -w /var/run/docker.sock ]; then
        print_color "$RED" "Incorrect Docker socket permissions"
        ((ERROR_COUNT++))
    fi
    
    # Check if current user is in docker group
    if ! groups "$USER" | grep -q '\bdocker\b'; then
        print_color "$YELLOW" "Warning: Current user is not in the docker group"
        ((ERROR_COUNT++))
    fi
    
    # Print verification summary
    print_color "$BLUE" "\nVerification Summary:"
    if [ $ERROR_COUNT -eq 0 ]; then
        print_color "$GREEN" "Docker installation verified successfully!"
        print_color "$GREEN" "All checks passed"
        return 0
    else
        print_color "$RED" "Docker verification completed with $ERROR_COUNT errors"
        print_color "$YELLOW" "Please check the above messages for details"
        return 1
    fi
}

configure_docker_environment() {
    local NETWORK_NAME="my_network"
    local NETWORK_DRIVER="bridge"
    local DOCKER_PORTS=("2375" "2376")
    local ERROR_COUNT=0
    local RETRY_COUNT=3
    local RETRY_DELAY=5
    
    # Function to retry commands
    retry_command() {
        local cmd="$1"
        local description="$2"
        local retry=0
        
        while [ $retry -lt $RETRY_COUNT ]; do
            if eval "$cmd"; then
                return 0
            fi
            ((retry++))
            print_color "$YELLOW" "$description failed, retrying in $RETRY_DELAY seconds... ($retry/$RETRY_COUNT)"
            sleep $RETRY_DELAY
        done
        return 1
    }
    
    # Check if Docker daemon is running
    if ! systemctl is-active --quiet docker; then
        print_color "$RED" "Docker daemon is not running"
        return 1
    fi
    
    # Create network if it doesn't exist
    print_color "$YELLOW" "Checking Docker network..."
    if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
        print_color "$YELLOW" "Creating $NETWORK_NAME network..."
        if ! retry_command "docker network create --driver $NETWORK_DRIVER $NETWORK_NAME" "Network creation"; then
            print_color "$RED" "Failed to create Docker network"
            ((ERROR_COUNT++))
        else
            print_color "$GREEN" "Network $NETWORK_NAME created successfully"
        fi
    else
        print_color "$GREEN" "Network $NETWORK_NAME already exists"
    fi
    
    # Configure firewall
    print_color "$YELLOW" "Configuring firewall..."
    
    # Check if UFW is installed and active
    if ! command -v ufw >/dev/null 2>&1; then
        print_color "$YELLOW" "UFW is not installed. Installing..."
        if ! retry_command "sudo apt-get install -y ufw" "UFW installation"; then
            print_color "$RED" "Failed to install UFW"
            ((ERROR_COUNT++))
        fi
    fi
    
    # Enable UFW if not active
    # if ! sudo ufw status | grep -q "Status: active"; then
    #     print_color "$YELLOW" "Enabling UFW..."
    #     if ! retry_command "sudo ufw --force enable" "UFW activation"; then
    #         print_color "$RED" "Failed to enable UFW"
    #         ((ERROR_COUNT++))
    #     fi
    # fi
    
    # Configure UFW rules
    # for port in "${DOCKER_PORTS[@]}"; do
    #     if ! sudo ufw status | grep -q "$port/tcp"; then
    #         print_color "$YELLOW" "Adding UFW rule for port $port..."
    #         if ! retry_command "sudo ufw allow $port/tcp" "UFW rule addition"; then
    #             print_color "$RED" "Failed to add UFW rule for port $port"
    #             ((ERROR_COUNT++))
    #         fi
    #     else
    #         print_color "$GREEN" "UFW rule for port $port already exists"
    #     fi
    # done
    
    # Docker Hub login
    print_color "$YELLOW" "Do you want to log in to Docker Hub? (y/n)"
    read -r docker_hub_login
    
    if [[ $docker_hub_login =~ ^[Yy]$ ]]; then
        if ! retry_command "docker login" "Docker Hub login"; then
            print_color "$RED" "Failed to log in to Docker Hub"
            ((ERROR_COUNT++))
        fi
    fi
    
    # Check and configure user permissions
    local current_user="$USER"
    
    # Check Docker group membership
    if ! groups "$current_user" | grep -q '\bdocker\b'; then
        print_color "$YELLOW" "Adding user to docker group..."
        if ! retry_command "sudo usermod -aG docker $current_user" "User group modification"; then
            print_color "$RED" "Failed to add user to docker group"
            ((ERROR_COUNT++))
        else
            print_color "$GREEN" "User added to docker group"
            print_color "$YELLOW" "Please log out and log back in for changes to take effect"
            print_color "$YELLOW" "Alternatively, run 'newgrp docker' to apply changes in current session"
        fi
    else
        print_color "$GREEN" "User is already in the docker group"
    fi
    
    # Check and fix Docker socket permissions
    local DOCKER_SOCKET="/var/run/docker.sock"
    if [ -S "$DOCKER_SOCKET" ]; then
        local current_perms=$(stat -c %a "$DOCKER_SOCKET")
        if [ "$current_perms" != "660" ]; then
            print_color "$YELLOW" "Adjusting Docker socket permissions..."
            if ! retry_command "sudo chmod 660 $DOCKER_SOCKET" "Socket permission modification"; then
                print_color "$RED" "Failed to adjust Docker socket permissions"
                ((ERROR_COUNT++))
            else
                print_color "$GREEN" "Docker socket permissions adjusted"
            fi
        fi
    else
        print_color "$RED" "Docker socket file not found"
        ((ERROR_COUNT++))
    fi
    
    # Print versions and status
    print_color "$BLUE" "\nDocker Environment Status:"
    if docker --version; then
        print_color "$GREEN" "√ Docker installed"
    else
        print_color "$RED" "× Docker version check failed"
        ((ERROR_COUNT++))
    fi
    
    if docker-compose --version; then
        print_color "$GREEN" "√ Docker Compose installed"
    else
        print_color "$RED" "× Docker Compose version check failed"
        ((ERROR_COUNT++))
    fi
    
    # Print summary
    print_color "$BLUE" "\nConfiguration Summary:"
    if [ $ERROR_COUNT -eq 0 ]; then
        print_color "$GREEN" "Docker environment configured successfully!"
        return 0
    else
        print_color "$RED" "Configuration completed with $ERROR_COUNT errors"
        return 1
    fi
}

restart_and_verify_docker() {
    local TIMEOUT=60
    local RETRY_COUNT=3
    local RETRY_DELAY=5
    local ERROR_COUNT=0
    local MAX_WAIT_TIME=30
    
    # Function to check Docker daemon status
    check_docker_status() {
        local wait_time=0
        local interval=2
        
        while [ $wait_time -lt $MAX_WAIT_TIME ]; do
            if systemctl is-active --quiet docker; then
                return 0
            fi
            sleep $interval
            wait_time=$((wait_time + interval))
            print_color "$YELLOW" "Waiting for Docker daemon to start... (${wait_time}s/${MAX_WAIT_TIME}s)"
        done
        return 1
    }
    
    # Function to retry commands
    retry_command() {
        local cmd="$1"
        local description="$2"
        local retry=0
        
        while [ $retry -lt $RETRY_COUNT ]; do
            if eval "$cmd"; then
                return 0
            fi
            ((retry++))
            print_color "$YELLOW" "$description failed, retrying in $RETRY_DELAY seconds... ($retry/$RETRY_COUNT)"
            sleep $RETRY_DELAY
        done
        return 1
    }
    
    # Save current Docker processes
    print_color "$YELLOW" "Checking running containers before restart..."
    local running_containers=$(docker ps -q 2>/dev/null)
    
    # Stop running containers gracefully if any
    if [ -n "$running_containers" ]; then
        print_color "$YELLOW" "Stopping running containers..."
        if ! retry_command "docker stop $running_containers" "Container stop"; then
            print_color "$RED" "Failed to stop running containers"
            ((ERROR_COUNT++))
        fi
    fi
    
    # Restart Docker service
    print_color "$YELLOW" "Restarting Docker service..."
    
    # Stop service
    print_color "$YELLOW" "Stopping Docker service..."
    if ! retry_command "sudo systemctl stop docker" "Docker service stop"; then
        print_color "$RED" "Failed to stop Docker service"
        ((ERROR_COUNT++))
    fi
    
    # Wait for service to fully stop
    sleep 2
    
    # Start service
    print_color "$YELLOW" "Starting Docker service..."
    if ! retry_command "sudo systemctl start docker" "Docker service start"; then
        print_color "$RED" "Failed to start Docker service"
        ((ERROR_COUNT++))
    fi
    
    # Check if service is running
    if ! check_docker_status; then
        print_color "$RED" "Docker service failed to start within ${MAX_WAIT_TIME} seconds"
        ((ERROR_COUNT++))
    else
        print_color "$GREEN" "Docker service started successfully"
    fi
    
    # Verify Docker daemon socket
    if [ ! -S /var/run/docker.sock ]; then
        print_color "$RED" "Docker socket file not found"
        ((ERROR_COUNT++))
    fi
    
    # Check Docker permissions
    print_color "$YELLOW" "Checking Docker permissions..."
    
    # Test Docker access without sudo
    if ! timeout $TIMEOUT docker info >/dev/null 2>&1; then
        print_color "$YELLOW" "Testing Docker access with sudo..."
        if ! timeout $TIMEOUT sudo docker info >/dev/null 2>&1; then
            print_color "$RED" "Cannot access Docker even with sudo"
            ((ERROR_COUNT++))
        else
            print_color "$YELLOW" "Docker only accessible with sudo"
            
            # Check group membership
            if ! groups "$USER" | grep -q '\bdocker\b'; then
                print_color "$YELLOW" "User not in docker group. Adding..."
                if ! sudo usermod -aG docker "$USER"; then
                    print_color "$RED" "Failed to add user to docker group"
                    ((ERROR_COUNT++))
                else
                    print_color "$GREEN" "User added to docker group"
                    print_color "$YELLOW" "Please log out and log back in for changes to take effect"
                fi
            fi
        fi
    else
        print_color "$GREEN" "Docker accessible without sudo"
    fi
    
    # Verify basic Docker functionality
    print_color "$YELLOW" "Verifying Docker functionality..."
    local test_commands=(
        "docker ps"
        "docker images"
        "docker network ls"
        "docker volume ls"
    )
    
    for cmd in "${test_commands[@]}"; do
        if ! retry_command "$cmd" "Docker command test"; then
            print_color "$RED" "Failed to execute: $cmd"
            ((ERROR_COUNT++))
        fi
    done
    
    # Restart previously running containers if any
    if [ -n "$running_containers" ]; then
        print_color "$YELLOW" "Restarting previously running containers..."
        if ! retry_command "docker start $running_containers" "Container restart"; then
            print_color "$RED" "Failed to restart some containers"
            ((ERROR_COUNT++))
        fi
    fi
    
    # Print summary
    print_color "$BLUE" "\nDocker Restart Summary:"
    if [ $ERROR_COUNT -eq 0 ]; then
        print_color "$GREEN" "Docker service restart completed successfully"
        print_color "$GREEN" "All checks passed"
        
        # Print current Docker status
        echo -e "\nCurrent Docker Status:"
        docker info 2>/dev/null | grep -E "^(Server Version|Containers|Images|Storage Driver)"
        
        return 0
    else
        print_color "$RED" "Docker service restart completed with $ERROR_COUNT errors"
        print_color "$YELLOW" "Please check the above messages and consider the following:"
        echo "1. Ensure Docker daemon is running: 'sudo systemctl status docker'"
        echo "2. Check Docker logs: 'sudo journalctl -u docker'"
        echo "3. Verify permissions: 'ls -l /var/run/docker.sock'"
        echo "4. Log out and log back in if group changes were made"
        return 1
    fi
}

# Main installation orchestrator
install_docker_system() {
    local STEP=1
    local TOTAL_STEPS=10
    local start_time=$(date +%s)
    local error_log="/tmp/docker_install_errors.log"
    
    # Function to print step information
    print_step() {
        local description="$1"
        print_color "$BLUE" "\nStep $STEP/$TOTAL_STEPS: $description"
        print_color "$BLUE" "----------------------------------------"
        ((STEP++))
    }
    
    # Function to log errors
    log_error() {
        local step="$1"
        local message="$2"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Step $step failed: $message" >> "$error_log"
    }
    
    # Initialize error log
    > "$error_log"
    
    print_color "$GREEN" "Starting Docker installation and configuration process..."
    echo "Installation started at: $(date '+%Y-%m-%d %H:%M:%S')"
    # Handle Ctrl+C and other interrupts
    trap 'interrupted=true; echo -e "\nInterrupted by user. Cleaning up..."; exit 1' INT TERM

    # Step 1: Check privileges
    print_step "Checking system privileges"
    if ! check_privileges; then
        log_error "Privileges Check" "Insufficient privileges"
        print_color "$RED" "Error: Privilege check failed. Root or sudo access required."
        return 1
    fi
    
    # Step 2: Check system information
    print_step "Checking system information"
    if ! check_system_info; then
        log_error "System Info" "Failed to get system information"
        print_color "$RED" "Error: System information check failed."
        return 1
    fi
    
    # Step 3: Verify Ubuntu version
    print_step "Verifying Ubuntu version"
    if ! check_ubuntu_version; then
        log_error "Ubuntu Version" "Unsupported Ubuntu version"
        print_color "$RED" "Error: Ubuntu version check failed."
        return 1
    fi
    
    # Step 4: Check system compatibility
    print_step "Checking system compatibility"
    if ! check_system_compatibility; then
        log_error "System Compatibility" "System not compatible"
        print_color "$RED" "Error: System compatibility check failed."
        return 1
    fi
    
    # Step 5: Disable CD-ROM sources
    print_step "Disabling CD-ROM sources"
    if ! disable_cdrom_sources; then
        log_error "CD-ROM Sources" "Failed to disable CD-ROM sources"
        print_color "$YELLOW" "Warning: Failed to disable CD-ROM sources. Continuing..."
    fi
    
    # Step 6: Clean existing Docker installations
    print_step "Cleaning existing Docker installations"
    if ! cleanup_docker_system; then
        log_error "Docker Cleanup" "Failed to clean existing Docker installation"
        print_color "$YELLOW" "Warning: Docker cleanup encountered issues. Continuing..."
    fi
    
    # Step 7: Update package list
    print_step "Updating package list"
    if ! update_package_list; then
        log_error "Package Update" "Failed to update package list"
        print_color "$RED" "Error: Package list update failed."
        return 1
    fi
    
    # Step 8: Install Docker
    print_step "Installing Docker"
    if ! install_docker; then
        log_error "Docker Installation" "Failed to install Docker"
        print_color "$RED" "Error: Docker installation failed."
        return 1
    fi
    
    # Step 9: Configure Docker daemon
    print_step "Configuring Docker daemon"
    if ! configure_docker_daemon; then
        log_error "Docker Daemon Configuration" "Failed to configure Docker daemon"
        print_color "$RED" "Error: Docker daemon configuration failed."
        return 1
    fi

    # Step 10: Verify Docker installation
    print_step "Verifying Docker installation"
    if ! verify_docker_installation; then
        log_error "Docker Verification" "Failed to verify Docker installation"
        print_color "$RED" "Error: Docker installation verification failed."
        return 1
    fi
    
    # Step 11: Configure Docker environment
    print_step "Configuring Docker environment"
    if ! configure_docker_environment; then
        log_error "Docker Configuration" "Failed to configure Docker environment"
        print_color "$RED" "Error: Docker environment configuration failed."
        return 1
    fi
    
    # Step 12: Restart and verify Docker
    print_step "Restarting and verifying Docker"
    if ! restart_and_verify_docker; then
        log_error "Docker Restart" "Failed to restart and verify Docker"
        print_color "$RED" "Error: Docker restart and verification failed."
        return 1
    fi
    
    # Calculate execution time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Print installation summary
    print_color "$BLUE" "\nInstallation Summary:"
    print_color "$GREEN" "✓ Installation completed successfully"
    echo "Installation duration: $(($duration / 60)) minutes and $(($duration % 60)) seconds"
    
    if [ -s "$error_log" ]; then
        print_color "$YELLOW" "\nWarnings encountered during installation:"
        cat "$error_log"
    fi
    
    print_color "$GREEN" "\nDocker installation and configuration completed!"
    print_color "$YELLOW" "Please log out and log back in for group changes to take effect."
    
    return 0
}

# Main execution
main() {
    # Ensure script is run with bash
    if [ -z "$BASH_VERSION" ]; then
        echo "This script must be run with bash"
        exit 1
    fi
    
    # Check if script is run as root or with sudo
    if [ "$EUID" -ne 0 ] && ! command -v sudo >/dev/null 2>&1; then
        echo "This script must be run as root or with sudo access"
        exit 1
    fi
    
    # Run installation
    if install_docker_system; then
        exit 0
    else
        print_color "$RED" "Docker installation failed. Check error log for details."
        exit 1
    fi
}

# Run main function
main
