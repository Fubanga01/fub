#!/bin/bash
# ================================================================
# SECURITY.SH — Proteções Base x-ui
# Ubuntu 22.04 | Porta 54321
# Camadas: 01-25
# ================================================================

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ── Cores ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

# ── Variáveis fixas ──
XUI_PORT=54321
VERSION="4.0.0"
INSTALL_DATE=$(date '+%d/%m/%Y %H:%M:%S')
FORTRESS_DIR="/etc/fortress"
LOG_DIR="/var/log/fortress"
BACKUP_DIR="/root/fortress-backups"
MAIN_LOG="$LOG_DIR/fortress.log"

# ── Funções base ──
check_root() {
    [[ $EUID -ne 0 ]] && {
        echo -e "${RED}Execute como root: sudo bash security.sh${NC}"
        exit 1
    }
}

step() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BOLD}${WHITE}[$1/25] $2${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

ok()   { echo -e "  ${GREEN}✅${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠️${NC}  $1"; }
err()  { echo -e "  ${RED}❌${NC} $1"; }
info() { echo -e "  ${CYAN}ℹ️${NC}  $1"; }

log_f() {
    mkdir -p "$LOG_DIR"
    echo "[$(date '+%d/%m/%Y %H:%M:%S')][$1] $2" >> "$MAIN_LOG"
}

tg_send() {
    [[ -z "${TG_TOKEN:-}" || -z "${TG_CHAT_ID:-}" ]] && return 0
    curl -s -X POST \
        "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d "chat_id=$TG_CHAT_ID" \
        -d "text=$1" \
        -d "parse_mode=Markdown" > /dev/null 2>&1 || true
}

get_main_iface() {
    ip route show default | awk '/default/ {print $5}' | head -1
}

get_server_ip() {
    curl -s4 --connect-timeout 5 ifconfig.me 2>/dev/null || \
    curl -s4 --connect-timeout 5 ip.sb 2>/dev/null || \
    hostname -I | awk '{print $1}'
}

# ══════════════════════════════════════════════════════
# BANNER
# ══════════════════════════════════════════════════════

banner() {
    clear
    echo -e "${RED}"
    cat << 'EOF'
 ██████╗ ███████╗ ██████╗██╗   ██╗██████╗ ██╗████████╗██╗   ██╗
 ███████╗█████╗  ██╔════╝██║   ██║██╔══██╗██║╚══██╔══╝╚██╗ ██╔╝
 ╚════██║██╔══╝  ██║     ██║   ██║██████╔╝██║   ██║    ╚████╔╝
      ██║███████╗╚██████╗╚██████╔╝██║  ██║██║   ██║     ╚██╔╝
      ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝   ╚═╝      ╚═╝
EOF
    echo -e "${NC}"
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}🛡️  SECURITY.SH — Proteções Base | Ubuntu 22.04${NC}          ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}   x-ui porta 54321 | Camadas 01-25${NC}                      ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ══════════════════════════════════════════════════════
# COLETA DE INFORMAÇÕES
# ══════════════════════════════════════════════════════

collect_info() {
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║              📋  CONFIGURAÇÃO INICIAL                        ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${GREEN}x-ui porta: $XUI_PORT (pré-configurado)${NC}"
    echo ""

    read -p "  Nova porta SSH [padrão: 2222]: " SSH_PORT
    SSH_PORT=${SSH_PORT:-2222}

    read -p "  Domínio do painel (Enter = sem domínio): " PANEL_DOMAIN
    PANEL_DOMAIN=${PANEL_DOMAIN:-""}

    read -p "  Email para alertas (Enter = pular): " ADMIN_EMAIL
    ADMIN_EMAIL=${ADMIN_EMAIL:-""}

    CURRENT_IP=$(echo $SSH_CLIENT | awk '{print $1}')
    echo -e "  ${CYAN}Seu IP atual: $CURRENT_IP${NC}"
    read -p "  IP admin para whitelist [Enter = $CURRENT_IP]: " ADMIN_IP
    ADMIN_IP=${ADMIN_IP:-$CURRENT_IP}

    echo ""
    read -p "  Token Bot Telegram (Enter = pular): " TG_TOKEN
    TG_TOKEN=${TG_TOKEN:-""}
    if [[ -n "$TG_TOKEN" ]]; then
        read -p "  Chat ID Telegram: " TG_CHAT_ID
        TG_CHAT_ID=${TG_CHAT_ID:-""}
    else
        TG_CHAT_ID=""
    fi

    echo ""
    echo -e "  ${CYAN}Países para bloquear (ex: CN,RU,KP ou Enter = nenhum):${NC}"
    read -p "  Países: " BLOCKED_COUNTRIES
    BLOCKED_COUNTRIES=${BLOCKED_COUNTRIES:-""}

    SERVER_IP=$(get_server_ip)
    MAIN_IFACE=$(get_main_iface)

    mkdir -p "$FORTRESS_DIR" "$LOG_DIR" "$BACKUP_DIR"
    chmod 700 "$FORTRESS_DIR" "$LOG_DIR" "$BACKUP_DIR"

    cat > "$FORTRESS_DIR/config.env" << ENVEOF
XUI_PORT=$XUI_PORT
SSH_PORT=$SSH_PORT
PANEL_DOMAIN=$PANEL_DOMAIN
ADMIN_EMAIL=$ADMIN_EMAIL
ADMIN_IP=$ADMIN_IP
TG_TOKEN=$TG_TOKEN
TG_CHAT_ID=$TG_CHAT_ID
BLOCKED_COUNTRIES=$BLOCKED_COUNTRIES
SERVER_IP=$SERVER_IP
MAIN_IFACE=$MAIN_IFACE
INSTALL_DATE=$INSTALL_DATE
VERSION=$VERSION
ENVEOF
    chmod 600 "$FORTRESS_DIR/config.env"

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  SSH:        ${YELLOW}$SSH_PORT${NC}"
    echo -e "  x-ui:       ${YELLOW}$XUI_PORT${NC}"
    echo -e "  Domínio:    ${YELLOW}${PANEL_DOMAIN:-Nenhum}${NC}"
    echo -e "  IP Admin:   ${YELLOW}$ADMIN_IP${NC}"
    echo -e "  Telegram:   ${YELLOW}${TG_TOKEN:+Sim}${TG_TOKEN:-Não}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    read -p "  Confirmar? [S/n]: " CONFIRM
    [[ "${CONFIRM,,}" == "n" ]] && exit 0
}

