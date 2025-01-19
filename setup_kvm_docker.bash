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

# Function to check virtualization support
check_virtualization() {
    print_color "$YELLOW" "Checking virtualization support..."
    
    # Install cpu-checker if not present
    if ! command -v kvm-ok >/dev/null 2>&1; then
        print_color "$YELLOW" "Installing cpu-checker package..."
        if ! sudo apt-get install -y cpu-checker; then
            print_color "$RED" "Failed to install cpu-checker"
            return 1
        fi
    fi
    
    # Check KVM support
    if ! sudo kvm-ok; then
        print_color "$RED" "KVM virtualization not supported"
        return 1
    fi
    
    # Check CPU virtualization flags
    if [ $(egrep -c '(vmx|svm)' /proc/cpuinfo) -eq 0 ]; then
        print_color "$RED" "CPU virtualization not enabled in BIOS"
        return 1
    fi
    
    print_color "$GREEN" "Virtualization support verified"
    return 0
}

# Function to install KVM and required packages
install_kvm() {
    local TIMEOUT=60
    local RETRY_COUNT=3
    local RETRY_DELAY=5
    local ERROR_COUNT=0
    
    # Check if running with necessary privileges
    if [ "$(id -u)" -ne 0 ]; then
        if ! command -v sudo >/dev/null 2>&1; then
            print_color "$RED" "This function requires root privileges and sudo is not available"
            return 1
        fi
    fi
    
    # Function to handle lock files
    handle_locks() {
        print_color "$YELLOW" "Checking and clearing package locks..."
        
        # List of lock files to check
        local LOCK_FILES=(
            "/var/lib/apt/lists/lock"
            "/var/cache/apt/archives/lock"
            "/var/lib/dpkg/lock"
            "/var/lib/dpkg/lock-frontend"
        )
        
        # Check and remove each lock file
        for lock_file in "${LOCK_FILES[@]}"; do
            if [ -f "$lock_file" ]; then
                sudo rm -f "$lock_file"
            fi
        done
        
        # Clean package cache
        sudo rm -f /var/cache/apt/pkgcache.bin
        sudo rm -f /var/cache/apt/srcpkgcache.bin
        
        # Reconfigure dpkg if needed
        sudo dpkg --configure -a
        
        return 0
    }
    
    # Handle locks before starting installation
    handle_locks
    
    print_color "$YELLOW" "Installing KVM and required packages..."
    
    # Update package list with proper error handling
    if ! sudo apt-get update; then
        print_color "$RED" "Failed to update package lists"
        return 1
    fi
    
    # Install KVM packages
    local KVM_PACKAGES=(
        "qemu-kvm"
        "libvirt-daemon-system"
        "libvirt-clients"
        "bridge-utils"
        "virtinst"
        "virt-manager"
    )
    
    for package in "${KVM_PACKAGES[@]}"; do
        if ! sudo apt-get install -y "$package"; then
            print_color "$RED" "Failed to install $package"
            ((ERROR_COUNT++))
        fi
    done
    
    # Enable and start libvirtd service
    if ! sudo systemctl enable --now libvirtd; then
        print_color "$RED" "Failed to enable libvirtd service"
        return 1
    fi
    
    if [ $ERROR_COUNT -eq 0 ]; then
        print_color "$GREEN" "KVM installation completed successfully"
        return 0
    else
        print_color "$RED" "KVM installation completed with $ERROR_COUNT errors"
        return 1
    fi
}

# Function to configure user permissions
configure_permissions() {
    print_color "$YELLOW" "Configuring user permissions..."
    local current_user="$SUDO_USER"
    if [ -z "$current_user" ]; then
        current_user="$USER"
    fi
    
    # Add user to required groups
    local REQUIRED_GROUPS=("kvm" "libvirt")
    for group in "${REQUIRED_GROUPS[@]}"; do
        if ! getent group "$group" > /dev/null; then
            print_color "$YELLOW" "Creating group $group..."
            if ! sudo groupadd "$group"; then
                print_color "$RED" "Failed to create group $group"
                return 1
            fi
        fi
        
        if ! groups "$current_user" | grep -q "\b$group\b"; then
            print_color "$YELLOW" "Adding user to $group group..."
            if ! sudo usermod -aG "$group" "$current_user"; then
                print_color "$RED" "Failed to add user to $group group"
                return 1
            fi
        fi
    done
    
    # Set KVM device permissions if it exists
    if [ -e "/dev/kvm" ]; then
        print_color "$YELLOW" "Setting KVM device permissions..."
        if ! sudo chown root:kvm /dev/kvm 2>/dev/null || ! sudo chmod 660 /dev/kvm 2>/dev/null; then
            print_color "$YELLOW" "Warning: Could not set KVM device permissions"
            # Don't return error here as this might not be critical
        fi
    else
        print_color "$YELLOW" "Warning: /dev/kvm device not found"
    fi
    
    print_color "$GREEN" "User permissions configured"
    print_color "$YELLOW" "Note: You may need to log out and log back in for group changes to take effect"
    return 0
}

