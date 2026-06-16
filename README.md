# 🩸 Bloodcyb Core - Enterprise Geo-Router & Proxy Engine

![Version](https://img.shields.io/badge/Version-13.6_Enterprise_Edition-blue.svg)
![Platform](https://img.shields.io/badge/Platform-Ubuntu%20%7C%20Debian-green.svg)
![Stack](https://img.shields.io/badge/Stack-Nginx%20%7C%20PHP--FPM%20%7C%20GOST%20%7C%20Systemd-red.svg)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

**Bloodcyb Core** is an advanced, automated Geo-DNS routing, Loadbalancer, and **Anti-Filtering Tunnel Management** system. It is designed specifically for split-traffic architectures—allowing you to route local users directly to a local server while channeling international bots/users through secure proxy tunnels (e.g., bypassing strict firewalls), all without harming your SEO.

It comes with a fully-featured, beautifully designed **Dark Mode Web Dashboard** to manage clusters, monitor live visual logs, handle unlimited proxies as system services, and auto-deploy Let's Encrypt SSL certificates with a single click.

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/3ea068ff-d925-4051-9426-dc278cd91a5d" />


## ✨ Key Features (v13.6 Updates)

* 🌍 **Smart Geo-Routing:** Seamlessly routes traffic based on MaxMind GeoLite2 databases. Perfect for Active-Active server architectures.
* 🛡️ **Unlimited GOST Tunnels (Systemd):** Add unlimited HTTP/SOCKS5 proxies. The system automatically converts them into official Linux `systemd` background services for 100% uptime and persistence.
* 🎛️ **Granular Routing Control:** Bind different routing logics per node. (e.g., Iran traffic goes *Direct*, Foreign traffic goes through *Proxy Tunnel #2*).
* 🩺 **Deep Inspection Radar & Health Checks:** 
  * **Anti-Freeze Engine:** Strict timeouts prevent the UI from freezing even if the target server drops packets.
  * **Anti-DNS Poisoning:** Smart pinging mechanism that bypasses local ISP DNS manipulation.
  * **Raw Debugger:** Instantly view raw `cURL` connection errors and `journalctl` proxy logs directly in the UI if a tunnel fails.
* 🎨 **Creative Management Dashboard:** A stunning, fully responsive Bootstrap 5.3 (Dark Mode) UI with Vazirmatn typography.
* 📊 **Visual Live Monitoring:** Transforms raw Nginx access logs into an animated, JSON-based visual tracking dashboard.
* 🔒 **Automated SSL:** Fully integrated with Certbot. Issue Let's Encrypt certificates directly from the GUI.

## ⚙️ How It Works

1. **Incoming Traffic:** Reaches the Bloodcyb Loadbalancer server.
2. **Decision Engine:** Nginx parses the client IP via the GeoIP2 module.
3. **Smart Routing:** 
   * If IP matches the local region (e.g., `IR`), it follows the assigned route (Direct or via a specific local GOST Tunnel).
   * If IP is international (including Googlebots), it follows the foreign route (Direct or via a specific secure GOST Tunnel).
4. **SEO Safe:** Preserves all real-client IP headers (`X-Real-IP`, `X-Forwarded-For`) so your backend (e.g., Laravel, WordPress) sees the actual user.

## 🚀 Installation Guide

You need a fresh **Ubuntu** or **Debian** server with `root` privileges.

**Step 1:** Download the Master Installer script:
```bash
wget https://raw.githubusercontent.com/amircyb/Geo-Router-Loadbalancer/main/bloodcyb.sh
```

**Step 2:** Make it executable:
```bash
chmod +x bloodcyb.sh
```

**Step 3:** Run the interactive installer:
```bash
./bloodcyb.sh
```
Follow the on-screen prompts to set your Secure Admin Password. The script will automatically compile the stack, configure Nginx & GeoIP, install the official GOST binary, and launch the UI in under 2 minutes.

## 💻 Accessing the Dashboard

Once installed, navigate to the assigned port on your server's IP:
* **URL:** `http://YOUR_SERVER_IP:8888`
* **Password:** The one you set during installation.

## 🗑️ Uninstallation / Update / Repair

The `bloodcyb.sh` script acts as a Master Manager. Simply run the script again on an existing installation to access the maintenance menu:

```bash
./bloodcyb.sh
```
* **Option 1 (Update/Repair):** Applies the latest UI/Engine updates without deleting your existing domains or proxy configurations.
* **Option 2 (Uninstall):** Safely stops and removes all custom systemd services, wipes Nginx configurations, and uninstalls the panel completely.

---
👨‍💻 **Developed with ❤️ by Amircyb** - *Built for an open and unrestricted internet.*