# ══════════════════════════════════════════════════════
# [01] ATUALIZAÇÃO
# ══════════════════════════════════════════════════════

step_01() {
    step "01" "🔄 Atualização do Sistema"

    apt-get update -y -q
    apt-get upgrade -y -q
    apt-get install -y -q \
        curl wget git unzip tar socat jq bc \
        net-tools htop vnstat sysstat lsof psmisc \
        tcpdump whois dnsutils \
        openssl gnupg2 ca-certificates \
        python3 python3-pip \
        fail2ban ufw \
        iptables iptables-persistent netfilter-persistent ipset \
        auditd aide \
        rkhunter chkrootkit \
        unattended-upgrades apt-listchanges \
        nginx certbot python3-certbot-nginx \
        openssh-server \
        inotify-tools \
        2>/dev/null

    apt-get autoremove -y -q
    apt-get autoclean -y -q

    ok "Sistema atualizado"
    log_f "OK" "Sistema atualizado"
}

# ══════════════════════════════════════════════════════
# [02] SSH SEGURO
# ══════════════════════════════════════════════════════

step_02() {
    step "02" "🔐 SSH Seguro"

    cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%s)"

    [[ ! -f /etc/ssh/ssh_host_ed25519_key ]] && \
        ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key \
        -N "" > /dev/null 2>&1

    cat > /etc/ssh/sshd_config << SSHEOF
Port $SSH_PORT
AddressFamily inet
ListenAddress 0.0.0.0
Protocol 2

HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key

KexAlgorithms curve25519-sha256@libssh.org,curve25519-sha256,diffie-hellman-group16-sha512
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

LoginGraceTime 20
PermitRootLogin yes
StrictModes yes
MaxAuthTries 3
MaxSessions 3

PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

AllowTcpForwarding no
X11Forwarding no
AllowAgentForwarding no
PermitTunnel no
PrintMotd no
PrintLastLog yes
TCPKeepAlive yes
ClientAliveInterval 180
ClientAliveCountMax 2
UseDNS no
MaxStartups 3:50:10

SyslogFacility AUTH
LogLevel VERBOSE

Banner /etc/ssh/fortress_banner
SSHEOF

    cat > /etc/ssh/fortress_banner << 'BANNER'

 ╔══════════════════════════════════════════════════════╗
 ║   ⚠️  ACESSO RESTRITO E MONITORADO  ⚠️               ║
 ║   Acesso não autorizado é crime (Lei 12.737/2012)   ║
 ╚══════════════════════════════════════════════════════╝

BANNER

    rm -f /etc/ssh/ssh_host_dsa_key* \
          /etc/ssh/ssh_host_ecdsa_key* 2>/dev/null

    sshd -t 2>/dev/null && systemctl restart sshd
    ok "SSH na porta $SSH_PORT"
    warn "Senha ativa — desabilite após adicionar chave SSH"
    log_f "OK" "SSH porta $SSH_PORT"
}

# ══════════════════════════════════════════════════════
# [03] UFW
# ══════════════════════════════════════════════════════

step_03() {
    step "03" "🔥 Firewall UFW"

    ufw --force reset > /dev/null 2>&1
    ufw --force disable > /dev/null 2>&1

    ufw default deny incoming
    ufw default allow outgoing
    ufw default deny forward

    [[ -n "$ADMIN_IP" ]] && ufw allow from "$ADMIN_IP" comment "Admin"

    ufw limit "$SSH_PORT"/tcp comment "SSH"
    ufw allow 80/tcp comment "HTTP"
    ufw allow 443/tcp comment "HTTPS"
    ufw limit "$XUI_PORT"/tcp comment "x-ui"

    for P in 21 23 25 135 137 138 139 445 1433 3306 3389 5432 5900 6379 27017; do
        ufw deny "$P" comment "Bloqueada" > /dev/null 2>&1
    done

    ufw --force enable > /dev/null 2>&1
    ok "UFW ativo"
    log_f "OK" "UFW configurado"
}

# ══════════════════════════════════════════════════════
# [04] IPTABLES
# ══════════════════════════════════════════════════════