# Function to verify KVM installation
verify_installation() {
    print_color "$YELLOW" "Verifying KVM installation..."
    
    # Check KVM module
    if ! lsmod | grep -i kvm > /dev/null; then
        print_color "$RED" "KVM modules not loaded"
        return 1
    fi
    
    # Check libvirtd service
    if ! systemctl is-active --quiet libvirtd; then
        print_color "$RED" "libvirtd service not running"
        return 1
    fi
    
    # Verify KVM device exists
    if [ ! -e "/dev/kvm" ]; then
        print_color "$RED" "/dev/kvm device not found"
        return 1
    fi
    
    print_color "$GREEN" "KVM installation verified successfully"
    return 0
}

# Function to configure Docker for KVM
configure_docker() {
    print_color "$YELLOW" "Configuring Docker for KVM support..."
    
    # Create or modify Docker daemon configuration
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json <<EOF
{
    "default-runtime": "runc",
    "runtimes": {
        "runc": {
            "path": "runc"
        }
    },
    "storage-driver": "overlay2",
    "iptables": false
}
EOF
    
    # Restart Docker service
    systemctl restart docker
    
    # Add iptables rules for bridge networking
    iptables -I FORWARD -i br0 -o br0 -j ACCEPT
    iptables -I FORWARD -i docker0 -o docker0 -j ACCEPT
}


install_kvm_system() {
    local STEP=1
    local TOTAL_STEPS=7
    local start_time=$(date +%s)
    local error_log="/tmp/kvm_install_errors.log"
    
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
    
    print_color "$GREEN" "Starting KVM installation and configuration process..."
    echo "Installation started at: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # Handle interrupts
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
    
    # Step 4: Check virtualization support
    print_step "Checking virtualization support"
    if ! check_virtualization; then
        log_error "Virtualization Check" "Virtualization not supported"
        print_color "$RED" "Error: Virtualization check failed."
        return 1
    fi
    
    # Step 5: Install KVM packages
    print_step "Installing KVM and required packages"
    if ! install_kvm; then
        log_error "Installation KVM" "Installation was not successful"
        print_color "$RED" "Error: Installation check failed."
        return 1
    fi
    
    # Enable and start libvirtd service
    # if ! systemctl enable --now libvirtd; then
    #     log_error "Service Configuration" "Failed to enable libvirtd service"
    #     print_color "$RED" "Error: Failed to enable libvirtd service"
    #     return 1
    # fi
    
    # Step 6: Configure permissions
    print_step "Configuring user permissions"
    if ! configure_permissions; then
        log_error "Installation KVM" "Installation was not successful"
        print_color "$RED" "Error: Installation check failed."
        return 1
    fi
    # local current_user="$SUDO_USER"
    # if [ -z "$current_user" ]; then
    #     current_user="$USER"
    # fi
    
    # local REQUIRED_GROUPS=("kvm" "libvirt")
    # for group in "${REQUIRED_GROUPS[@]}"; do
    #     if ! usermod -aG "$group" "$current_user"; then
    #         log_error "Permission Configuration" "Failed to add user to $group group"
    #         print_color "$RED" "Error: Failed to add user to $group group"
    #         return 1
    #     fi
    # done
    
    # # Set KVM device permissions
    # if [ -e "/dev/kvm" ]; then
    #     if ! chown root:kvm /dev/kvm || ! chmod 660 /dev/kvm; then
    #         log_error "Device Permissions" "Failed to set KVM device permissions"
    #         print_color "$RED" "Error: Failed to set KVM device permissions"
    #         return 1
    #     fi
    # fi
    
    # Step 7: Verify installation
    print_step "Verifying KVM installation"
    if ! verify_installation; then
        log_error "Installation Verification" "Failed to verify KVM installation"
        print_color "$RED" "Error: KVM installation verification failed"
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
    
    print_color "$GREEN" "\nKVM installation and configuration completed!"
    echo ""

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
    if install_kvm_system; then
        exit 0
    else
        print_color "$RED" "Docker installation failed. Check error log for details."
        exit 1
    fi
}

# Run main function
main
