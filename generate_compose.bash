#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Default values
DEFAULT_FILENAME="docker-compose.yml"
DEFAULT_CONTAINER_NAME="windows10LTSC"
DEFAULT_WEB_PORT=8006
DEFAULT_RDP_PORT=3390
DEFAULT_MT_API_PORT=8228
DEFAULT_REGION="en-US"
DEFAULT_KEYBOARD="en-US"
DEFAULT_USERNAME="root"
DEFAULT_PASSWORD="root"
DEFAULT_META_TRADER_5_ACCOUNT_NUMBER="META_TRADER_5_ACCOUNT_NUMBER"
DEFAULT_META_TRADER_5_PASSWORD="META_TRADER_5_PASSWORD"
DEFAULT_BROKER_SERVER="BROKER_SERVER"

# Function to print colored output
print_color() {
    echo -e "${1}${2}${NC}"
}

# Main function
generate_compose() {
    print_color "$GREEN" "Creating Docker Compose configuration..."
    print_color "$YELLOW" "Please provide the following information:"
    
    # Get filename
    read -p "Output filename [$DEFAULT_FILENAME]: " filename
    filename=${filename:-$DEFAULT_FILENAME}
    case "$filename" in *\.yml) ;; *) filename="$filename.yml" ;; esac
    print_color "$GREEN" "Using filename: $YELLOW$filename"
    
    # Get system configuration
    read -p "Container Name [$DEFAULT_CONTAINER_NAME]: " container_name
    read -p "Region [$DEFAULT_REGION]: " region
    read -p "Keyboard layout [$DEFAULT_KEYBOARD]: " keyboard
    read -p "Username [$DEFAULT_USERNAME]: " username
    read -p "Password [$DEFAULT_PASSWORD]: " password
    
    # Get MetaTrader info
    read -p "MetaTrader Account Number [$DEFAULT_META_TRADER_5_ACCOUNT_NUMBER]: " mt_user
    read -p "MetaTrader Password [$DEFAULT_META_TRADER_5_PASSWORD]: " mt_pass
    read -p "MetaTrader Server Name [$DEFAULT_BROKER_SERVER]: " mt_server
    
    # Get ports
    read -p "Web Viewer Port [$DEFAULT_WEB_PORT]: " web_port
    read -p "RDP Port [$DEFAULT_RDP_PORT]: " rdp_port
    read -p "MT API Port [$DEFAULT_MT_API_PORT]: " mt_api_port
    
    # Set default values if empty
    container_name=${container_name:-$DEFAULT_CONTAINER_NAME}
    region=${region:-$DEFAULT_REGION}
    keyboard=${keyboard:-$DEFAULT_KEYBOARD}
    username=${username:-$DEFAULT_USERNAME}
    password=${password:-$DEFAULT_PASSWORD}
    mt_user=${mt_user:-$DEFAULT_META_TRADER_5_ACCOUNT_NUMBER}
    mt_pass=${mt_pass:-$DEFAULT_META_TRADER_5_PASSWORD}
    mt_server=${mt_server:-$DEFAULT_BROKER_SERVER}
    web_port=${web_port:-$DEFAULT_WEB_PORT}
    rdp_port=${rdp_port:-$DEFAULT_RDP_PORT}
    mt_api_port=${mt_api_port:-$DEFAULT_MT_API_PORT}

    # Generate docker-compose.yml
    cat > "$filename" << EOL
services:
  windows:
    image: dockurr/windows
    container_name: "${container_name}"
    environment:
      VERSION: "10l"
      AUTO_LOGIN: "true"
      REGION: "${region}"
      KEYBOARD: "${keyboard}"
      USERNAME: "${username}"
      PASSWORD: "${password}"
      METATRADER_USER: "${mt_user}"
      METATRADER_PASSWORD: "${mt_pass}"
      METATRADER_SERVER_NAME: "${mt_server}"
      MT_API_PORT: ${mt_api_port}
    devices:
      - /dev/kvm
      - /dev/net/tun
    cap_add:
      - NET_ADMIN
    ports:
      - ${web_port}:8006  # Web viewer
      - ${rdp_port}:3389  # RDP port
      - ${mt_api_port}:${mt_api_port}  # MT API Port
    volumes:
      - ./scripts:/oem
      - ./metatrader:/data/metatrader
      - ./experts:/data/experts
    restart: unless-stopped
EOL
    
    print_color "$GREEN" "Configuration file $filename has been created successfully!"
}

generate_compose