step_04() {
    step "04" "🛡️ IPTables Multi-Camada"

    [[ -n "$ADMIN_IP" ]] && \
        iptables -I INPUT 1 -s "$ADMIN_IP" -j ACCEPT

    iptables -A INPUT -m conntrack \
        --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
    iptables -A INPUT -p tcp ! --syn \
        -m conntrack --ctstate NEW -j DROP

    # Anti-Spoofing
    for BOGON in "0.0.0.0/8" "127.0.0.0/8" \
                 "169.254.0.0/16" "224.0.0.0/4" "240.0.0.0/4"; do
        iptables -A INPUT -s "$BOGON" ! -i lo -j DROP 2>/dev/null
    done

    # SYN Flood
    iptables -N SYN_FLOOD 2>/dev/null || iptables -F SYN_FLOOD
    iptables -A SYN_FLOOD -p tcp --syn -m limit \
        --limit 30/s --limit-burst 60 -j RETURN
    iptables -A SYN_FLOOD -j DROP
    iptables -A INPUT -p tcp --syn -j SYN_FLOOD
    echo 1 > /proc/sys/net/ipv4/tcp_syncookies

    # ICMP
    iptables -A INPUT -p icmp --icmp-type echo-request \
        -m limit --limit 2/s --limit-burst 5 -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
    iptables -A INPUT -p icmp -j ACCEPT

    # Port Scan
    iptables -N PORT_SCAN 2>/dev/null || iptables -F PORT_SCAN
    iptables -A PORT_SCAN -p tcp --tcp-flags ALL NONE \
        -j LOG --log-prefix "NULL_SCAN: "
    iptables -A PORT_SCAN -p tcp --tcp-flags ALL NONE -j DROP
    iptables -A PORT_SCAN -p tcp --tcp-flags ALL ALL \
        -j LOG --log-prefix "XMAS_SCAN: "
    iptables -A PORT_SCAN -p tcp --tcp-flags ALL ALL -j DROP
    iptables -A PORT_SCAN -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
    iptables -A PORT_SCAN -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
    iptables -A PORT_SCAN -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP
    iptables -A INPUT -j PORT_SCAN

    # DDoS
    iptables -N DDOS 2>/dev/null || iptables -F DDOS
    iptables -A DDOS -m connlimit \
        --connlimit-above 80 --connlimit-mask 32 -j DROP
    iptables -A DDOS -p tcp --syn -m recent \
        --name DDOS --set
    iptables -A DDOS -p tcp --syn -m recent \
        --name DDOS --rcheck --seconds 1 --hitcount 20 -j DROP
    iptables -A INPUT -j DDOS

    # SSH Brute
    iptables -N SSH_BF 2>/dev/null || iptables -F SSH_BF
    iptables -A SSH_BF -m recent \
        --name SSH --set --rsource
    iptables -A SSH_BF -m recent \
        --name SSH --rcheck --seconds 60 --hitcount 4 \
        -j LOG --log-prefix "SSH_BRUTE: "
    iptables -A SSH_BF -m recent \
        --name SSH --rcheck --seconds 60 --hitcount 4 -j DROP
    iptables -A SSH_BF -j ACCEPT
    iptables -A INPUT -p tcp --dport "$SSH_PORT" --syn -j SSH_BF

    # x-ui Brute
    iptables -N XUI_BF 2>/dev/null || iptables -F XUI_BF
    iptables -A XUI_BF -m connlimit \
        --connlimit-above 30 --connlimit-mask 32 -j DROP
    iptables -A XUI_BF -m recent \
        --name XUI --set --rsource
    iptables -A XUI_BF -m recent \
        --name XUI --rcheck --seconds 60 --hitcount 10 \
        -j LOG --log-prefix "XUI_BRUTE: "
    iptables -A XUI_BF -m recent \
        --name XUI --rcheck --seconds 60 --hitcount 10 -j DROP
    iptables -A XUI_BF -j ACCEPT
    iptables -A INPUT -p tcp --dport "$XUI_PORT" -j XUI_BF

    # Portas abertas
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT

    # Log final
    iptables -A INPUT -m limit --limit 3/min \
        -j LOG --log-prefix "DROPPED: " --log-level 4

    netfilter-persistent save > /dev/null 2>&1

    ok "IPTables: anti-scan, anti-flood, anti-spoof, anti-DDoS"
    log_f "OK" "IPTables configurado"
}

# ══════════════════════════════════════════════════════
# [05] IPSET + BLOCKLISTS
# ══════════════════════════════════════════════════════

step_05() {
    step "05" "🌐 IPSet + Blocklists"

    ipset create BLOCKED hash:ip maxelem 2000000 \
        timeout 86400 2>/dev/null || ipset flush BLOCKED
    ipset create TOR_EXIT hash:ip maxelem 200000 \
        timeout 3600 2>/dev/null || ipset flush TOR_EXIT

    info "Baixando lista TOR..."
    curl -s --connect-timeout 10 \
        "https://check.torproject.org/torbulkexitlist" 2>/dev/null | \
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | \
    while IFS= read -r ip; do
        ipset add TOR_EXIT "$ip" 2>/dev/null || true
    done
    ok "TOR bloqueado"

    info "Baixando blocklist.de..."
    curl -s --connect-timeout 10 \
        "https://lists.blocklist.de/lists/all.txt" 2>/dev/null | \
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | \
    head -50000 | \
    while IFS= read -r ip; do
        ipset add BLOCKED "$ip" 2>/dev/null || true
    done
    ok "Blocklist.de carregada"

    iptables -I INPUT 2 -m set \
        --match-set BLOCKED src -j DROP 2>/dev/null
    iptables -I INPUT 3 -m set \
        --match-set TOR_EXIT src -j DROP 2>/dev/null

    mkdir -p /etc/ipset
    ipset save > /etc/ipset/fortress.rules

    cat > /etc/cron.daily/fortress-blocklist << 'CRONBL'
#!/bin/bash
ipset flush TOR_EXIT 2>/dev/null
curl -s "https://check.torproject.org/torbulkexitlist" | \
grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | \
while read ip; do ipset add TOR_EXIT "$ip" 2>/dev/null; done
curl -s "https://lists.blocklist.de/lists/all.txt" | \
grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -50000 | \
while read ip; do ipset add BLOCKED "$ip" 2>/dev/null; done
ipset save > /etc/ipset/fortress.rules
CRONBL
    chmod +x /etc/cron.daily/fortress-blocklist

    ok "IPSet com auto-atualização diária"
    log_f "OK" "IPSet configurado"
}

# ══════════════════════════════════════════════════════
# [06] FAIL2BAN
# ══════════════════════════════════════════════════════

