# 🚀 Windows MetaTrader Docker Container 🎯

Welcome to an innovative solution for running MetaTrader 5 on Linux servers! This project provides a seamless way to run Windows-based MetaTrader within a Docker container on Ubuntu Linux servers, offering multiple access methods and 24/7 operation capability. 🌟

## 🎯 Key Features

- Run multiple MetaTrader instances on Linux servers 🖥️
- 24/7 continuous operation capability ⏰
- Multiple access methods: Web, VNC, and RDP 🔗
- Perfect platform for API development (MTAPI compatible) 🛠️
- Automated installation process 🤖

## 🔧 System Requirements

- Ubuntu Server 20.04 or higher
- Minimum 4GB RAM
- Minimum 80GB Storage
- Internet connectivity
- KVM virtualization support (essential for VPS users)

## Why this branch is for you?
This branch provides a solution when your remote server's IP is blocked by Microsoft or other ISO download sources (Error 403) due to repeated download attempts. 🛡️

## Prerequisites
- Git
- Python3-pip
- Docker
- At least 5GB free space for ISO file

## Installation Guide

### 1. Clone the Repository
```bash
git clone -b local-iso --single-branch https://github.com/ImanNasrEsfahani/windows_metatrader_docker
```

### 2. Install gdown Package
```bash
sudo apt install python3-pip
pip install gdown
```

### 3. Download Windows ISO 💿
Choose one of these commands based on your Windows version preference:

**Windows 7**
```bash
gdown https://drive.google.com/uc?id=1-JH0XXm0ppZjrNriSO1bqRUnokPo_N1S -O windows.iso
```

**Windows 10 LTSC**
```bash
gdown https://drive.google.com/uc?id=1-9W7zVRDObTeUPGkG1VkIxuhVK2pI4Qx -O windows.iso
```

**Windows 10 PRO**
```bash
gdown https://drive.google.com/uc?id=1-3LbPI53bN8EJzRIw_ksfkid-L75cRYh -O windows.iso
```

### 4. Configure Docker Compose (Optional)
```bash
make config
```

### 5. Launch Container 🚀
**Default configuration**
```bash
docker compose up -d
```

**Custom configuration**
```bash
docker compose -f custom-docker-compose.yml up -d
```

## Connecting to the Container 🖥️

| Connection Method | Address Format | Default Port |
|------------------|----------------|--------------|
| Web Browser | your-server-ip:8006 | 8006 |
| Remote Desktop | your-server-ip:3390 | 3390 |
| VNC Viewer | your-server-ip:3390 | 3390 |

## Important Notes ⚠️
- Ensure sufficient disk space (minimum 5GB) before downloading ISO
- If using custom ports in docker-compose, replace default ports (8006/3390) accordingly
- Custom configuration files must be properly configured before launching

## Support
If you find this project helpful, please consider giving it a star ⭐
