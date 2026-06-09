#!/bin/bash
# =================================================================
# Bloodcyb Core - Visual Log Edition (Version 8.0)
# Stack: Nginx (JSON Logs), PHP-FPM, Bootstrap 5.3 Dark, Vazirmatn
# =================================================================

set -e

GREEN="\e[32m"
BLUE="\e[36m"
RED="\e[31m"
YELLOW="\e[33m"
RESET="\e[0m"

echo -e "${BLUE}=================================================================${RESET}"
echo -e "${BLUE}   🩸 Bloodcyb Core - Visual Routing Engine${RESET}"
echo -e "${BLUE}=================================================================${RESET}"

uninstall_system() {
    echo -e "${YELLOW}[!] Warning: This will completely remove the Bloodcyb panel and ALL routed domains.${RESET}"
    read -p "Are you absolutely sure you want to uninstall? (y/n): " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "${RED}[*] Starting Uninstallation...${RESET}"
        rm -rf /var/www/bloodcyb
        rm -f /etc/sudoers.d/bloodcyb-panel
        rm -f /etc/nginx/sites-available/bloodcyb-panel.conf
        rm -f /etc/nginx/sites-enabled/bloodcyb-panel.conf
        rm -f /etc/nginx/conf.d/bcyb_log.conf
        
        for conf in /etc/nginx/sites-available/*.conf; do
            if [ -f "$conf" ] && grep -q "upstream iran_" "$conf"; then
                domain_file=$(basename "$conf")
                rm -f "$conf"
                rm -f "/etc/nginx/sites-enabled/$domain_file"
            fi
        done
        systemctl reload nginx || true
        echo -e "${GREEN}[SUCCESS] Bloodcyb has been completely uninstalled.${RESET}"
    else
        echo "Uninstallation aborted."
    fi
    exit 0
}

install_system() {
    read -p ">> Enter a secure password for the Admin Panel: " PANEL_PASS
    PANEL_PASS_HASH=$(php -r "echo password_hash('$PANEL_PASS', PASSWORD_DEFAULT);")

    echo -e "${BLUE}[*] Installing dependencies & Configuring GeoIP...${RESET}"
    apt-get update -y -q
    apt-get install -y -q nginx php-fpm php-curl php-cli curl wget sudo libnginx-mod-http-geoip2 certbot python3-certbot-nginx

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

    # تنظیم فرمت JSON برای لاگ‌های گرافیکی
    echo -e "${BLUE}[*] Configuring Advanced JSON Logging...${RESET}"
    cat <<'EOF' > /etc/nginx/conf.d/bcyb_log.conf
log_format bcyb_json escape=json '{"ip":"$remote_addr","time":"$time_iso8601","req":"$request","status":"$status","ua":"$http_user_agent","country":"$geoip_country_code"}';
EOF

    echo -e "${BLUE}[*] Deploying Web Dashboard & Logic...${RESET}"
    mkdir -p /var/www/bloodcyb
    chown -R www-data:www-data /var/www/bloodcyb

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

if (isset($_POST['add_domain'])) {
    $domain = trim($_POST['domain']);
    $iran_ip = trim($_POST['iran_ip']);
    $foreign_ip = trim($_POST['foreign_ip']);
    $domain_safe = str_replace('.', '_', $domain);

    # استفاده از فرمت bcyb_json در لاگ این دامنه
    $config = "upstream iran_{$domain_safe} { server {$iran_ip}:80; }\nupstream foreign_{$domain_safe} { server {$foreign_ip}:80; }\nmap \$geoip_country_code \$target_{$domain_safe} { default foreign_{$domain_safe}; IR iran_{$domain_safe}; }\nserver {\n    listen 80;\n    server_name {$domain} www.{$domain};\n    access_log /var/log/nginx/{$domain_safe}_access.log bcyb_json;\n    location ~ /\.well-known/acme-challenge/ { root /var/www/html; allow all; }\n    location / {\n        proxy_pass http://\$target_{$domain_safe};\n        proxy_set_header Host \$host;\n        proxy_set_header X-Real-IP \$remote_addr;\n        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n        proxy_set_header X-Forwarded-Country \$geoip_country_code;\n        proxy_set_header X-Forwarded-Proto \$scheme;\n    }\n}";
    
    file_put_contents("/tmp/{$domain}.conf", $config);
    shell_exec("sudo mv /tmp/{$domain}.conf /etc/nginx/sites-available/");
    shell_exec("sudo ln -sf /etc/nginx/sites-available/{$domain}.conf /etc/nginx/sites-enabled/");
    $test = shell_exec("sudo nginx -t 2>&1");
    
    if (strpos($test, 'successful') !== false) {
        shell_exec("sudo systemctl reload nginx");
        $message = "<div class='alert alert-success d-flex align-items-center rounded-3'><i class='fa-solid fa-check-circle fs-4 me-3'></i><div>کلاستر <b>{$domain}</b> با موفقیت راه‌اندازی شد.</div></div>";
        if (isset($_POST['install_ssl'])) {
            $ssl_output = shell_exec("sudo certbot --nginx -d {$domain} -d www.{$domain} --non-interactive --agree-tos -m admin@{$domain} 2>&1");
            $message .= "<div class='alert alert-info rounded-3'><pre class='mb-0 small' style='direction:ltr;'>$ssl_output</pre></div>";
        }
    } else {
        $message = "<div class='alert alert-danger rounded-3'><i class='fa-solid fa-triangle-exclamation me-2'></i>خطای کانفیگ:<br><pre class='mb-0 small mt-2' style='direction:ltr;'>$test</pre></div>";
    }
}

if (isset($_POST['delete_domain'])) {
    $del_domain = trim($_POST['delete_domain']);
    $del_safe = str_replace('.', '_', $del_domain);
    shell_exec("sudo rm -f /etc/nginx/sites-available/{$del_domain}.conf");
    shell_exec("sudo rm -f /etc/nginx/sites-enabled/{$del_domain}.conf");
    shell_exec("sudo rm -f /var/log/nginx/{$del_safe}_access.log");
    shell_exec("sudo systemctl reload nginx");
    $message = "<div class='alert alert-warning rounded-3'><i class='fa-solid fa-trash me-2'></i>کلاستر <b>{$del_domain}</b> غیرفعال و لاگ‌های آن پاک شد.</div>";
}

$domains_list = [];
$files = glob('/etc/nginx/sites-enabled/*.conf');
if ($files) {
    foreach($files as $file) {
        $name = basename($file, '.conf');
        if($name !== 'bloodcyb-panel' && $name !== 'default') $domains_list[] = $name;
    }
}

function checkServer($ip, $port = 80) {
    $fp = @fsockopen($ip, $port, $errno, $errstr, 2);
    if (!$fp) return "<span class='text-danger fw-bold'><i class='fa-solid fa-xmark me-1'></i> مسدود / آفلاین</span>";
    fclose($fp); return "<span class='text-success fw-bold'><i class='fa-solid fa-check me-1'></i> آنلاین و متصل</span>";
}

if (!isset($_SESSION['logged_in'])) {
    ?>
    <!DOCTYPE html>
    <html lang="fa" dir="rtl" data-bs-theme="dark">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>ورود | Bloodcyb Engine</title>
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.rtl.min.css" rel="stylesheet">
        <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css" rel="stylesheet">
        <link href="https://fonts.googleapis.com/css2?family=Vazirmatn:wght@400;600;800&display=swap" rel="stylesheet">
        <style>
            body { font-family: 'Vazirmatn', sans-serif !important; background-color: #020617; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; }
            .login-card { background: #0f172a; border: 1px solid #1e293b; border-radius: 1rem; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.5); width: 100%; max-width: 400px; padding: 2.5rem; }
            .form-control { background-color: #1e293b; border-color: #334155; color: #f8fafc; padding: 0.8rem 1rem; border-radius: 0.5rem; }
            .form-control:focus { border-color: #0ea5e9; box-shadow: none; background-color: #1e293b; color: #fff; }
            .btn-primary { background-color: #0ea5e9; border: none; padding: 0.8rem; border-radius: 0.5rem; font-weight: 600; }
        </style>
    </head>
    <body>
        <div class="login-card mx-3">
            <div class="text-center mb-4">
                <i class="fa-solid fa-network-wired fa-2x mb-3 text-info"></i>
                <h3 class="fw-bold text-white letter-spacing-1">BLOODCYB</h3>
            </div>
            <?php if(isset($error)) echo "<div class='alert alert-danger rounded-3 border-0 text-center'>$error</div>"; ?>
            <form method="POST">
                <div class="mb-4"><input type="password" name="password" class="form-control" placeholder="کلید امنیتی سیستم..." required></div>
                <button type="submit" name="login" class="btn btn-primary w-100 fs-6"><i class="fa-solid fa-fingerprint me-2"></i> ورود</button>
            </form>
        </div>
    </body>
    </html>
    <?php exit;
}
?>
<!DOCTYPE html>
<html lang="fa" dir="rtl" data-bs-theme="dark">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bloodcyb | Routing Console</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.rtl.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css" rel="stylesheet">
    <link href="https://fonts.googleapis.com/css2?family=Vazirmatn:wght@400;500;700;800&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Vazirmatn', sans-serif !important; background-color: #0b1120; margin: 0; overflow-x: hidden; }
        .bg-sidebar { background-color: #0f172a; border-left: 1px solid #1e293b; }
        .nav-pills .nav-link { color: #94a3b8; border-radius: 0.5rem; padding: 0.8rem 1rem; margin-bottom: 0.5rem; font-weight: 500; }
        .nav-pills .nav-link:hover, .nav-pills .nav-link.active { background-color: rgba(14, 165, 233, 0.1); color: #0ea5e9; }
        .card-custom { background-color: #1e293b; border: 1px solid #334155; border-radius: 0.75rem; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); }
        .card-header-custom { border-bottom: 1px solid #334155; background-color: rgba(0,0,0,0.2); padding: 1rem 1.5rem; }
        .form-control, .form-select { background-color: #0f172a; border: 1px solid #334155; color: #f8fafc; padding: 0.75rem 1rem; border-radius: 0.5rem; }
        .form-control:focus, .form-select:focus { background-color: #0f172a; border-color: #0ea5e9; box-shadow: none; color: #fff; }
        .sidebar-wrapper { width: 280px; position: fixed; top: 0; right: 0; bottom: 0; z-index: 1000; }
        .main-wrapper { margin-right: 280px; min-height: 100vh; display: flex; flex-direction: column; }
        @media (max-width: 991.98px) { .main-wrapper { margin-right: 0; } }
        /* انیمیشن برای مسیردهی لاگ */
        .route-line { width: 100%; height: 2px; background: #334155; position: relative; display: flex; align-items: center; justify-content: center; }
        .route-dot { position: absolute; width: 10px; height: 10px; background: #0ea5e9; border-radius: 50%; box-shadow: 0 0 10px #0ea5e9; animation: moveDot 1.5s infinite linear; }
        @keyframes moveDot { 0% { left: 100%; opacity: 0; } 20% { opacity: 1; } 80% { opacity: 1; } 100% { left: 0%; opacity: 0; } }
    </style>
</head>
<body>

<nav class="navbar bg-sidebar d-lg-none border-bottom border-secondary px-3 py-3 sticky-top">
    <div class="d-flex justify-content-between w-100 align-items-center">
        <h5 class="mb-0 fw-bold text-info"><i class="fa-solid fa-network-wired me-2"></i>BLOODCYB</h5>
        <button class="btn btn-outline-secondary border-0" type="button" data-bs-toggle="offcanvas" data-bs-target="#sidebarMobile"><i class="fa-solid fa-bars fs-4 text-white"></i></button>
    </div>
</nav>

<?php ob_start(); ?>
<div class="p-4 d-flex flex-column h-100 bg-sidebar">
    <div class="text-center mb-5 d-none d-lg-block">
        <h4 class="fw-bold text-info mb-0"><i class="fa-solid fa-network-wired me-2"></i>BLOODCYB</h4>
        <div class="mt-2"><span class="badge bg-success bg-opacity-10 text-success border border-success px-2 py-1">Engine Online</span></div>
    </div>
    <ul class="nav flex-column nav-pills w-100 mb-auto" id="v-pills-tab" role="tablist">
        <li class="nav-item"><button class="nav-link active w-100 text-start" data-bs-toggle="pill" data-bs-target="#dashboard" type="button"><i class="fa-solid fa-route me-3 w-20px text-center"></i> داشبورد مسیریابی</button></li>
        <li class="nav-item"><button class="nav-link w-100 text-start" data-bs-toggle="pill" data-bs-target="#logs" type="button"><i class="fa-solid fa-eye me-3 w-20px text-center"></i> مانیتورینگ گرافیکی</button></li>
    </ul>
    <div class="mt-4"><a class="btn btn-outline-danger w-100 py-2" href="?logout=true"><i class="fa-solid fa-power-off me-2"></i> خروج</a></div>
</div>
<?php $sidebarContent = ob_get_clean(); ?>

<div class="sidebar-wrapper d-none d-lg-block"><?= $sidebarContent ?></div>
<div class="offcanvas offcanvas-end bg-sidebar" tabindex="-1" id="sidebarMobile">
    <div class="offcanvas-header border-bottom border-secondary">
        <h5 class="offcanvas-title fw-bold text-info"><i class="fa-solid fa-network-wired me-2"></i>BLOODCYB</h5>
        <button type="button" class="btn-close btn-close-white" data-bs-dismiss="offcanvas"></button>
    </div>
    <div class="offcanvas-body p-0"><?= $sidebarContent ?></div>
</div>

<div class="main-wrapper">
    <div class="p-4 p-md-5 tab-content flex-grow-1">
        
        <div class="tab-pane fade show active" id="dashboard">
            <div class="mb-4 d-none d-lg-block"><h4 class="fw-bold text-white"><i class="fa-solid fa-border-all text-primary me-2"></i> مرکز فرماندهی شبکه</h4></div>
            <?= $message ?>
            <div class="row g-4 mb-4">
                <div class="col-xl-7">
                    <div class="card-custom h-100">
                        <div class="card-header-custom text-info fw-bold"><i class="fa-solid fa-plus me-2"></i> استقرار مسیر جدید</div>
                        <div class="card-body p-4">
                            <form method="POST">
                                <div class="mb-4">
                                    <label class="form-label text-muted small">نام دامنه (بدون www)</label>
                                    <div class="input-group">
                                        <span class="input-group-text bg-dark border-secondary"><i class="fa-solid fa-globe text-muted"></i></span>
                                        <input type="text" name="domain" class="form-control" placeholder="example.com" required>
                                    </div>
                                </div>
                                <div class="row g-3 mb-4">
                                    <div class="col-md-6"><label class="form-label text-danger small">آی‌پی نود ایران</label><input type="text" name="iran_ip" class="form-control" style="border-right: 2px solid #ef4444;" required></div>
                                    <div class="col-md-6"><label class="form-label text-primary small">آی‌پی نود بین‌الملل</label><input type="text" name="foreign_ip" class="form-control" style="border-right: 2px solid #3b82f6;" required></div>
                                </div>
                                <div class="d-flex justify-content-between align-items-center p-3 rounded-3 mb-4 bg-dark border border-secondary">
                                    <div class="text-white"><i class="fa-solid fa-shield-halved me-2 text-success"></i> صدور خودکار SSL</div>
                                    <div class="form-check form-switch m-0 fs-5"><input class="form-check-input bg-success border-success" type="checkbox" name="install_ssl" checked></div>
                                </div>
                                <button type="submit" name="add_domain" class="btn btn-primary w-100 py-2"><i class="fa-solid fa-rocket me-2"></i> راه‌اندازی کلاستر</button>
                            </form>
                        </div>
                    </div>
                </div>
                <div class="col-xl-5">
                    <div class="card-custom h-100">
                        <div class="card-header-custom text-warning fw-bold"><i class="fa-solid fa-radar me-2"></i> رادار شبکه</div>
                        <div class="card-body p-4">
                            <p class="text-muted small mb-4">بررسی وضعیت فایروال سرورهای مقصد (پورت ۸۰)</p>
                            <form method="POST" class="mb-4">
                                <div class="input-group">
                                    <input type="text" name="check_ip" class="form-control" placeholder="آی‌پی سرور..." required value="<?= $_POST['check_ip'] ?? '' ?>">
                                    <button type="submit" name="do_check" class="btn btn-secondary px-4"><i class="fa-solid fa-magnifying-glass"></i></button>
                                </div>
                            </form>
                            <?php if (isset($_POST['do_check'])): ?>
                                <div class="p-4 bg-dark rounded border border-secondary text-center"><div class="text-muted small mb-2">ارتباط پورت ۸۰:</div><div class="fs-5"><?= checkServer(trim($_POST['check_ip'])) ?></div></div>
                            <?php endif; ?>
                        </div>
                    </div>
                </div>
            </div>
            
            <div class="card-custom">
                <div class="card-header-custom text-success fw-bold"><i class="fa-solid fa-server me-2"></i> کلاسترهای در حال اجرا</div>
                <div class="card-body p-0">
                    <div class="table-responsive">
                        <table class="table table-dark table-hover mb-0 align-middle">
                            <thead><tr><th class="ps-4 py-3 text-muted fw-normal">دامنه</th><th class="py-3 text-muted fw-normal">وضعیت</th><th class="text-end pe-4 py-3 text-muted fw-normal">عملیات</th></tr></thead>
                            <tbody>
                                <?php if(empty($domains_list)): ?><tr><td colspan="3" class="text-center py-4 text-muted">هیچ دامنه‌ای یافت نشد.</td></tr>
                                <?php else: foreach($domains_list as $dom): ?>
                                <tr>
                                    <td class="ps-4 py-3 fw-bold"><i class="fa-solid fa-globe text-primary opacity-50 me-2"></i> <?= $dom ?></td>
                                    <td class="py-3"><span class="badge bg-success bg-opacity-10 text-success border border-success"><i class="fa-solid fa-circle-play me-1"></i> در حال هدایت</span></td>
                                    <td class="text-end pe-4 py-3">
                                        <form method="POST" onsubmit="return confirm('حذف مسیر <?= $dom ?> و توقف ترافیک؟');" class="d-inline">
                                            <input type="hidden" name="delete_domain" value="<?= $dom ?>"><button type="submit" class="btn btn-sm btn-outline-danger"><i class="fa-solid fa-trash-can"></i></button>
                                        </form>
                                    </td>
                                </tr>
                                <?php endforeach; endif; ?>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="tab-pane fade <?= isset($_POST['view_logs']) ? 'show active' : '' ?>" id="logs">
            <div class="mb-4"><h4 class="fw-bold text-white"><i class="fa-solid fa-route text-info me-2"></i> مانیتورینگ مسیردهی زنده</h4><p class="text-muted small">ردیابی گرافیکی و لحظه‌ای درخواست‌ها (Live Visual Routing)</p></div>
            <div class="card-custom">
                <div class="card-body p-4">
                    <form method="POST" class="row g-3 align-items-end mb-4 pb-4 border-bottom border-secondary">
                        <div class="col-md-8 col-lg-6">
                            <label class="form-label text-muted small">انتخاب کلاستر</label>
                            <select name="log_domain" class="form-select" required>
                                <option value="">دامنه‌ای را انتخاب کنید...</option>
                                <?php foreach($domains_list as $dom): ?><option value="<?= $dom ?>" <?= (isset($_POST['log_domain']) && $_POST['log_domain'] == $dom) ? 'selected' : '' ?>><?= $dom ?></option><?php endforeach; ?>
                            </select>
                        </div>
                        <div class="col-md-4 col-lg-3"><button type="submit" name="view_logs" class="btn btn-info w-100 py-2 fw-bold text-dark"><i class="fa-solid fa-radar me-2"></i> اسکن ترافیک</button></div>
                    </form>
                    
                    <div class="log-container mt-4">
                    <?php
                    if (isset($_POST['view_logs']) && !empty($_POST['log_domain'])) {
                        $safe_log_name = str_replace('.', '_', $_POST['log_domain']);
                        $log_file = "/var/log/nginx/{$safe_log_name}_access.log";
                        
                        if (file_exists($log_file)) {
                            // دریافت 10 خط آخر
                            $log_output = shell_exec("sudo tail -n 10 " . escapeshellarg($log_file) . " 2>&1");
                            if (empty(trim($log_output))) {
                                echo "<div class='text-center p-5 text-muted'><i class='fa-solid fa-satellite-dish fs-1 mb-3 opacity-50'></i><br>سیستم آماده است. منتظر دریافت ترافیک جدید...</div>";
                            } else {
                                $lines = array_reverse(explode("\n", trim($log_output))); // جدیدترین بالا باشد
                                foreach($lines as $line) {
                                    $data = json_decode($line, true);
                                    if ($data) {
                                        // تحلیل داده‌های JSON
                                        $is_iran = ($data['country'] === 'IR');
                                        $node_name = $is_iran ? 'نود ایران' : 'نود بین‌الملل';
                                        $node_flag = $is_iran ? '🇮🇷' : '🌍';
                                        $node_color = $is_iran ? 'danger' : 'primary';
                                        
                                        $status = (int)$data['status'];
                                        $s_color = $status >= 500 ? 'danger' : ($status >= 400 ? 'warning' : 'success');
                                        $s_icon = $status >= 500 ? 'fa-xmark' : ($status >= 400 ? 'fa-triangle-exclamation' : 'fa-check');
                                        
                                        $req = htmlspecialchars($data['req']);
                                        $ip = htmlspecialchars($data['ip']);
                                        $time = date('H:i:s', strtotime($data['time']));
                                        
                                        // چاپ ردیف گرافیکی
                                        echo "
                                        <div class='d-flex flex-wrap align-items-center justify-content-between p-3 mb-3 bg-dark rounded-4 border border-secondary position-relative overflow-hidden'>
                                            <div class='d-flex align-items-center mb-3 mb-md-0' style='min-width: 200px; z-index: 2;'>
                                                <div class='bg-secondary bg-opacity-25 p-3 rounded-circle text-light me-3'><i class='fa-solid fa-user-astronaut'></i></div>
                                                <div>
                                                    <div class='fw-bold font-monospace text-info'>$ip</div>
                                                    <div class='text-muted small'><i class='fa-regular fa-clock me-1'></i> $time</div>
                                                </div>
                                            </div>
                                            
                                            <div class='text-center px-2 px-md-4 mb-3 mb-md-0 flex-grow-1 d-none d-md-block' style='z-index: 2;'>
                                                <div class='small text-light font-monospace mb-2 bg-black rounded px-2 py-1 d-inline-block border border-secondary' style='max-width: 250px; text-overflow: ellipsis; overflow: hidden; white-space: nowrap;' title='$req'>$req</div>
                                                <div class='route-line rounded-pill'>
                                                    <div class='route-dot'></div>
                                                </div>
                                            </div>
                                            
                                            <div class='d-flex align-items-center justify-content-md-end' style='min-width: 200px; z-index: 2;'>
                                                <div class='text-end me-3'>
                                                    <div class='fw-bold text-light'>$node_name <span class='fs-5'>$node_flag</span></div>
                                                    <div class='small text-$s_color fw-bold'><i class='fa-solid $s_icon me-1'></i> HTTP $status</div>
                                                </div>
                                                <div class='bg-$node_color bg-opacity-10 border border-$node_color p-3 rounded-circle text-$node_color text-center' style='width: 55px; height: 55px;'>
                                                    <i class='fa-solid fa-server fs-5'></i>
                                                </div>
                                            </div>
                                        </div>";
                                    } else {
                                        // لاگ‌های قدیمی متنی
                                        echo "<div class='text-muted small font-monospace p-2 border-bottom border-secondary mb-2'>".htmlspecialchars($line)."</div>";
                                    }
                                }
                            }
                        } else {
                            echo "<div class='alert alert-warning rounded-3'><i class='fa-solid fa-triangle-exclamation me-2'></i> فایل لاگ یافت نشد. برای مشاهده لاگ‌های گرافیکی، لطفاً دامنه مورد نظر را یکبار از داشبورد حذف کرده و مجدداً بسازید تا ساختار جدید JSON روی آن اعمال شود.</div>";
                        }
                    }
                    ?>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
<?php if (isset($_POST['view_logs'])): ?>
<script>document.addEventListener("DOMContentLoaded", function() { var triggerEl = document.querySelector('button[data-bs-target="#logs"]'); bootstrap.Tab.getInstance(triggerEl).show(); });</script>
<?php endif; ?>
</body></html>
EOF

    sed -i "s|INSERT_HASH_HERE|$PANEL_PASS_HASH|g" /var/www/bloodcyb/index.php

    echo -e "${BLUE}[*] Configuring Internal Web Server...${RESET}"
    cat <<'EOF' > /etc/nginx/sites-available/bloodcyb-panel.conf
server {
    listen 8888;
    server_name _;
    root /var/www/bloodcyb;
    index index.php;
    location / { try_files $uri $uri/ =404; }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }
}
EOF

    PHP_SOCK=$(find /var/run/php/ -name "*.sock" | head -n 1)
    if [ ! -z "$PHP_SOCK" ]; then
        sed -i "s|unix:/var/run/php/php-fpm.sock;|unix:$PHP_SOCK;|g" /etc/nginx/sites-available/bloodcyb-panel.conf
    fi

    ln -sf /etc/nginx/sites-available/bloodcyb-panel.conf /etc/nginx/sites-enabled/

    echo -e "${BLUE}[*] Setting secure execution permissions...${RESET}"
    cat <<'EOF' > /etc/sudoers.d/bloodcyb-panel
www-data ALL=(root) NOPASSWD: /usr/sbin/nginx, /usr/bin/certbot, /bin/systemctl reload nginx, /bin/mv /tmp/*.conf /etc/nginx/sites-available/, /bin/ln -sf /etc/nginx/sites-available/* /etc/nginx/sites-enabled/, /bin/rm -f /etc/nginx/sites-available/*.conf, /bin/rm -f /etc/nginx/sites-enabled/*.conf, /bin/rm -f /var/log/nginx/*_access.log, /usr/bin/tail
EOF
    chmod 0440 /etc/sudoers.d/bloodcyb-panel

    systemctl restart nginx
    systemctl restart php*-fpm

    SERVER_IP=$(curl -s ifconfig.me)

    echo -e "${GREEN}=================================================================${RESET}"
    echo -e "${GREEN} [SUCCESS] Bloodcyb Visual Engine deployed successfully!${RESET}"
    echo -e "${GREEN} -> Admin Console : http://${SERVER_IP}:8888${RESET}"
    echo -e "${GREEN}=================================================================${RESET}"
}

if [ -f "/var/www/bloodcyb/index.php" ]; then
    echo -e "${GREEN}[✔] System detected: Bloodcyb is already installed.${RESET}"
    echo ""
    echo "What would you like to do?"
    echo "  1) Update / Repair Panel (Applies new Visual Logs update)"
    echo "  2) Uninstall Completely"
    echo "  3) Exit"
    echo ""
    read -p "Select an option (1-3): " MENU_CHOICE

    case $MENU_CHOICE in
        1) install_system ;;
        2) uninstall_system ;;
        3) exit 0 ;;
        *) echo -e "${RED}Invalid option.${RESET}"; exit 1 ;;
    esac
else
    install_system
fi