step_06() {
    step "06" "🔨 Fail2Ban"

    cat > /etc/fail2ban/jail.local << F2BEOF
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1 ${ADMIN_IP}
bantime  = 86400
findtime = 300
maxretry = 3
backend  = systemd
banaction = iptables-multiport
action   = %(action_)s

[sshd]
enabled  = true
port     = $SSH_PORT
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 2
bantime  = 604800

[sshd-ddos]
enabled  = true
port     = $SSH_PORT
filter   = sshd-ddos
logpath  = /var/log/auth.log
maxretry = 6
bantime  = 604800

[xui-login]
enabled  = true
port     = $XUI_PORT,80,443
filter   = xui-login
logpath  = /var/log/nginx/access.log
maxretry = 5
bantime  = 86400
findtime = 120

[xui-scanner]
enabled  = true
port     = $XUI_PORT,80,443
filter   = xui-scanner
logpath  = /var/log/nginx/access.log
maxretry = 2
bantime  = 604800

[nginx-http-auth]
enabled  = true
port     = http,https
filter   = nginx-http-auth
logpath  = /var/log/nginx/error.log
maxretry = 3

[nginx-botsearch]
enabled  = true
port     = http,https
filter   = nginx-botsearch
logpath  = /var/log/nginx/access.log
maxretry = 1
bantime  = 604800

[nginx-badbots]
enabled  = true
port     = http,https
filter   = nginx-badbots
logpath  = /var/log/nginx/access.log
maxretry = 1
bantime  = 604800

[nginx-noscript]
enabled  = true
port     = http,https
filter   = nginx-noscript
logpath  = /var/log/nginx/access.log
maxretry = 3

[nginx-404]
enabled  = true
port     = http,https
filter   = nginx-404
logpath  = /var/log/nginx/access.log
maxretry = 20
bantime  = 3600
findtime = 60

[portscan]
enabled  = true
filter   = portscan
logpath  = /var/log/kern.log
maxretry = 1
bantime  = 604800

[recidive]
enabled  = true
filter   = recidive
logpath  = /var/log/fail2ban.log
maxretry = 3
bantime  = 2592000
findtime = 86400
F2BEOF

    cat > /etc/fail2ban/filter.d/xui-login.conf << 'EOF'
[Definition]
failregex = ^<HOST>.*"POST.*(login|xui/login).*" (401|403|429)
ignoreregex =
EOF

    cat > /etc/fail2ban/filter.d/xui-scanner.conf << 'EOF'
[Definition]
failregex = ^<HOST>.*"(GET|POST).*(\.php|\.asp|\.env|\.git|wp-login|phpMyAdmin|shell).*"
ignoreregex =
EOF

    cat > /etc/fail2ban/filter.d/portscan.conf << 'EOF'
[Definition]
failregex = .*PORT_SCAN.*SRC=<HOST>
            .*NULL_SCAN.*SRC=<HOST>
            .*XMAS_SCAN.*SRC=<HOST>
ignoreregex =
EOF

    cat > /etc/fail2ban/filter.d/nginx-badbots.conf << 'EOF'
[Definition]
failregex = ^<HOST>.*"(GET|POST).*".*(masscan|nikto|sqlmap|nmap|zgrab|nuclei|dirbuster|gobuster|burpsuite|acunetix).*"$
ignoreregex =
EOF

    cat > /etc/fail2ban/filter.d/nginx-noscript.conf << 'EOF'
[Definition]
failregex = ^<HOST> -.*GET.*(\.php|\.asp|\.exe|\.pl|\.cgi)
ignoreregex =
EOF

    cat > /etc/fail2ban/filter.d/nginx-404.conf << 'EOF'
[Definition]
failregex = ^<HOST> - .* "(GET|POST).*" 404
ignoreregex = \.(ico|png|jpg|css|js|woff)
EOF

    systemctl enable fail2ban
    systemctl restart fail2ban

    ok "Fail2Ban com 11+ jails ativo"
    log_f "OK" "Fail2Ban configurado"
}

# ══════════════════════════════════════════════════════
# [07] KERNEL HARDENING
# ══════════════════════════════════════════════════════

step_07() {
    step "07" "⚙️ Kernel Hardening"

    cat > /etc/sysctl.d/99-fortress.conf << 'EOF'
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.log_martians = 1
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.perf_event_paranoid = 3
kernel.yama.ptrace_scope = 2
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2
kernel.sysrq = 0
kernel.core_pattern = |/bin/false
fs.suid_dumpable = 0
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2
net.core.somaxconn = 65535
net.ipv4.ip_forward = 1
EOF

    sysctl -p /etc/sysctl.d/99-fortress.conf > /dev/null 2>&1

    cat > /etc/modprobe.d/fortress-blacklist.conf << 'EOF'
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
install cramfs /bin/true
install hfs /bin/true
install hfsplus /bin/true
install udf /bin/true
install bluetooth /bin/true
install usb-storage /bin/true
EOF

    ok "Kernel endurecido"
    log_f "OK" "Kernel hardening"
}

# ══════════════════════════════════════════════════════
# [08] NGINX WAF
# ══════════════════════════════════════════════════════

step_08() {
    step "08" "🌐 Nginx WAF + Proxy Reverso"

    mkdir -p /var/log/fortress /var/www/certbot

    cat > /etc/nginx/nginx.conf << 'NGXEOF'
user www-data;
worker_processes auto;
worker_rlimit_nofile 65535;
worker_rlimit_core 0;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 4096;
    multi_accept on;
    use epoll;
}

http {
    charset utf-8;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    server_tokens off;
    log_not_found off;
    types_hash_max_size 2048;
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    keepalive_timeout 30;
    client_body_timeout 10;
    client_header_timeout 10;
    send_timeout 10;
    reset_timedout_connection on;
    client_max_body_size 16m;
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;

    log_format fortress '$time_iso8601 | $remote_addr | $request_method | $host$request_uri | $status | "$http_user_agent"';
    access_log /var/log/nginx/access.log fortress;
    error_log /var/log/nginx/error.log warn;

    limit_conn_zone $binary_remote_addr zone=perip:10m;
    limit_req_zone $binary_remote_addr zone=global:10m rate=100r/m;
    limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
    limit_req_zone $binary_remote_addr zone=api:10m rate=60r/m;

    map $http_user_agent $bad_ua {
        default 0;
        "" 1;
        ~*masscan 1; ~*nikto 1; ~*sqlmap 1; ~*nmap 1;
        ~*zgrab 1; ~*nuclei 1; ~*dirbuster 1; ~*gobuster 1;
        ~*burpsuite 1; ~*acunetix 1; ~*python-requests/2 1;
        ~*Go-http-client 1; ~*libwww-perl 1; ~*HTTrack 1;
    }

    map $request_uri $bad_uri {
        default 0;
        ~*(<script|javascript:|onload=|onerror=) 1;
        ~*(union.*select|insert.*into|drop.*table) 1;
        ~*(\.\./|%2e%2e) 1;
        ~*(etc/passwd|etc/shadow|proc/self) 1;
    }

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
NGXEOF

    ok "Nginx WAF configurado"
    log_f "OK" "Nginx WAF"
}

