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

## 🚀 Installation Process

1. Clone the repository:
```bash
git clone https://github.com/ImanNasrEsfahani/windows_metatrader_docker
```

2. Install Docker:
```bash
chmod +x docker-installation.bash
./docker-installation.bash
```

3. Setup KVM virtualization:
```bash
chmod +x setup_kvm_docker.bash
./setup_kvm_docker.bash
```

4. Configure Docker Compose (Optional):
```bash
make config
```

5. Launch the container:
```bash
docker compose up -d
```

## 🔌 Accessing Your Container

**Web Browser Access:**
- URL: `your-server-ip:8006`

**Remote Desktop Connection:**
- Address: `your-server-ip:3390`

**VNC Viewer:**
- Address: `your-server-ip:3390`

**API Access:**
- Port: `2889`

## 📦 Custom Configurations

**Adding Custom Expert Advisors:**
- Place your EAs in the `experts` folder before container launch

**Changing MetaTrader Installation:**
- Replace `mt5setup.exe` in the `metatrader` folder with your broker's MT5 version

## 🧹 Maintenance

To clean up unused Docker resources:
```bash
./docker-pruner.bash
```

## 🎯 Future Goals

We're working towards developing a reliable system for:
- High-frequency trading capabilities
- Multi-account algorithmic trading
- Cross-broker trading operations
- Stable API integration

## 🤝 Contributing

Your contributions make this project better! Feel free to:
- Fork the repository
- Submit pull requests
- Report issues
- Suggest improvements

## ⭐ Show Your Support

If you find this project helpful, please consider:
- Giving it a star on GitHub! 🌟
- Contributing to its development 🛠️
- Sharing it with others who might benefit 🔄

Let's make automated trading on Linux servers easier together! 🚀

---
Made with ❤️ for the trading community 📈
