#!/bin/bash
# =================================================================
# Bloodcyb Core - Anti-Freeze Fast Radar (Version 13.6)
# Stack: Nginx (JSON), PHP-FPM, Bootstrap 5.3 Dark, Systemd Multi-GOST
# =================================================================

set -e

GREEN="\e[32m"
BLUE="\e[36m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

echo -e "${BLUE}=================================================================${RESET}"
echo -e "${BLUE}   🩸 Bloodcyb Core - Ultimate Routing Engine (v13.6)${RESET}"
echo -e "${BLUE}=================================================================${RESET}"

uninstall_system() {
    echo -e "${YELLOW}[!] Warning: Removing Bloodcyb panel and all configurations...${RESET}"
    read -p "Are you sure? (y/n): " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        rm -rf /var/www/bloodcyb
        rm -f /etc/sudoers.d/bloodcyb-panel
        rm -f /etc/nginx/sites-available/bloodcyb-panel.conf
        rm -f /etc/nginx/sites-enabled/bloodcyb-panel.conf
        rm -f /etc/nginx/conf.d/bcyb_log.conf
        rm -f /usr/local/bin/bcyb-proxy
        
        for svc in $(systemctl list-unit-files | grep "bcyb-gost-" | awk '{print $1}'); do
            systemctl stop $svc || true
            systemctl disable $svc || true
            rm -f /etc/systemd/system/$svc
        done
        systemctl daemon-reload
        
        for conf in /etc/nginx/sites-available/*.conf; do
            if [ -f "$conf" ] && grep -q "upstream iran_" "$conf"; then
                domain_file=$(basename "$conf")
                rm -f "$conf"
                rm -f "/etc/nginx/sites-enabled/$domain_file"
            fi
        done
        systemctl reload nginx || true
        echo -e "${GREEN}[SUCCESS] Uninstalled successfully.${RESET}"
    fi
    exit 0
}

install_system() {
    read -p ">> Enter secure password for Admin Panel: " PANEL_PASS
    PANEL_PASS_HASH=$(php -r "echo password_hash('$PANEL_PASS', PASSWORD_DEFAULT);")

    echo -e "${BLUE}[*] Installing packages...${RESET}"
    apt-get update -y -q
    apt-get install -y -q nginx php-fpm php-curl php-cli curl wget sudo libnginx-mod-http-geoip2 certbot python3-certbot-nginx

    if [ ! -f /usr/local/bin/gost ]; then
        echo -e "${BLUE}[*] Downloading Official GOST Proxy Engine...${RESET}"
        wget -qO /tmp/gost.gz https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-linux-amd64-2.11.5.gz
        gzip -d -f /tmp/gost.gz
        chmod +x /tmp/gost
        mv /tmp/gost /usr/local/bin/gost
    fi

    if [ ! -f /etc/nginx/geoip/GeoLite2-Country.mmdb ]; then
        mkdir -p /etc/nginx/geoip
        wget -q -O /etc/nginx/geoip/GeoLite2-Country.mmdb https://github.com/P3TERX/GeoLite.mmdb/raw/download/GeoLite2-Country.mmdb
        chown -R www-data:www-data /etc/nginx/geoip
    fi

    cat <<'EOF' > /etc/nginx/conf.d/geoip.conf
geoip2 /etc/nginx/geoip/GeoLite2-Country.mmdb {
    $geoip_country_code country iso_code;
}
EOF

    cat <<'EOF' > /etc/nginx/conf.d/bcyb_log.conf
log_format bcyb_json escape=json '{"ip":"$remote_addr","time":"$time_iso8601","req":"$request","status":"$status","ua":"$http_user_agent","country":"$geoip_country_code"}';
EOF

    echo -e "${BLUE}[*] Deploying Systemd Service Manager...${RESET}"
    cat <<'EOF' > /usr/local/bin/bcyb-proxy
#!/bin/bash
PORT=$2
URL=$3
SVC="bcyb-gost-${PORT}"

if [ "$1" == "start" ]; then
    cat <<SYSTEMD > /etc/systemd/system/${SVC}.service
[Unit]
Description=Bloodcyb GOST Proxy Port $PORT
After=network.target

[Service]
Type=simple
LimitNOFILE=65535
ExecStart=/usr/local/bin/gost -L=http://127.0.0.1:$PORT -F="$URL"
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SYSTEMD
    systemctl daemon-reload
    systemctl enable ${SVC}
    systemctl restart ${SVC}
    echo "Service $SVC started"
elif [ "$1" == "stop" ]; then
    systemctl stop ${SVC} || true
    systemctl disable ${SVC} || true
    rm -f /etc/systemd/system/${SVC}.service
    systemctl daemon-reload
    echo "Service $SVC stopped"
fi
EOF
    chmod +x /usr/local/bin/bcyb-proxy

    mkdir -p /var/www/bloodcyb
    chown -R www-data:www-data /var/www/bloodcyb

    echo -e "${BLUE}[*] Compiling Dashboard UI...${RESET}"
    cat <<'EOF' > /var/www/bloodcyb/index.php
<?php
session_start();
$ADMIN_HASH = 'INSERT_HASH_HERE';

if (isset($_POST['login'])) {
    if (password_verify($_POST['password'], $ADMIN_HASH)) { $_SESSION['logged_in'] = true; } 
    else { $error = "کلید امنیتی نامعتبر است!"; }
}

if (isset($_GET['logout'])) { session_destroy(); header("Location: index.php"); exit; }

$message = "";
$active_tab = "dashboard";

$proxies_file = '/var/www/bloodcyb/proxies.json';
$proxies = file_exists($proxies_file) ? json_decode(file_get_contents($proxies_file), true) : [];

if (isset($_POST['add_proxy'])) {
    $p_name = trim($_POST['proxy_name']);
    $p_url = trim($_POST['proxy_url']);
    
    if (strpos($p_url, '://') === false) {
        $message = "<div class='alert alert-danger'><i class='fa-solid fa-triangle-exclamation me-2'></i>خطا: فرمت آدرس نامعتبر است! آدرس باید شامل <code>socks5://</code> یا <code>http://</code> باشد.</div>";
    } elseif (!empty($p_name) && !empty($p_url)) {
        $max_port = 8079;
        foreach($proxies as $p) { if(isset($p['port']) && $p['port'] > $max_port) $max_port = $p['port']; }
        $new_port = $max_port + 1;
        $id = uniqid();
        $proxies[$id] = ['name' => $p_name, 'url' => $p_url, 'port' => $new_port, 'health' => 'unknown'];
        file_put_contents($proxies_file, json_encode($proxies));
        $message = "<div class='alert alert-success'><i class='fa-solid fa-check me-2'></i>پروکسی <b>{$p_name}</b> با موفقیت اضافه شد.</div>";
    }
    $active_tab = "proxy-manager";
}

if (isset($_POST['toggle_proxy'])) {
    $id = $_POST['proxy_id'];
    $action = $_POST['action'];
    if (isset($proxies[$id])) {
        $port = $proxies[$id]['port'];
        $url = escapeshellarg($proxies[$id]['url']);
        if ($action == 'start') {
            shell_exec("sudo /usr/local/bin/bcyb-proxy start {$port} {$url}");
            $proxies[$id]['health'] = 'unknown';
            $message = "<div class='alert alert-success'><i class='fa-solid fa-server me-2'></i>سرویس لینوکسی <b>{$proxies[$id]['name']}</b> با موفقیت راه‌اندازی شد. (جهت اطمینان تست سلامت بگیرید)</div>";
        } else {
            shell_exec("sudo /usr/local/bin/bcyb-proxy stop {$port}");
            $proxies[$id]['health'] = 'unknown';
            $message = "<div class='alert alert-warning'><i class='fa-solid fa-stop me-2'></i>سرویس متوقف شد.</div>";
        }
        file_put_contents($proxies_file, json_encode($proxies));
    }
    $active_tab = "proxy-manager";
}

if (isset($_POST['test_proxy'])) {
    $id = $_POST['proxy_id'];
    if (isset($proxies[$id])) {
        $port = $proxies[$id]['port'];
        $is_running = (trim(shell_exec("sudo systemctl is-active bcyb-gost-{$port}")) == 'active');
        
        if ($is_running) {
            // Anti-Freeze & Anti-Poison Curl Command (-m 5 limits absolute max time)
            $cmd = "curl -4 -sS -L -m 5 --connect-timeout 3 -w '\\n%{http_code}' -x http://127.0.0.1:{$port} http://1.1.1.1/cdn-cgi/trace 2>&1";
            $out_raw = trim(shell_exec($cmd));
            $lines = explode("\n", $out_raw);
            $http_code = array_pop($lines);
            $curl_err = implode(" ", $lines);
            
            if ($http_code == "200") {
                $proxies[$id]['health'] = 'ok';
                $message = "<div class='alert alert-success d-flex align-items-center'><i class='fa-solid fa-shield-check fs-3 me-3'></i><div>تست موفقیت‌آمیز: <b>{$proxies[$id]['name']}</b> کاملاً سالم است و به خوبی کار می‌کند!</div></div>";
            } else {
                $proxies[$id]['health'] = 'error';
                $gost_log = shell_exec("sudo journalctl -u bcyb-gost-{$port} -n 5 --no-pager 2>/dev/null");
                $message = "<div class='alert alert-danger d-flex align-items-center'><i class='fa-solid fa-triangle-exclamation fs-3 me-3'></i><div class='w-100'><b>تست ناموفق! ارور دقیق کلاینت:</b><br><small class='font-monospace text-warning'>" . htmlspecialchars($curl_err) . "</small><hr class='my-1 border-danger'><b>لاگ سرویس لینوکس (GOST):</b><br><small class='font-monospace text-light' style='white-space: pre-wrap;'>" . htmlspecialchars($gost_log) . "</small></div></div>";
            }
            file_put_contents($proxies_file, json_encode($proxies));
        } else {
            $message = "<div class='alert alert-warning'><i class='fa-solid fa-circle-exclamation me-2'></i>برای تست سلامت، اول باید پروکسی روشن باشد!</div>";
        }
    }
    $active_tab = "proxy-manager";
}

if (isset($_POST['delete_proxy'])) {
    $id = $_POST['proxy_id'];
    if (isset($proxies[$id])) {
        shell_exec("sudo /usr/local/bin/bcyb-proxy stop {$proxies[$id]['port']}");
        unset($proxies[$id]);
        file_put_contents($proxies_file, json_encode($proxies));
        $message = "<div class='alert alert-danger'><i class='fa-solid fa-trash me-2'></i>پروکسی حذف شد.</div>";
    }
    $active_tab = "proxy-manager";
}

if (isset($_POST['add_domain'])) {
    $domain = trim($_POST['domain']);
    $iran_ip = trim($_POST['iran_ip']);
    $foreign_ip = trim($_POST['foreign_ip']);
    $iran_route = $_POST['iran_route']; 
    $foreign_route = $_POST['foreign_route'];
    $domain_safe = str_replace('.', '_', $domain);

    $iran_target = ($iran_route == 'direct') ? "{$iran_ip}:80" : "127.0.0.1:{$iran_route}";
    $foreign_target = ($foreign_route == 'direct') ? "{$foreign_ip}:80" : "127.0.0.1:{$foreign_route}";

    $config = "upstream iran_{$domain_safe} { server {$iran_target}; }\nupstream foreign_{$domain_safe} { server {$foreign_target}; }\nmap \$geoip_country_code \$target_{$domain_safe} { default foreign_{$domain_safe}; IR iran_{$domain_safe}; }\nserver {\n    listen 80;\n    server_name {$domain} www.{$domain};\n    access_log /var/log/nginx/{$domain_safe}_access.log bcyb_json;\n    location ~ /\.well-known/acme-challenge/ { root /var/www/html; allow all; }\n    location / {\n        proxy_pass http://\$target_{$domain_safe};\n        proxy_set_header Host \$host;\n        proxy_set_header X-Real-IP \$remote_addr;\n        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n        proxy_set_header X-Forwarded-Country \$geoip_country_code;\n        proxy_set_header X-Forwarded-Proto \$scheme;\n    }\n}";
    
    file_put_contents("/tmp/{$domain}.conf", $config);
    shell_exec("sudo mv /tmp/{$domain}.conf /etc/nginx/sites-available/");
    shell_exec("sudo ln -sf /etc/nginx/sites-available/{$domain}.conf /etc/nginx/sites-enabled/");
    $test = shell_exec("sudo nginx -t 2>&1");
    
    if (strpos($test, 'successful') !== false) {
        shell_exec("sudo systemctl reload nginx");
        $message = "<div class='alert alert-success'><i class='fa-solid fa-check-circle me-2'></i>کلاستر <b>{$domain}</b> ایجاد شد.</div>";
        if (isset($_POST['install_ssl'])) {
            shell_exec("sudo certbot --nginx -d {$domain} -d www.{$domain} --non-interactive --agree-tos -m admin@{$domain} 2>&1");
        }
    } else {
        $message = "<div class='alert alert-danger'>خطای Nginx:<br><pre>{$test}</pre></div>";
    }
    $active_tab = "dashboard";
}

if (isset($_POST['delete_domain'])) {
    $del_domain = trim($_POST['delete_domain']);
    $del_safe = str_replace('.', '_', $del_domain);
    shell_exec("sudo rm -f /etc/nginx/sites-available/{$del_domain}.conf /etc/nginx/sites-enabled/{$del_domain}.conf /var/log/nginx/{$del_safe}_access.log");
    shell_exec("sudo systemctl reload nginx");
    $message = "<div class='alert alert-warning'><i class='fa-solid fa-trash me-2'></i>کلاستر <b>{$del_domain}</b> پاک شد.</div>";
    $active_tab = "dashboard";
}

if (isset($_POST['do_check'])) { $active_tab = "dashboard"; }
if (isset($_POST['trigger_radar'])) { $active_tab = "network-radar"; }
if (isset($_POST['view_logs'])) { $active_tab = "logs"; }

$domains_list = [];
$files = glob('/etc/nginx/sites-enabled/*.conf');
if ($files) {
    foreach($files as $file) {
        $name = basename($file, '.conf');
        if($name !== 'bloodcyb-panel' && $name !== 'default') $domains_list[] = $name;
    }
}

function checkPort($ip, $port) {
    $fp = @fsockopen($ip, $port, $errno, $errstr, 1.5);
    if (!$fp) return "<span class='badge bg-danger'><i class='fa-solid fa-circle-xmark'></i> مسدود</span>";
    fclose($fp); return "<span class='badge bg-success'><i class='fa-solid fa-circle-check'></i> آزاد</span>";
}

function checkFirewallTarget($ip, $route) {
    if (empty($ip)) return "";
    
    // پاکسازی ورودی برای جلوگیری از باگ‌های شل
    $safe_ip = escapeshellarg("http://" . str_replace(['http://', 'https://'], '', $ip));

    if ($route === 'direct') {
        $fp = @fsockopen($ip, 80, $errno, $errstr, 2);
        if (!$fp) return "<span class='text-danger fw-bold'><i class='fa-solid fa-xmark me-1'></i> مسدود / بسته (مستقیم)</span>";
        fclose($fp); return "<span class='text-success fw-bold'><i class='fa-solid fa-check me-1'></i> آنلاین و آزاد (مستقیم)</span>";
    } else {
        $is_running = (trim(shell_exec("sudo systemctl is-active bcyb-gost-{$route}")) == 'active');
        if (!$is_running) return "<span class='text-warning fw-bold'><i class='fa-solid fa-triangle-exclamation me-1'></i> سرویس لینوکس پروکسی خاموش است!</span>";
        
        // Anti-Freeze Curl (Max time: 4 seconds)
        $cmd = "curl -4 -sL -m 4 --connect-timeout 3 -w '%{http_code}' -o /dev/null -x http://127.0.0.1:{$route} {$safe_ip} 2>/dev/null";
        $http_code = trim(shell_exec($cmd));
        
        if ($http_code == "503" || $http_code == "502") return "<span class='text-danger fw-bold'><i class='fa-solid fa-ban me-1'></i> مسدود (توسط فیلترینگ یا پروکسی Drop شد)</span>";
        if ($http_code !== "000" && $http_code !== "") return "<span class='text-success fw-bold'><i class='fa-solid fa-shield-check me-1'></i> آنلاین (آزاد از تونل) - کد $http_code</span>";
        else return "<span class='text-danger fw-bold'><i class='fa-solid fa-shield-xmark me-1'></i> Timeout / قطع (سرور مقصد مرده یا مسدود است)</span>";
    }
}
function checkNetworkExternal() { return @fsockopen("8.8.8.8", 53, $errno, $errstr, 1) !== false; }
function checkNetworkInternal() { return @fsockopen("aparat.com", 80, $errno, $errstr, 1) !== false; }

if (!isset($_SESSION['logged_in'])) {
    ?>
    <!DOCTYPE html><html lang="fa" dir="rtl" data-bs-theme="dark"><head><meta charset="UTF-8"><title>Bloodcyb | Login</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.rtl.min.css" rel="stylesheet"><link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css" rel="stylesheet"><style>body{background-color:#020617;display:flex;align-items:center;justify-content:center;min-height:100vh;}.login-card{background:#0f172a;border:1px solid #1e293b;border-radius:1rem;padding:2.5rem;width:100%;max-width:400px;}</style></head>
    <body><div class="login-card"><h3 class="text-center text-info mb-4"><i class="fa-solid fa-network-wired"></i> BLOODCYB</h3><?php if(isset($error)) echo "<div class='alert alert-danger'>$error</div>"; ?><form method="POST"><input type="password" name="password" class="form-control mb-3" placeholder="رمز عبور..." required><button type="submit" name="login" class="btn btn-info w-100 fw-bold">ورود</button></form></div></body></html>
    <?php exit;
}
?>
<!DOCTYPE html>
<html lang="fa" dir="rtl" data-bs-theme="dark">
<head>
    <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Bloodcyb | Console</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.rtl.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css" rel="stylesheet">
    <link href="https://fonts.googleapis.com/css2?family=Vazirmatn:wght@400;500;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Vazirmatn', sans-serif !important; background-color: #0b1120; }
        .bg-sidebar { background-color: #0f172a; border-left: 1px solid #1e293b; }
        .nav-pills .nav-link { color: #94a3b8; border-radius: 0.5rem; padding: 0.8rem; margin-bottom: 0.5rem; font-weight: 500; }
        .nav-pills .nav-link:hover, .nav-pills .nav-link.active { background-color: rgba(14, 165, 233, 0.1); color: #0ea5e9; }
        .card-custom { background-color: #1e293b; border: 1px solid #334155; border-radius: 0.75rem; }
        .card-header-custom { border-bottom: 1px solid #334155; background-color: rgba(0,0,0,0.2); padding: 1rem 1.5rem; }
        .form-control, .form-select { background-color: #0f172a; border: 1px solid #334155; color: #f8fafc; }
        .form-control:focus, .form-select:focus { border-color: #0ea5e9; box-shadow: none; background-color: #0f172a; color: #fff;}
        .sidebar-wrapper { width: 280px; position: fixed; top: 0; right: 0; bottom: 0; z-index: 1000; }
        .main-wrapper { margin-right: 280px; min-height: 100vh; }
        @media (max-width: 991.98px) { .main-wrapper { margin-right: 0; } }
        .route-line { width: 100%; height: 2px; background: #334155; position: relative; display: flex; align-items: center; justify-content: center; }
        .route-dot { position: absolute; width: 10px; height: 10px; background: #0ea5e9; border-radius: 50%; box-shadow: 0 0 10px #0ea5e9; animation: moveDot 1.5s infinite linear; }
        @keyframes moveDot { 0% { left: 100%; opacity: 0; } 20% { opacity: 1; } 80% { opacity: 1; } 100% { left: 0%; opacity: 0; } }
    </style>
</head>
<body>

<nav class="navbar bg-sidebar d-lg-none border-bottom border-secondary px-3 py-3 sticky-top">
    <h5 class="mb-0 fw-bold text-info"><i class="fa-solid fa-network-wired me-2"></i>BLOODCYB</h5>
    <button class="btn btn-outline-secondary border-0" data-bs-toggle="offcanvas" data-bs-target="#sidebarMobile"><i class="fa-solid fa-bars text-white"></i></button>
</nav>

<?php ob_start(); ?>
<div class="p-4 d-flex flex-column h-100 bg-sidebar">
    <div class="text-center mb-5 d-none d-lg-block">
        <h4 class="fw-bold text-info"><i class="fa-solid fa-network-wired me-2"></i>BLOODCYB</h4>
        <span class="badge bg-success bg-opacity-10 text-success border border-success px-2 py-1">Engine Online</span>
    </div>
    <ul class="nav flex-column nav-pills w-100" id="main-tabs" role="tablist">
        <li class="nav-item"><button class="nav-link w-100 text-start active" id="tab-dashboard" data-bs-toggle="pill" data-bs-target="#dashboard" type="button"><i class="fa-solid fa-route me-3 w-20px"></i> مرکز فرماندهی</button></li>
        <li class="nav-item"><button class="nav-link w-100 text-start" id="tab-proxy-manager" data-bs-toggle="pill" data-bs-target="#proxy-manager" type="button"><i class="fa-solid fa-server me-3 w-20px"></i> لیست پروکسی‌ها</button></li>
        <li class="nav-item"><button class="nav-link w-100 text-start" id="tab-network-radar" data-bs-toggle="pill" data-bs-target="#network-radar" type="button"><i class="fa-solid fa-radar me-3 w-20px"></i> رادار و تست اتصال</button></li>
        <li class="nav-item"><button class="nav-link w-100 text-start" id="tab-logs" data-bs-toggle="pill" data-bs-target="#logs" type="button"><i class="fa-solid fa-eye me-3 w-20px"></i> مانیتورینگ گرافیکی</button></li>
    </ul>
    <div class="mt-auto"><a class="btn btn-outline-danger w-100" href="?logout=true"><i class="fa-solid fa-power-off me-2"></i> خروج</a></div>
</div>
<?php $sidebarContent = ob_get_clean(); ?>

<div class="sidebar-wrapper d-none d-lg-block"><?= $sidebarContent ?></div>
<div class="offcanvas offcanvas-end bg-sidebar" id="sidebarMobile"><div class="offcanvas-body p-0"><?= $sidebarContent ?></div></div>

<div class="main-wrapper p-4 p-md-5">
    <?php if(!empty($message)) echo "<div class='mb-4'>$message</div>"; ?>

    <div class="tab-content">
        <div class="tab-pane fade show active" id="dashboard">
            <h4 class="fw-bold text-white mb-4"><i class="fa-solid fa-border-all text-primary me-2"></i> مرکز فرماندهی شبکه</h4>
            
            <div class="row g-4 mb-4">
                <div class="col-xl-7">
                    <div class="card-custom h-100">
                        <div class="card-header-custom text-info fw-bold"><i class="fa-solid fa-plus me-2"></i> استقرار مسیر جدید با کانفیگ اختصاصی</div>
                        <div class="card-body p-4">
                            <form method="POST">
                                <div class="mb-4">
                                    <label class="form-label text-muted small">نام دامنه (بدون www)</label>
                                    <input type="text" name="domain" class="form-control" placeholder="example.com" required>
                                </div>
                                <div class="row g-4 mb-4">
                                    <div class="col-md-6">
                                        <label class="form-label text-danger fw-bold small"><i class="fa-solid fa-server me-1"></i> آی‌پی و مسیر نود ایران</label>
                                        <input type="text" name="iran_ip" class="form-control mb-2" placeholder="IP ایران" style="border-right: 3px solid #ef4444;" required>
                                        <select name="iran_route" class="form-select border-danger text-muted">
                                            <option value="direct">مسیر مستقیم (IP عادی)</option>
                                            <?php foreach($proxies as $id => $p): ?>
                                                <option value="<?= $p['port'] ?>">تونل: <?= htmlspecialchars($p['name']) ?></option>
                                            <?php endforeach; ?>
                                        </select>
                                    </div>
                                    <div class="col-md-6">
                                        <label class="form-label text-primary fw-bold small"><i class="fa-solid fa-earth-americas me-1"></i> آی‌پی و مسیر نود بین‌الملل</label>
                                        <input type="text" name="foreign_ip" class="form-control mb-2" placeholder="IP خارج" style="border-right: 3px solid #3b82f6;" required>
                                        <select name="foreign_route" class="form-select border-primary text-muted">
                                            <option value="direct">مسیر مستقیم (IP عادی)</option>
                                            <?php foreach($proxies as $id => $p): ?>
                                                <option value="<?= $p['port'] ?>">تونل: <?= htmlspecialchars($p['name']) ?></option>
                                            <?php endforeach; ?>
                                        </select>
                                    </div>
                                </div>
                                <div class="d-flex justify-content-between align-items-center p-3 mb-4 rounded bg-dark border border-secondary">
                                    <span class="text-white"><i class="fa-solid fa-shield-halved text-success me-2"></i> صدور خودکار SSL</span>
                                    <input class="form-check-input bg-success border-success" type="checkbox" name="install_ssl" checked>
                                </div>
                                <button type="submit" name="add_domain" class="btn btn-primary w-100 py-2"><i class="fa-solid fa-rocket me-2"></i> راه‌اندازی کلاستر</button>
                            </form>
                        </div>
                    </div>
                </div>

                <div class="col-xl-5">
                    <div class="card-custom h-100">
                        <div class="card-header-custom text-warning fw-bold"><i class="fa-solid fa-radar me-2"></i> بررسی فایروال (مستقیم / پروکسی)</div>
                        <div class="card-body p-4">
                            <p class="text-muted small mb-4">آی‌پی سرور مقصد را وارد کنید تا از طریق مسیر انتخاب‌شده تست شود.</p>
                            <form method="POST" class="mb-4">
                                <div class="input-group mb-3">
                                    <span class="input-group-text bg-dark border-secondary"><i class="fa-solid fa-globe text-muted"></i></span>
                                    <input type="text" name="check_ip" class="form-control" placeholder="آی‌پی سرور..." required value="<?= $_POST['check_ip'] ?? '' ?>">
                                </div>
                                <div class="input-group">
                                    <select name="check_route" class="form-select border-secondary text-muted bg-dark">
                                        <option value="direct">تست مسیر مستقیم (بدون واسطه)</option>
                                        <?php foreach($proxies as $id => $p): ?>
                                            <option value="<?= $p['port'] ?>" <?= (isset($_POST['check_route']) && $_POST['check_route'] == $p['port']) ? 'selected' : '' ?>>تست با: <?= htmlspecialchars($p['name']) ?></option>
                                        <?php endforeach; ?>
                                    </select>
                                    <button type="submit" name="do_check" class="btn btn-warning px-3 fw-bold text-dark"><i class="fa-solid fa-magnifying-glass"></i> اسکن</button>
                                </div>
                            </form>
                            <?php if (isset($_POST['do_check'])): ?>
                                <div class="p-4 bg-dark rounded border border-secondary text-center">
                                    <div class="text-muted small mb-3">نتیجه تست ارتباط:</div>
                                    <div class="fs-6"><?= checkFirewallTarget(trim($_POST['check_ip']), $_POST['check_route']) ?></div>
                                </div>
                            <?php endif; ?>
                        </div>
                    </div>
                </div>
            </div>

            <div class="card-custom">
                <div class="card-header-custom text-success fw-bold"><i class="fa-solid fa-server me-2"></i> کلاسترهای در حال اجرا</div>
                <div class="card-body p-0">
                    <table class="table table-dark table-hover mb-0 align-middle">
                        <thead><tr><th class="ps-4 py-3">دامنه</th><th class="py-3">مسیر ایران</th><th class="py-3">مسیر خارج</th><th class="text-end pe-4">حذف</th></tr></thead>
                        <tbody>
                            <?php if(empty($domains_list)): ?><tr><td colspan="4" class="text-center py-4 text-muted">رکوردی یافت نشد.</td></tr>
                            <?php else: foreach($domains_list as $dom): 
                                $conf = file_get_contents("/etc/nginx/sites-enabled/{$dom}.conf");
                                preg_match('/upstream iran_[^ ]+ \{ server (127\.0\.0\.1:[0-9]+); \}/', $conf, $ir_match);
                                preg_match('/upstream foreign_[^ ]+ \{ server (127\.0\.0\.1:[0-9]+); \}/', $conf, $fr_match);
                            ?>
                            <tr>
                                <td class="ps-4 py-3 fw-bold text-info"><?= $dom ?></td>
                                <td><?= isset($ir_match[1]) ? "<span class='badge bg-warning text-dark'>تونل: {$ir_match[1]}</span>" : "<span class='badge bg-success'>مستقیم</span>" ?></td>
                                <td><?= isset($fr_match[1]) ? "<span class='badge bg-warning text-dark'>تونل: {$fr_match[1]}</span>" : "<span class='badge bg-success'>مستقیم</span>" ?></td>
                                <td class="text-end pe-4"><form method="POST" class="d-inline"><input type="hidden" name="delete_domain" value="<?= $dom ?>"><button type="submit" class="btn btn-sm btn-outline-danger"><i class="fa-solid fa-trash"></i></button></form></td>
                            </tr>
                            <?php endforeach; endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>

        <div class="tab-pane fade" id="proxy-manager">
            <h4 class="fw-bold text-white mb-4"><i class="fa-solid fa-server text-warning me-2"></i> مدیریت تونل‌ها (افزودن نامحدود پروکسی)</h4>
            
            <div class="card-custom mb-4">
                <div class="card-body p-4">
                    <form method="POST" class="row g-3 align-items-end">
                        <div class="col-md-3">
                            <label class="form-label text-muted small">نام دلخواه (مثلا: سرور هلند)</label>
                            <input type="text" name="proxy_name" class="form-control" required>
                        </div>
                        <div class="col-md-7">
                            <label class="form-label text-muted small">آدرس پروکسی (فرمت صحیح: <code>socks5://user:pass@ip:port</code> یا <code>http://...</code>)</label>
                            <input type="text" name="proxy_url" class="form-control" placeholder="http://user:pass@ip:port" required>
                        </div>
                        <div class="col-md-2">
                            <button type="submit" name="add_proxy" class="btn btn-primary w-100 fw-bold"><i class="fa-solid fa-plus me-1"></i> افزودن</button>
                        </div>
                    </form>
                </div>
            </div>

            <div class="row g-4">
                <?php foreach($proxies as $id => $p): 
                    $is_running = (trim(shell_exec("sudo systemctl is-active bcyb-gost-{$p['port']}")) == 'active');
                    $health = isset($p['health']) ? $p['health'] : 'unknown';
                    
                    if($is_running) {
                        if ($health == 'ok') { $status_badge = '<span class="badge bg-success"><i class="fa-solid fa-circle-check"></i> متصل و سالم</span>'; $border_color = 'border-success'; } 
                        elseif ($health == 'error') { $status_badge = '<span class="badge bg-danger"><i class="fa-solid fa-triangle-exclamation"></i> مسدود / خطا</span>'; $border_color = 'border-danger'; } 
                        else { $status_badge = '<span class="badge bg-warning text-dark"><i class="fa-solid fa-bolt"></i> سرویس در حال اجرا</span>'; $border_color = 'border-warning'; }
                    } else {
                        $status_badge = '<span class="badge bg-secondary">سرویس متوقف است</span>'; $border_color = 'border-secondary';
                    }
                ?>
                <div class="col-md-6 col-xl-4">
                    <div class="card-custom h-100 border-start border-4 <?= $border_color ?>">
                        <div class="card-body p-4">
                            <div class="d-flex justify-content-between align-items-center mb-3">
                                <h5 class="text-white fw-bold mb-0"><?= htmlspecialchars($p['name']) ?></h5>
                                <?= $status_badge ?>
                            </div>
                            <p class="text-muted small font-monospace mb-2 text-truncate" title="<?= htmlspecialchars($p['url']) ?>"><?= htmlspecialchars($p['url']) ?></p>
                            <p class="text-info small mb-4">پورت داخلی سرور: <b class="fs-6"><?= $p['port'] ?></b></p>
                            
                            <div class="d-flex justify-content-between align-items-center border-top border-secondary pt-3">
                                <div class="d-flex gap-2">
                                    <form method="POST" class="m-0">
                                        <input type="hidden" name="proxy_id" value="<?= $id ?>">
                                        <?php if($is_running): ?>
                                            <input type="hidden" name="action" value="stop">
                                            <button type="submit" name="toggle_proxy" class="btn btn-warning btn-sm fw-bold"><i class="fa-solid fa-stop me-1"></i> توقف</button>
                                        <?php else: ?>
                                            <input type="hidden" name="action" value="start">
                                            <button type="submit" name="toggle_proxy" class="btn btn-success btn-sm fw-bold"><i class="fa-solid fa-play me-1"></i> روشن کن</button>
                                        <?php endif; ?>
                                    </form>
                                    <form method="POST" class="m-0">
                                        <input type="hidden" name="proxy_id" value="<?= $id ?>">
                                        <button type="submit" name="test_proxy" class="btn btn-info btn-sm fw-bold text-dark"><i class="fa-solid fa-stethoscope me-1"></i> تست سلامت</button>
                                    </form>
                                </div>
                                
                                <form method="POST" class="m-0" onsubmit="return confirm('آیا از حذف این پروکسی مطمئن هستید؟');">
                                    <input type="hidden" name="proxy_id" value="<?= $id ?>">
                                    <button type="submit" name="delete_proxy" class="btn btn-outline-danger btn-sm"><i class="fa-solid fa-trash"></i></button>
                                </form>
                            </div>
                        </div>
                    </div>
                </div>
                <?php endforeach; ?>
            </div>
        </div>

        <div class="tab-pane fade" id="network-radar">
            <h4 class="fw-bold text-white mb-4"><i class="fa-solid fa-radar text-info me-2"></i> رادار و تست اتصال شبکه</h4>
            <div class="row g-4">
                <div class="col-lg-4">
                    <div class="card-custom mb-4">
                        <div class="card-header-custom fw-bold"><i class="fa-solid fa-globe me-2"></i> وضعیت سرور فعلی</div>
                        <div class="card-body p-4">
                            <div class="mb-3 d-flex justify-content-between"><span>دسترسی ایران:</span> <?= checkNetworkInternal() ? '<span class="text-success"><i class="fa-solid fa-check"></i> متصل</span>' : '<span class="text-danger"><i class="fa-solid fa-xmark"></i> قطع</span>' ?></div>
                            <div class="d-flex justify-content-between"><span>دسترسی بین‌الملل:</span> <?= checkNetworkExternal() ? '<span class="text-success"><i class="fa-solid fa-check"></i> آزاد</span>' : '<span class="text-danger"><i class="fa-solid fa-xmark"></i> مسدود</span>' ?></div>
                        </div>
                    </div>
                </div>
                <div class="col-lg-8">
                    <div class="card-custom">
                        <div class="card-header-custom fw-bold"><i class="fa-solid fa-magnifying-glass me-2"></i> بررسی کلاینت و پورت (Check-Host)</div>
                        <div class="card-body p-4">
                            <form method="POST" class="row g-3 mb-4">
                                <div class="col-md-7"><input type="text" name="radar_ip" class="form-control" placeholder="آی‌پی یا دامنه (مثال: 1.1.1.1)" required value="<?= $_POST['radar_ip'] ?? '' ?>"><input type="hidden" name="trigger_radar" value="1"></div>
                                <div class="col-md-2"><input type="number" name="radar_port" class="form-control" placeholder="پورت (80)" value="<?= $_POST['radar_port'] ?? '80' ?>"></div>
                                <div class="col-md-3"><button type="submit" class="btn btn-info w-100 text-dark fw-bold">اسکن پورت</button></div>
                            </form>
                            <?php if (isset($_POST['trigger_radar'])): $t = trim($_POST['radar_ip']); $p = (int)$_POST['radar_port']; ?>
                                <div class="p-3 bg-dark border border-secondary rounded">
                                    <h6 class="text-info mb-3">نتیجه اسکن: <?= htmlspecialchars($t) ?>:<?= $p ?></h6>
                                    <div class="d-flex justify-content-between mb-2 pb-2 border-bottom border-secondary"><span>از داخل سرور شما:</span> <?= checkPort($t, $p) ?></div>
                                    <div class="d-flex justify-content-between mb-2 pb-2 border-bottom border-secondary"><span>پورت ۸۰ (HTTP):</span> <?= checkPort($t, 80) ?></div>
                                    <div class="d-flex justify-content-between"><span>پورت ۵۳ (DNS):</span> <?= checkPort($t, 53) ?></div>
                                </div>
                            <?php endif; ?>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="tab-pane fade" id="logs">
            <h4 class="fw-bold text-white mb-4"><i class="fa-solid fa-eye text-success me-2"></i> مانیتورینگ گرافیکی ترافیک</h4>
            <div class="card-custom">
                <div class="card-body p-4">
                    <form method="POST" class="row g-3 mb-4 border-bottom border-secondary pb-4">
                        <div class="col-md-8"><select name="log_domain" class="form-select" required><option value="">انتخاب کلاستر...</option><?php foreach($domains_list as $dom): ?><option value="<?= $dom ?>" <?= (isset($_POST['log_domain']) && $_POST['log_domain']==$dom)?'selected':'' ?>><?= $dom ?></option><?php endforeach; ?></select></div>
                        <div class="col-md-4"><button type="submit" name="view_logs" class="btn btn-success w-100 fw-bold">بارگذاری لاگ زنده</button></div>
                    </form>
                    <div>
                    <?php
                    if (isset($_POST['view_logs']) && !empty($_POST['log_domain'])) {
                        $log_file = "/var/log/nginx/".str_replace('.', '_', $_POST['log_domain'])."_access.log";
                        if (file_exists($log_file)) {
                            $log_output = shell_exec("sudo tail -n 10 " . escapeshellarg($log_file) . " 2>&1");
                            if(empty(trim($log_output))) { echo "<div class='text-center text-muted py-4'>ترافیکی ثبت نشده است.</div>"; }
                            else {
                                foreach(array_reverse(explode("\n", trim($log_output))) as $line) {
                                    $data = json_decode($line, true);
                                    if ($data) {
                                        $n_n = ($data['country']==='IR') ? 'ایران 🇮🇷' : 'خارج 🌍';
                                        $clr = ($data['status']>=400) ? 'danger' : 'success';
                                        echo "<div class='d-flex justify-content-between align-items-center p-3 mb-2 bg-dark rounded border border-secondary'><div><b class='text-info'>{$data['ip']}</b> <span class='text-muted small ms-2'>".date('H:i:s',strtotime($data['time']))."</span><div class='small text-muted'>".htmlspecialchars($data['req'])."</div></div><div class='text-end'><span class='badge bg-{$clr} mb-1'>HTTP {$data['status']}</span><br><small class='text-white'>{$n_n}</small></div></div>";
                                    }
                                }
                            }
                        } else { echo "<div class='alert alert-warning'>فایل لاگ یافت نشد.</div>"; }
                    }
                    ?>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
<script>
    document.addEventListener("DOMContentLoaded", function() {
        const activeTabId = 'tab-<?= $active_tab ?>';
        const triggerEl = document.getElementById(activeTabId);
        if (triggerEl) { new bootstrap.Tab(triggerEl).show(); }
    });
</script>
</body></html>
EOF

    sed -i "s|INSERT_HASH_HERE|$PANEL_PASS_HASH|g" /var/www/bloodcyb/index.php

    echo -e "${BLUE}[*] Configuring Internal Web Server...${RESET}"
    cat <<'EOF' > /etc/nginx/sites-available/bloodcyb-panel.conf
server { listen 8888; server_name _; root /var/www/bloodcyb; index index.php; location / { try_files $uri $uri/ =404; } location ~ \.php$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:/var/run/php/php-fpm.sock; } }
EOF

    PHP_SOCK=$(find /var/run/php/ -name "*.sock" | head -n 1)
    if [ ! -z "$PHP_SOCK" ]; then sed -i "s|unix:/var/run/php/php-fpm.sock;|unix:$PHP_SOCK;|g" /etc/nginx/sites-available/bloodcyb-panel.conf; fi
    ln -sf /etc/nginx/sites-available/bloodcyb-panel.conf /etc/nginx/sites-enabled/

    echo -e "${BLUE}[*] Setting secure execution permissions...${RESET}"
    cat <<'EOF' > /etc/sudoers.d/bloodcyb-panel
www-data ALL=(root) NOPASSWD: /usr/sbin/nginx, /usr/bin/certbot, /bin/systemctl, /bin/mv /tmp/*.conf /etc/nginx/sites-available/, /bin/ln -sf /etc/nginx/sites-available/* /etc/nginx/sites-enabled/, /bin/rm -f /etc/nginx/sites-available/*.conf, /bin/rm -f /etc/nginx/sites-enabled/*.conf, /bin/rm -f /var/log/nginx/*_access.log, /usr/bin/tail, /usr/local/bin/bcyb-proxy, /usr/bin/journalctl
EOF
    chmod 0440 /etc/sudoers.d/bloodcyb-panel
    systemctl restart nginx; systemctl restart php*-fpm

    SERVER_IP=$(curl -s ifconfig.me)
    echo -e "${GREEN}=================================================================${RESET}"
    echo -e "${GREEN} [SUCCESS] Bloodcyb 13.6 (Anti-Freeze Edition) Deployed!${RESET}"
    echo -e "${GREEN} -> Admin Console : http://${SERVER_IP}:8888${RESET}"
    echo -e "${GREEN}=================================================================${RESET}"
}

if [ -f "/var/www/bloodcyb/index.php" ]; then
    echo -e "${GREEN}[✔] System detected: Bloodcyb is already installed.${RESET}"
    echo "  1) Update / Repair Panel (Anti-Freeze Radar Fix)"
    echo "  2) Uninstall Completely"
    echo "  3) Exit"
    read -p "Select an option (1-3): " MENU_CHOICE
    case $MENU_CHOICE in
        1) install_system ;; 2) uninstall_system ;; 3) exit 0 ;; *) echo -e "${RED}Invalid option.${RESET}"; exit 1 ;;
    esac
else
    install_system
fi