# ══════════════════════════════════════════════════════
# [09] SSL
# ══════════════════════════════════════════════════════

step_09() {
    step "09" "🔒 SSL/TLS"

    mkdir -p /etc/ssl/fortress

    if [[ -n "$PANEL_DOMAIN" && -n "$ADMIN_EMAIL" ]]; then
        systemctl stop nginx 2>/dev/null
        certbot certonly --standalone \
            -d "$PANEL_DOMAIN" \
            --email "$ADMIN_EMAIL" \
            --agree-tos --non-interactive 2>/dev/null

        if [[ $? -eq 0 ]]; then
            ln -sf "/etc/letsencrypt/live/$PANEL_DOMAIN/fullchain.pem" \
                /etc/ssl/fortress/fullchain.pem
            ln -sf "/etc/letsencrypt/live/$PANEL_DOMAIN/privkey.pem" \
                /etc/ssl/fortress/privkey.pem
            ok "Let's Encrypt: $PANEL_DOMAIN"
        else
            warn "Let's Encrypt falhou, usando autoassinado"
            openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
                -keyout /etc/ssl/fortress/privkey.pem \
                -out /etc/ssl/fortress/fullchain.pem \
                -subj "/C=BR/O=Fortress/CN=${PANEL_DOMAIN}" 2>/dev/null
        fi
    else
        openssl req -x509 -nodes -days 3650 -newkey rsa:4096 \
            -keyout /etc/ssl/fortress/privkey.pem \
            -out /etc/ssl/fortress/fullchain.pem \
            -subj "/C=BR/O=Fortress/CN=localhost" 2>/dev/null
        ok "Certificado autoassinado gerado"
    fi

    chmod 600 /etc/ssl/fortress/*.pem

    ok "SSL configurado"
    log_f "OK" "SSL"
}

# ══════════════════════════════════════════════════════
# [10] CROWDSEC
# ══════════════════════════════════════════════════════

step_10() {
    step "10" "🤖 CrowdSec IPS"

    curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh \
        | bash > /dev/null 2>&1
    apt-get install -y crowdsec \
        crowdsec-firewall-bouncer-iptables 2>/dev/null

    if command -v cscli > /dev/null 2>&1; then
        cscli collections install \
            crowdsecurity/nginx \
            crowdsecurity/ssh-bf \
            crowdsecurity/linux 2>/dev/null
        systemctl enable crowdsec \
            crowdsec-firewall-bouncer 2>/dev/null
        systemctl restart crowdsec \
            crowdsec-firewall-bouncer 2>/dev/null
        ok "CrowdSec ativo"
    else
        warn "CrowdSec não instalou (não crítico)"
    fi

    log_f "OK" "CrowdSec"
}

# ══════════════════════════════════════════════════════
# [11] ROOTKITS
# ══════════════════════════════════════════════════════

step_11() {
    step "11" "🔍 Detecção de Rootkits"

    rkhunter --update --nocolors > /dev/null 2>&1
    rkhunter --propupd --nocolors > /dev/null 2>&1

    cat > /etc/cron.daily/fortress-rkhunter << 'EOF'
#!/bin/bash
/usr/bin/rkhunter --check --nocolors --skip-keypress \
    --report-warnings-only 2>&1 | logger -t rkhunter
EOF
    chmod +x /etc/cron.daily/fortress-rkhunter

    ok "RKHunter + ChkRootkit configurados"
    log_f "OK" "Rootkits"
}

# ══════════════════════════════════════════════════════
# [12] AUDITD
# ══════════════════════════════════════════════════════

step_12() {
    step "12" "📋 Auditoria"

    cat > /etc/audit/rules.d/fortress.rules << 'EOF'
-D
-b 8192
-f 2
-w /var/log/lastlog -p rwa -k logins
-w /var/run/utmp -p rwa -k session
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k privilege
-w /etc/ssh/sshd_config -p wa -k sshd
-w /root/.ssh -p rwa -k ssh_access
-w /usr/local/x-ui -p wa -k xui
-w /etc/fortress -p wa -k fortress
-w /etc/cron.d -p wa -k cron
-a always,exit -F arch=b64 -S execve -F euid=0 -k root_cmds
-w /tmp -p wxa -k tmp
-w /dev/shm -p wxa -k shm
-e 2
EOF

    systemctl restart auditd 2>/dev/null
    ok "Auditd configurado"
    log_f "OK" "Auditd"
}

# ══════════════════════════════════════════════════════
# [13] HONEYPOT + GEOIP + ANTIDDOS
# ══════════════════════════════════════════════════════

step_13() {
    step "13-15" "🍯 Honeypot + 🌍 GeoIP + 💥 Anti-DDoS"

    for HP in 22 23 3389 5900 1433 3306 6379 4444; do
        [[ "$HP" != "$SSH_PORT" ]] && \
            iptables -A INPUT -p tcp --dport "$HP" \
            -j LOG --log-prefix "HONEYPOT_${HP}: " 2>/dev/null
    done
    ok "Honeypot ativo"

    if [[ -n "$BLOCKED_COUNTRIES" ]]; then
        IFS=',' read -ra CCS <<< "$BLOCKED_COUNTRIES"
        for CC in "${CCS[@]}"; do
            CC=$(echo "$CC" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
            ipset create "GEO_${CC^^}" hash:net maxelem 500000 \
                2>/dev/null || ipset flush "GEO_${CC^^}"
            curl -s "https://www.ipdeny.com/ipblocks/data/countries/${CC}.zone" \
                2>/dev/null | \
            while IFS= read -r NET; do
                [[ -n "$NET" ]] && \
                    ipset add "GEO_${CC^^}" "$NET" 2>/dev/null
            done
            iptables -I INPUT -m set \
                --match-set "GEO_${CC^^}" src -j DROP 2>/dev/null
            ok "País bloqueado: ${CC^^}"
        done
    fi

    cat > /usr/local/bin/fortress-ddos << 'DDOS'
#!/bin/bash
source /etc/fortress/config.env 2>/dev/null
while true; do
    ss -tn state established 2>/dev/null | \
    awk 'NR>1{print $5}' | \
    grep -oP '[\d.]+(?=:\d+$)' | \
    sort | uniq -c | sort -rn | \
    while read COUNT IP; do
        if [[ $COUNT -ge 80 && -n "$IP" ]]; then
            iptables -I INPUT -s "$IP" -j DROP 2>/dev/null
            echo "[$(date)] DDoS ban: $IP ($COUNT)" \
                >> /var/log/fortress/ddos.log
        fi
    done
    sleep 30
done
DDOS
    chmod +x /usr/local/bin/fortress-ddos

    cat > /etc/systemd/system/fortress-ddos.service << 'EOF'
[Unit]
Description=Fortress DDoS Protection
After=network.target
[Service]
Type=simple
ExecStart=/usr/local/bin/fortress-ddos
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now fortress-ddos 2>/dev/null

    ok "Anti-DDoS ativo"
    log_f "OK" "Honeypot + GeoIP + DDoS"
}

# ══════════════════════════════════════════════════════
# [16] MONITOR 24/7
# ══════════════════════════════════════════════════════

step_16() {
    step "16-17" "👁️ Monitor 24/7 + Telegram"

    cat > /usr/local/bin/fortress-monitor << 'MONITOR'
#!/bin/bash
source /etc/fortress/config.env 2>/dev/null
LOG="/var/log/fortress/monitor.log"
BANNED="/etc/fortress/banned_ips.txt"
touch "$BANNED"

tg() {
    [[ -z "${TG_TOKEN:-}" || -z "${TG_CHAT_ID:-}" ]] && return
    curl -s -X POST \
        "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d "chat_id=$TG_CHAT_ID" \
        -d "text=$1" \
        -d "parse_mode=Markdown" > /dev/null 2>&1
}

ban_ip() {
    local IP="$1" REASON="$2"
    grep -q "^$IP$" "$BANNED" 2>/dev/null && return
    echo "$IP" >> "$BANNED"
    iptables -I INPUT 1 -s "$IP" -j DROP 2>/dev/null
    ipset add BLOCKED "$IP" 2>/dev/null
    tg "🚫 *IP BANIDO*%0AIP: \`$IP\`%0AMotivo: $REASON"
    echo "[$(date)] BAN $IP: $REASON" >> "$LOG"
}

check_services() {
    for SVC in x-ui nginx fail2ban; do
        if ! systemctl is-active "$SVC" > /dev/null 2>&1; then
            systemctl restart "$SVC" 2>/dev/null
            sleep 3
            systemctl is-active "$SVC" > /dev/null 2>&1 || \
                tg "🔴 *SERVIÇO CAÍDO*: $SVC"
        fi
    done
}

check_bruteforce() {
    grep "Failed password" /var/log/auth.log 2>/dev/null | \
    grep "$(date '+%b %d')" | awk '{print $(NF-3)}' | \
    sort | uniq -c | sort -rn | \
    while read C IP; do
        [[ $C -ge 5 && -n "$IP" ]] && \
            ban_ip "$IP" "SSH brute ($C tentativas)"
    done

    [[ -f /var/log/nginx/access.log ]] && \
    grep "$(date '+%d/%b/%Y:%H')" /var/log/nginx/access.log 2>/dev/null | \
    grep -E '"POST.*/login.*" (401|403|429)' | \
    awk '{print $1}' | sort | uniq -c | sort -rn | \
    while read C IP; do
        [[ $C -ge 5 && -n "$IP" ]] && \
            ban_ip "$IP" "x-ui brute ($C tentativas)"
    done
}

