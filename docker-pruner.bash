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

# Function to check Docker status
check_docker_status() {
    print_color "$YELLOW" "Checking Docker status..."
    
    if ! command -v docker &>/dev/null; then
        print_color "$RED" "Docker is not installed"
        return 1
    fi
    
    if ! systemctl is-active --quiet docker; then
        print_color "$RED" "Docker daemon is not running"
        return 1
    fi
    
    print_color "$GREEN" "Docker is running"
    return 0
}

# Function to stop running containers
stop_containers() {
    print_color "$YELLOW" "Stopping running containers..."
    local running_containers=$(docker ps -q)
    
    if [ -n "$running_containers" ]; then
        if ! docker kill $running_containers; then
            print_color "$RED" "Failed to stop some containers"
            return 1
        fi
        print_color "$GREEN" "All containers stopped successfully"
    else
        print_color "$GREEN" "No running containers found"
    fi
    return 0
}

# Function to remove containers
remove_containers() {
    print_color "$YELLOW" "Removing all containers..."
    local all_containers=$(docker ps -a -q)
    
    if [ -n "$all_containers" ]; then
        if ! docker rm $all_containers; then
            print_color "$RED" "Failed to remove some containers"
            return 1
        fi
        print_color "$GREEN" "All containers removed successfully"
    else
        print_color "$GREEN" "No containers to remove"
    fi
    return 0
}

# Function to remove images
remove_images() {
    print_color "$YELLOW" "Removing all images..."
    local all_images=$(docker images -a -q)
    
    if [ -n "$all_images" ]; then
        if ! docker rmi -f $all_images; then
            print_color "$RED" "Failed to remove some images"
            return 1
        fi
        print_color "$GREEN" "All images removed successfully"
    else
        print_color "$GREEN" "No images to remove"
    fi
    return 0
}

# Function to perform system prune
system_prune() {
    print_color "$YELLOW" "Performing system prune..."
    if ! docker system prune -a --volumes -f; then
        print_color "$RED" "System prune failed"
        return 1
    fi
    print_color "$GREEN" "System prune completed successfully"
    return 0
}

# Function to remove dangling and unused images
cleanup_images() {
    print_color "$YELLOW" "Cleaning up images..."
    
    # Remove dangling images
    if ! docker image prune -f; then
        print_color "$RED" "Failed to remove dangling images"
        return 1
    fi
    
    # Remove unused images
    if ! docker image prune -a -f; then
        print_color "$RED" "Failed to remove unused images"
        return 1
    fi
    
    print_color "$GREEN" "Image cleanup completed successfully"
    return 0
}

# Function to clean builder cache
clean_builder_cache() {
    print_color "$YELLOW" "Cleaning builder cache..."
    if ! docker builder prune -f; then
        print_color "$RED" "Failed to clean builder cache"
        return 1
    fi
    print_color "$GREEN" "Builder cache cleaned successfully"
    return 0
}

# Function to remove volumes
remove_volumes() {
    print_color "$YELLOW" "Removing volumes..."
    if ! docker volume prune -f; then
        print_color "$RED" "Failed to remove volumes"
        return 1
    fi
    print_color "$GREEN" "Volumes removed successfully"
    return 0
}

# Main cleanup function
perform_docker_cleanup() {
    local STEP=1
    local TOTAL_STEPS=8
    local ERROR_COUNT=0
    local start_time=$(date +%s)
    
    # Function to print step information
    print_step() {
        local description="$1"
        print_color "$BLUE" "\nStep $STEP/$TOTAL_STEPS: $description"
        print_color "$BLUE" "----------------------------------------"
        ((STEP++))
    }
    
    print_color "$GREEN" "Starting Docker cleanup process..."
    echo "Cleanup started at: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # Handle interrupts
    trap 'echo -e "\nInterrupted by user. Cleaning up..."; exit 1' INT TERM
    
    # Step 1: Check Docker status
    print_step "Checking Docker status"
    if ! check_docker_status; then
        print_color "$RED" "Docker status check failed"
        return 1
    fi
    
    # Step 2: Stop running containers
    print_step "Stopping running containers"
    if ! stop_containers; then
        ((ERROR_COUNT++))
    fi
    
    # Step 3: Remove containers
    print_step "Removing containers"
    if ! remove_containers; then
        ((ERROR_COUNT++))
    fi
    
    # Step 4: Remove images
    print_step "Removing images"
    if ! remove_images; then
        ((ERROR_COUNT++))
    fi
    
    # Step 5: System prune
    print_step "Performing system prune"
    if ! system_prune; then
        ((ERROR_COUNT++))
    fi
    
    # Step 6: Cleanup images
    print_step "Cleaning up images"
    if ! cleanup_images; then
        ((ERROR_COUNT++))
    fi
    
    # Step 7: Clean builder cache
    print_step "Cleaning builder cache"
    if ! clean_builder_cache; then
        ((ERROR_COUNT++))
    fi
    
    # Step 8: Remove volumes
    print_step "Removing volumes"
    if ! remove_volumes; then
        ((ERROR_COUNT++))
    fi
    
    # Calculate execution time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Print cleanup summary
    print_color "$BLUE" "\nCleanup Summary:"
    if [ $ERROR_COUNT -eq 0 ]; then
        print_color "$GREEN" "✓ Cleanup completed successfully"
    else
        print_color "$YELLOW" "Cleanup completed with $ERROR_COUNT warnings"
    fi
    echo "Duration: $(($duration / 60)) minutes and $(($duration % 60)) seconds"
    
    return $ERROR_COUNT
}

# Main execution
main() {
    # Ensure script is run with bash
    if [ -z "$BASH_VERSION" ]; then
        echo "This script must be run with bash"
        exit 1
    fi
    
    # Check if running with necessary privileges
    if [ "$(id -u)" -ne 0 ]; then
        if ! command -v sudo >/dev/null 2>&1; then
            echo "This script must be run as root or with sudo access"
            exit 1
        fi
    fi
    
    # Run cleanup
    if perform_docker_cleanup; then
        print_color "$GREEN" "Docker cleanup completed successfully"
        exit 0
    else
        print_color "$YELLOW" "Docker cleanup completed with warnings"
        exit 1
    fi
}

# Run main function
main
