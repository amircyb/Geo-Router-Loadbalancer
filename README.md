# 🩸 Bloodcyb Geo-Router & Loadbalancer

![Version](https://img.shields.io/badge/Version-8.0_Cloud_Edition-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian-green.svg)
![Stack](https://img.shields.io/badge/Stack-Nginx%20%7C%20PHP--FPM%20%7C%20Bootstrap%205-red.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

**Bloodcyb** is an advanced, automated Geo-DNS routing and Loadbalancer system designed specifically for split-traffic architectures (e.g., routing local users to a local server and international bots/users to an external server) without harming SEO.

It comes with a fully-featured, beautifully designed **Dark Mode Web Dashboard** to manage clusters, monitor live visual logs, and auto-deploy Let's Encrypt SSL certificates with a single click.

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/b86c8224-0ab2-42a5-a4a6-8c81e09f3b7d" />


## ✨ Key Features

* 🌍 **Smart Geo-Routing:** Seamlessly routes traffic based on MaxMind GeoLite2 databases. Perfect for Active-Active server architectures.
* 🎨 **Creative Management Dashboard:** A stunning, fully responsive Bootstrap 5.3 (Dark Mode) UI with Vazirmatn typography.
* 📊 **Visual Live Monitoring:** Transforms boring Nginx access logs into a visual, animated routing dashboard (JSON-based Nginx logging).
* 🔒 **Automated SSL:** Fully integrated with Certbot. Issue Let's Encrypt certificates for your routed domains directly from the GUI.
* 🩺 **Built-in Health Checks:** Instantly ping target server ports to detect firewall blocks or downtimes.
* 🛠️ **Master Installer/Uninstaller:** A smart bash script that detects server state, installs all dependencies, and can cleanly remove the entire system if needed.

## ⚙️ How It Works

1. **Incoming Traffic:** Reaches the Bloodcyb Loadbalancer server.
2. **Decision Engine:** Nginx parses the client IP via the GeoIP module.
3. **Routing:** * If IP matches `IR` (or your defined local region), it proxies to the Local Node.
   * If IP is anything else (including Googlebots), it proxies to the International Node.
4. **SEO Safe:** Preserves all real-client IP headers (`X-Real-IP`, `X-Forwarded-For`) so your backend (e.g., Laravel, WordPress on cPanel) works flawlessly.

## 🚀 Installation Guide

You need a fresh **Ubuntu** or **Debian** server with root privileges.

**Step 1:** Download the Master Installer script:
```bash
wget [https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/YOUR_REPOSITORY_NAME/main/bloodcyb.sh](https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/YOUR_REPOSITORY_NAME/main/bloodcyb.sh)
```
**Step 2: Make it executable:

```bash
chmod +x bloodcyb.sh
```
**Step 3: Run the interactive installer:

```bash
./bloodcyb.sh
```
Follow the on-screen prompt to set your Secure Admin Password. The script will compile the stack, configure the Nginx modules, and launch the UI in under 2 minutes.

💻 Accessing the Dashboard
Once installed, navigate to the assigned port on your server's IP:

URL: http://YOUR_SERVER_IP:8888

Password: The one you set during installation.

🗑️ Uninstallation / Repair
Simply run the script again. The Master Manager will detect the existing installation and provide a menu to either Repair/Update the UI or Completely Uninstall the system and remove all routed configurations safely.

```bash
./bloodcyb.sh
```
👨‍💻 Author
Developed with ❤️ by  Bloodcyb.