check_miners() {
    for M in xmrig minerd cpuminer cgminer bfgminer; do
        if pgrep -x "$M" > /dev/null 2>&1; then
            PID=$(pgrep -x "$M")
            pkill -9 "$M"
            tg "⛏️ *MINER ELIMINADO*: $M (PID: $PID)"
        fi
    done
}

check_resources() {
    CPU=$(top -bn1 2>/dev/null | grep "Cpu(s)" | \
        awk '{print $2}' | cut -d. -f1)
    MEM=$(free 2>/dev/null | grep Mem | \
        awk '{printf "%.0f", $3/$2*100}')
    [[ ${CPU:-0} -ge 90 ]] && tg "⚠️ CPU ALTA: ${CPU}%"
    [[ ${MEM:-0} -ge 90 ]] && tg "⚠️ RAM ALTA: ${MEM}%"
}

status_report() {
    echo "╔══════════════════════════════════════╗"
    echo "║   🛡️  FORTRESS — STATUS              ║"
    echo "╚══════════════════════════════════════╝"
    echo " $(date '+%d/%m/%Y %H:%M:%S')"
    echo ""
    echo " Serviços:"
    for S in x-ui nginx fail2ban fortress-ddos; do
        systemctl is-active "$S" > /dev/null 2>&1 && \
            echo "  ✅ $S" || echo "  ❌ $S"
    done
    echo ""
    echo " IPs Banidos: $(wc -l < $BANNED 2>/dev/null || echo 0)"
    echo " Conexões: $(ss -tn state established 2>/dev/null | wc -l)"
    CPU=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2}')
    MEM=$(free -h 2>/dev/null | grep Mem | awk '{print $3"/"$2}')
    echo " CPU: ${CPU}% | RAM: $MEM"
}

