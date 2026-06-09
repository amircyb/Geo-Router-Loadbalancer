🩸 Bloodcyb Geo-Router & Loadbalancer
Bloodcyb is an advanced, automated Geo-DNS routing and Loadbalancer system designed specifically for split-traffic architectures (e.g., routing local users to a local server and international bots/users to an external server) without harming SEO.

It comes with a fully-featured, beautifully designed Dark Mode Web Dashboard to manage clusters, monitor live visual logs, and auto-deploy Let's Encrypt SSL certificates with a single click.
✨ Key Features
🌍 Smart Geo-Routing: Seamlessly routes traffic based on MaxMind GeoLite2 databases. Perfect for Active-Active server architectures.

🎨 Creative Management Dashboard: A stunning, fully responsive Bootstrap 5.3 (Dark Mode) UI with Vazirmatn typography.

📊 Visual Live Monitoring: Transforms boring Nginx access logs into a visual, animated routing dashboard (JSON-based Nginx logging).

🔒 Automated SSL: Fully integrated with Certbot. Issue Let's Encrypt certificates for your routed domains directly from the GUI.

🩺 Built-in Health Checks: Instantly ping target server ports to detect firewall blocks or downtimes.

🛠️ Master Installer/Uninstaller: A smart bash script that detects server state, installs all dependencies, and can cleanly remove the entire system if needed.
⚙️ How It Works
Incoming Traffic: Reaches the Bloodcyb Loadbalancer server.

Decision Engine: Nginx parses the client IP via the GeoIP module.

Routing: * If IP matches IR (or your defined local region), it proxies to the Local Node.

If IP is anything else (including Googlebots), it proxies to the International Node.

SEO Safe: Preserves all real-client IP headers (X-Real-IP, X-Forwarded-For) so your backend (e.g., Laravel, WordPress on cPanel) works flawlessly.
🚀 Installation Guide
You need a fresh Ubuntu or Debian server with root privileges.

Step 1: Download the Master Installer script:

wget https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/YOUR_REPOSITORY_NAME/main/bloodcyb.sh
Step 2: Make it executable:

Bash
chmod +x bloodcyb.sh
Step 3: Run the interactive installer:

Bash
./bloodcyb.sh
Follow the on-screen prompt to set your Secure Admin Password. The script will compile the stack, configure the Nginx modules, and launch the UI in under 2 minutes.

💻 Accessing the Dashboard
Once installed, navigate to the assigned port on your server's IP:

URL: http://YOUR_SERVER_IP:8888

Password: The one you set during installation.

🗑️ Uninstallation / Repair
Simply run the script again. The Master Manager will detect the existing installation and provide a menu to either Repair/Update the UI or Completely Uninstall the system and remove all routed configurations safely.

Bash
./bloodcyb.sh
👨‍💻 Author
Developed with ❤️ by Bloodcyb.