case "${1:-monitor}" in
    monitor)
        while true; do
            check_services
            check_bruteforce
            check_miners
            check_resources
            sleep 60
        done ;;
    status)  status_report ;;
    check)
        check_services
        check_bruteforce
        check_miners
        echo "✅ Verificação OK" ;;
    ban)
        [[ -n "$2" ]] && ban_ip "$2" "manual" ;;
    unban)
        [[ -n "$2" ]] && {
            sed -i "/^$2$/d" "$BANNED"
            iptables -D INPUT -s "$2" -j DROP 2>/dev/null
            ipset del BLOCKED "$2" 2>/dev/null
            echo "✅ $2 removido"
        } ;;
    daily)
        B=$(wc -l < $BANNED 2>/dev/null || echo 0)
        C=$(ss -tn state established 2>/dev/null | wc -l)
        CPU=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2}')
        MEM=$(free -h 2>/dev/null | grep Mem | awk '{print $3"/"$2}')
        DISK=$(df -h / 2>/dev/null | tail -1 | awk '{print $5}')
        UP=$(uptime -p 2>/dev/null)
        tg "📊 *RELATÓRIO DIÁRIO*%0A🖥️ $(hostname)%0A⏱️ $UP%0ACPU: ${CPU}%%%0ARAM: $MEM%0ADisco: $DISK%0AConexões: $C%0ABanidos: $B%0A✅ PROTEGIDO"
        ;;
    *) echo "fortress-monitor {monitor|status|check|ban IP|unban IP|daily}" ;;
esac
MONITOR
    chmod +x /usr/local/bin/fortress-monitor

    cat > /etc/systemd/system/fortress-monitor.service << 'EOF'
[Unit]
Description=Fortress Monitor 24/7
After=network.target x-ui.service
[Service]
Type=simple
ExecStart=/usr/local/bin/fortress-monitor monitor
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now fortress-monitor 2>/dev/null

    echo "0 7 * * * root /usr/local/bin/fortress-monitor daily" \
        > /etc/cron.d/fortress-daily

    ok "Monitor 24/7 ativo"
    log_f "OK" "Monitor"
}

# ══════════════════════════════════════════════════════
# [18] AIDE + AUTO-UPDATES
# ══════════════════════════════════════════════════════

step_18() {
    step "18-19" "🗂️ AIDE + 🔄 Auto-Updates"

    aideinit 2>/dev/null || aide --init > /dev/null 2>&1
    mv /var/lib/aide/aide.db.new \
        /var/lib/aide/aide.db 2>/dev/null
    ok "AIDE inicializado"

    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
    systemctl enable unattended-upgrades 2>/dev/null

    ok "Auto-updates de segurança"
    log_f "OK" "AIDE + Auto-updates"
}

# ══════════════════════════════════════════════════════
# [20-25] ANTI-MINER + BACKUP + CLI
# ══════════════════════════════════════════════════════

step_20() {
    step "20-25" "⛏️ Anti-Miner + 💾 Backup + 🖥️ CLI"

    # Anti-Miner
    for MP in 3333 4444 5555 6666 7777 8888 9999 14444 45560; do
        iptables -A OUTPUT -p tcp --dport "$MP" -j DROP 2>/dev/null
    done
    for MD in pool.minexmr.com supportxmr.com nanopool.org \
              moneroocean.stream coinhive.com coin-hive.com; do
        grep -q "$MD" /etc/hosts || \
            echo "0.0.0.0 $MD" >> /etc/hosts
    done
    ok "Anti-Miner configurado"

    # Permissões
    chmod 644 /etc/passwd
    chmod 000 /etc/shadow
    chmod 644 /etc/group
    chmod 440 /etc/sudoers
    chmod 700 /root
    chmod 700 /root/.ssh 2>/dev/null
    echo "umask 027" >> /etc/profile
    ok "Permissões endurecidas"

    # Backup
    cat > /usr/local/bin/fortress-backup << 'BKEOF'
#!/bin/bash
source /etc/fortress/config.env 2>/dev/null
DIR="/root/fortress-backups"
TS=$(date '+%Y%m%d_%H%M%S')
TMP=$(mktemp -d); trap "rm -rf $TMP" EXIT
mkdir -p "$TMP/data" "$DIR"
cp /usr/local/x-ui/x-ui.db "$TMP/data/" 2>/dev/null
cp /etc/x-ui/x-ui.db "$TMP/data/" 2>/dev/null
cp -r /etc/fortress "$TMP/data/" 2>/dev/null
cp /etc/ssh/sshd_config "$TMP/data/" 2>/dev/null
iptables-save > "$TMP/data/iptables.rules" 2>/dev/null
PASS=$(openssl rand -base64 32)
tar -czf "$TMP/bak.tar.gz" -C "$TMP/data" . 2>/dev/null
openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt \
    -in "$TMP/bak.tar.gz" \
    -out "$DIR/fortress-$TS.enc" \
    -pass "pass:$PASS"
echo "$PASS" > "$DIR/fortress-$TS.pass"
chmod 600 "$DIR/fortress-$TS.pass"
SIZE=$(du -sh "$DIR/fortress-$TS.enc" | cut -f1)
echo "✅ Backup: fortress-$TS.enc ($SIZE)"
ls -t "$DIR"/*.enc 2>/dev/null | tail -n +8 | \
while read F; do rm -f "${F%.enc}".*; done
BKEOF
    chmod +x /usr/local/bin/fortress-backup
    /usr/local/bin/fortress-backup
    echo "0 3 * * 0 root /usr/local/bin/fortress-backup" \
        >> /etc/cron.d/fortress-daily
    ok "Backup automático configurado"

    # CLI básica
    cat > /usr/local/bin/fortress << 'CLIMAIN'
#!/bin/bash
source /etc/fortress/config.env 2>/dev/null
case "${1:-menu}" in
    menu)
        clear
        echo "╔══════════════════════════════════════╗"
        echo "║    🛡️  FORTRESS SHIELD               ║"
        echo "╚══════════════════════════════════════╝"
        echo "  [1] Status    [2] Banir IP"
        echo "  [3] Desbanir  [4] IPs banidos"
        echo "  [5] Fail2Ban  [6] Logs"
        echo "  [7] Backup    [8] Reiniciar"
        echo "  [9] Telegram  [0] Sair"
        read -p "  Opção: " O
        case $O in
            1) fortress-monitor status; read -p "Enter..."; fortress menu ;;
            2) read -p "IP: " I; fortress-monitor ban "$I"; read -p "Enter..."; fortress menu ;;
            3) read -p "IP: " I; fortress-monitor unban "$I"; read -p "Enter..."; fortress menu ;;
            4) cat /etc/fortress/banned_ips.txt 2>/dev/null | nl; read -p "Enter..."; fortress menu ;;
            5) fail2ban-client status; read -p "Enter..."; fortress menu ;;
            6) tail -50 /var/log/fortress/*.log 2>/dev/null; read -p "Enter..."; fortress menu ;;
            7) fortress-backup; read -p "Enter..."; fortress menu ;;
            8) for S in x-ui nginx fail2ban fortress-monitor fortress-ddos; do systemctl restart "$S" 2>/dev/null && echo "✅ $S" || echo "❌ $S"; done; read -p "Enter..."; fortress menu ;;
            9) [[ -n "$TG_TOKEN" ]] && curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_CHAT_ID" -d "text=🛡️ Fortress OK - $(date)" > /dev/null && echo "✅" || echo "❌"; read -p "Enter..."; fortress menu ;;
            0) exit 0 ;;
            *) fortress menu ;;
        esac ;;
    status)  fortress-monitor status ;;
    ban)     fortress-monitor ban "$2" ;;
    unban)   fortress-monitor unban "$2" ;;
    check)   fortress-monitor check ;;
    backup)  fortress-backup ;;
    logs)    tail -f /var/log/fortress/fortress.log ;;
    *) echo "fortress {menu|status|ban IP|unban IP|check|backup|logs}" ;;
esac
CLIMAIN
    chmod +x /usr/local/bin/fortress
    echo "alias f='fortress'" >> /root/.bashrc

    ok "CLI instalada"
    log_f "OK" "Anti-miner + Backup + CLI"
}

# ══════════════════════════════════════════════════════
# CONFIGURAR NGINX SITE (sem caminho oculto ainda)
# ══════════════════════════════════════════════════════

configure_nginx_site() {
    cat > /etc/nginx/sites-available/fortress << SITEEOF
server {
    listen 80 default_server;
    server_name ${PANEL_DOMAIN:-_};
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2 default_server;
    server_name ${PANEL_DOMAIN:-_};

    ssl_certificate /etc/ssl/fortress/fullchain.pem;
    ssl_certificate_key /etc/ssl/fortress/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    if (\$bad_ua) { return 444; }
    if (\$bad_uri) { return 403; }

    limit_conn perip 30;
    limit_req zone=global burst=200 nodelay;

    location ~* ^/(login|xui/login)\$ {
        limit_req zone=login burst=3 nodelay;
        limit_req_status 429;
        access_log /var/log/fortress/xui-access.log;
        proxy_pass http://127.0.0.1:${XUI_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location / {
        limit_req zone=api burst=100 nodelay;
        proxy_pass http://127.0.0.1:${XUI_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400;
    }

    location ~* ^/(wp-admin|wp-login|phpMyAdmin|\.env|\.git) {
        access_log /var/log/fortress/scanners.log;
        return 444;
    }

    location ~* \.(env|git|bak|sql|db|log|key|pem)\$ {
        deny all;
        return 404;
    }
}
SITEEOF

    ln -sf /etc/nginx/sites-available/fortress \
           /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    nginx -t 2>/dev/null && systemctl restart nginx 2>/dev/null
    ok "Nginx site configurado"
}

# ══════════════════════════════════════════════════════
# FINALIZAR
# ══════════════════════════════════════════════════════

finalize() {
    netfilter-persistent save > /dev/null 2>&1
    ipset save > /etc/ipset/fortress.rules 2>/dev/null
    systemctl daemon-reload

    for SVC in x-ui nginx fail2ban fortress-monitor \
               fortress-ddos auditd; do
        systemctl restart "$SVC" 2>/dev/null
    done

    tg_send "🛡️ *SECURITY.SH INSTALADO*%0A✅ 25 camadas ativas%0A🖥️ $(hostname)%0A🌐 $SERVER_IP"
    log_f "OK" "Security.sh concluído"
}

# ══════════════════════════════════════════════════════
# RELATÓRIO FINAL
# ══════════════════════════════════════════════════════

final_report() {
    clear
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║   ✅  SECURITY.SH CONCLUÍDO — 25 CAMADAS ATIVAS!    ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  SSH porta:    ${YELLOW}$SSH_PORT${NC}"
    echo -e "  x-ui porta:   ${YELLOW}$XUI_PORT${NC}"
    echo -e "  IP Admin:     ${YELLOW}$ADMIN_IP${NC}"
    echo -e "  Servidor:     ${YELLOW}$SERVER_IP${NC}"
    echo ""
    echo -e "  ${CYAN}Acesso ao painel:${NC}"
    echo -e "  ${YELLOW}https://$SERVER_IP${NC}  (via Nginx)"
    echo -e "  ${YELLOW}http://$SERVER_IP:$XUI_PORT${NC}  (direto)"
    echo ""
    echo -e "  ${CYAN}Comandos:${NC}"
    echo -e "  ${YELLOW}fortress${NC}  → Menu principal"
    echo -e "  ${YELLOW}fortress status${NC}"
    echo -e "  ${YELLOW}fortress ban IP${NC}"
    echo ""
    echo -e "  ${RED}⚠️  PRÓXIMO PASSO: Execute fortress.sh${NC}"
    echo -e "  ${RED}     para as camadas 26-42 (WireGuard,${NC}"
    echo -e "  ${RED}     Port Knocking, Canary, etc.)${NC}"
    echo ""
}

# ══════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════

main() {
    check_root
    banner
    collect_info

    echo -e "\n${GREEN}🚀 Instalando 25 camadas...${NC}\n"

    step_01
    step_02
    step_03
    step_04
    step_05
    step_06
    step_07
    step_08
    step_09
    step_10
    step_11
    step_12
    step_13
    step_16
    step_18
    step_20
    configure_nginx_site
    finalize
    final_report
}

main "$@"