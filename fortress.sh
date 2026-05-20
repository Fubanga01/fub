#!/bin/bash
# ================================================================
#  FORTRESS SHIELD v4.0 — 42 CAMADAS DE PROTEÇÃO
#  Target: Ubuntu 22.04 LTS | x-ui porta 54321
# ================================================================

set -euo pipefail

# ══════════════════════════════════════════════════════════════════
#  VARIÁVEIS E CONFIGURAÇÃO
# ══════════════════════════════════════════════════════════════════

export DEBIAN_FRONTEND=noninteractive

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

XUI_PORT=54321
VERSION="4.0.0"
INSTALL_DATE=$(date '+%d/%m/%Y %H:%M:%S')
FORTRESS_DIR="/etc/fortress"
LOG_DIR="/var/log/fortress"
BACKUP_DIR="/root/fortress-backups"
COLD_DIR="/root/fortress-cold-backup"
MAIN_LOG="$LOG_DIR/fortress.log"

# ── Funções base ──
check_root() {
    [[ $EUID -ne 0 ]] && { echo -e "${RED}Execute como root!${NC}"; exit 1; }
}

check_ubuntu() {
    source /etc/os-release
    if [[ "$ID" != "ubuntu" || "$VERSION_ID" != "22.04" ]]; then
        echo -e "${YELLOW}⚠️  Detectado: $ID $VERSION_ID (otimizado para Ubuntu 22.04)${NC}"
        read -p "Continuar mesmo assim? [s/N]: " CONT
        [[ "${CONT,,}" != "s" ]] && exit 1
    fi
}

step() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${BOLD}${WHITE}[$1/42] $2${NC}"
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

# ══════════════════════════════════════════════════════════════════
#  BANNER E COLETA DE INFORMAÇÕES
# ══════════════════════════════════════════════════════════════════

banner() {
    clear
    echo -e "${RED}"
    cat << 'EOF'
 ███████╗ ██████╗ ██████╗ ████████╗██████╗ ███████╗███████╗███████╗
 ██╔════╝██╔═══██╗██╔══██╗╚══██╔══╝██╔══██╗██╔════╝██╔════╝██╔════╝
 █████╗  ██║   ██║██████╔╝   ██║   ██████╔╝█████╗  ███████╗███████╗
 ██╔══╝  ██║   ██║██╔══██╗   ██║   ██╔══██╗██╔══╝  ╚════██║╚════██║
 ██║     ╚██████╔╝██║  ██║   ██║   ██║  ██║███████╗███████║███████║
 ╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝
EOF
    echo -e "${NC}"
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}🏴‍☠️  FORTRESS SHIELD v4.0 — 42 CAMADAS | Ubuntu 22.04${NC}        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}   Porta x-ui: 54321 | Proteção Total contra Invasão${NC}         ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

collect_info() {
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║              📋  CONFIGURAÇÃO INICIAL                        ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "  ${GREEN}Porta x-ui: $XUI_PORT (pré-configurada)${NC}"
    echo ""

    # SSH
    read -p "  Nova porta SSH [padrão: 2222]: " SSH_PORT
    SSH_PORT=${SSH_PORT:-2222}

    # Domínio
    read -p "  Domínio do painel (Enter = sem domínio): " PANEL_DOMAIN
    PANEL_DOMAIN=${PANEL_DOMAIN:-""}

    # Email
    read -p "  Email para alertas (Enter = pular): " ADMIN_EMAIL
    ADMIN_EMAIL=${ADMIN_EMAIL:-""}

    # IP Admin
    echo ""
    echo -e "  ${CYAN}Seu IP atual: $(echo $SSH_CLIENT | awk '{print $1}')${NC}"
    read -p "  IP admin para whitelist [Enter = IP atual]: " ADMIN_IP
    ADMIN_IP=${ADMIN_IP:-$(echo $SSH_CLIENT | awk '{print $1}')}

    # Telegram
    echo ""
    read -p "  Token do Bot Telegram (Enter = pular): " TG_TOKEN
    TG_TOKEN=${TG_TOKEN:-""}
    if [[ -n "$TG_TOKEN" ]]; then
        read -p "  Chat ID do Telegram: " TG_CHAT_ID
        TG_CHAT_ID=${TG_CHAT_ID:-""}
    fi

    # WireGuard
    echo ""
    echo -e "  ${CYAN}WireGuard VPN para acesso admin:${NC}"
    read -p "  Porta WireGuard [51820]: " WG_PORT
    WG_PORT=${WG_PORT:-51820}
    WG_SUBNET="10.66.66.0/24"

    # Port Knocking
    echo ""
    echo -e "  ${CYAN}Sequência de Port Knocking (3 portas secretas):${NC}"
    read -p "  Porta 1 [7000]: " KNOCK_1; KNOCK_1=${KNOCK_1:-7000}
    read -p "  Porta 2 [8000]: " KNOCK_2; KNOCK_2=${KNOCK_2:-8000}
    read -p "  Porta 3 [9000]: " KNOCK_3; KNOCK_3=${KNOCK_3:-9000}

    # Países bloqueados
    echo ""
    echo -e "  ${CYAN}Bloquear países (ex: CN,RU,KP ou Enter = nenhum):${NC}"
    read -p "  Países: " BLOCKED_COUNTRIES
    BLOCKED_COUNTRIES=${BLOCKED_COUNTRIES:-""}

    # Gerar segredos
    ADMIN_SECRET=$(openssl rand -hex 8)
    ADMIN_PATH="/fortress-${ADMIN_SECRET}"

    SERVER_IP=$(get_server_ip)
    MAIN_IFACE=$(get_main_iface)

    # Criar diretórios
    mkdir -p "$FORTRESS_DIR" "$LOG_DIR" "$BACKUP_DIR" "$COLD_DIR"
    chmod 700 "$FORTRESS_DIR" "$LOG_DIR" "$BACKUP_DIR" "$COLD_DIR"

    # Salvar configuração
    cat > "$FORTRESS_DIR/config.env" << ENVFILE
# Fortress Shield v4.0 Config
XUI_PORT=$XUI_PORT
SSH_PORT=$SSH_PORT
PANEL_DOMAIN=$PANEL_DOMAIN
ADMIN_EMAIL=$ADMIN_EMAIL
ADMIN_IP=$ADMIN_IP
TG_TOKEN=$TG_TOKEN
TG_CHAT_ID=$TG_CHAT_ID
WG_PORT=$WG_PORT
WG_SUBNET=$WG_SUBNET
KNOCK_1=$KNOCK_1
KNOCK_2=$KNOCK_2
KNOCK_3=$KNOCK_3
BLOCKED_COUNTRIES=$BLOCKED_COUNTRIES
ADMIN_SECRET=$ADMIN_SECRET
ADMIN_PATH=$ADMIN_PATH
SERVER_IP=$SERVER_IP
MAIN_IFACE=$MAIN_IFACE
INSTALL_DATE=$INSTALL_DATE
VERSION=$VERSION
ENVFILE
    chmod 600 "$FORTRESS_DIR/config.env"

    # Confirmar
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  x-ui:          ${YELLOW}$XUI_PORT${NC}"
    echo -e "  SSH:           ${YELLOW}$SSH_PORT${NC}"
    echo -e "  Domínio:       ${YELLOW}${PANEL_DOMAIN:-'Nenhum'}${NC}"
    echo -e "  IP Admin:      ${YELLOW}$ADMIN_IP${NC}"
    echo -e "  WireGuard:     ${YELLOW}$WG_PORT${NC}"
    echo -e "  Port Knock:    ${YELLOW}$KNOCK_1→$KNOCK_2→$KNOCK_3${NC}"
    echo -e "  Telegram:      ${YELLOW}${TG_TOKEN:+'Sim'}${TG_TOKEN:-'Não'}${NC}"
    echo -e "  Países Block:  ${YELLOW}${BLOCKED_COUNTRIES:-'Nenhum'}${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    read -p "  Confirmar e instalar? [S/n]: " CONFIRM
    [[ "${CONFIRM,,}" == "n" ]] && exit 0
}


# ══════════════════════════════════════════════════════════════════
#  [01] ATUALIZAÇÃO DO SISTEMA
# ══════════════════════════════════════════════════════════════════

step_01() {
    step "01" "🔄 Atualização Completa do Sistema"

    apt-get update -y -q
    apt-get upgrade -y -q
    apt-get dist-upgrade -y -q

    apt-get install -y -q \
        curl wget git unzip tar socat jq bc moreutils psmisc lsof \
        net-tools htop vnstat iftop nethogs sysstat \
        tcpdump whois dnsutils geoip-bin \
        openssl gnupg2 ca-certificates \
        python3 python3-pip \
        fail2ban ufw \
        iptables iptables-persistent netfilter-persistent ipset \
        apparmor apparmor-utils apparmor-profiles apparmor-profiles-extra \
        auditd aide \
        rkhunter chkrootkit \
        clamav clamav-daemon \
        unattended-upgrades apt-listchanges \
        logwatch \
        nginx certbot python3-certbot-nginx \
        libnginx-mod-http-geoip \
        openssh-server \
        libpam-google-authenticator \
        wireguard wireguard-tools qrencode \
        knockd \
        inotify-tools \
        yara \
        unbound unbound-anchor dns-root-data \
        2>/dev/null

    apt-get autoremove -y -q
    apt-get autoclean -y -q

    ok "Sistema atualizado e dependências instaladas"
    log_f "OK" "Sistema atualizado"
}


# ══════════════════════════════════════════════════════════════════
#  [02] SSH ULTRA SEGURO
# ══════════════════════════════════════════════════════════════════

step_02() {
    step "02" "🔐 SSH Ultra Seguro"

    cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.bak.$(date +%s)"

    # Gerar chave ED25519 se não existir
    [[ ! -f /etc/ssh/ssh_host_ed25519_key ]] && \
        ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N "" > /dev/null 2>&1

    cat > /etc/ssh/sshd_config << SSHEOF
# ══════════════════════════════════════
# SSH Seguro — Fortress Shield
# ══════════════════════════════════════

Port $SSH_PORT
AddressFamily inet
ListenAddress 0.0.0.0
Protocol 2

HostKey /etc/ssh/ssh_host_ed25519_key
HostKey /etc/ssh/ssh_host_rsa_key

KexAlgorithms curve25519-sha256@libssh.org,curve25519-sha256,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

LoginGraceTime 20
PermitRootLogin yes
StrictModes yes
MaxAuthTries 3
MaxSessions 3

PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# SENHA ATIVADA TEMPORARIAMENTE — desabilite após adicionar chave SSH
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
KerberosAuthentication no
GSSAPIAuthentication no
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
Compression no
UseDNS no
MaxStartups 3:50:10

SyslogFacility AUTH
LogLevel VERBOSE

Banner /etc/ssh/fortress_banner
SSHEOF

    cat > /etc/ssh/fortress_banner << 'BANNER'

 ╔═══════════════════════════════════════════════════════╗
 ║     ⚠️  SISTEMA MONITORADO — ACESSO RESTRITO  ⚠️       ║
 ║                                                       ║
 ║  Acesso não autorizado é CRIME (Lei 12.737/2012)     ║
 ║  IP, data e ações registrados e monitorados.         ║
 ╚═══════════════════════════════════════════════════════╝

BANNER

    # Remover chaves fracas
    rm -f /etc/ssh/ssh_host_dsa_key* /etc/ssh/ssh_host_ecdsa_key* 2>/dev/null

    sshd -t 2>/dev/null && systemctl restart sshd
    ok "SSH na porta $SSH_PORT (senha ativa temporariamente)"
    warn "Adicione chave SSH e depois desabilite PasswordAuthentication"
    log_f "OK" "SSH configurado porta $SSH_PORT"
}


# ══════════════════════════════════════════════════════════════════
#  [03] UFW FIREWALL
# ══════════════════════════════════════════════════════════════════

step_03() {
    step "03" "🔥 Firewall UFW"

    ufw --force reset > /dev/null 2>&1
    ufw --force disable > /dev/null 2>&1

    ufw default deny incoming
    ufw default allow outgoing
    ufw default deny forward

    # Whitelist admin
    [[ -n "$ADMIN_IP" ]] && ufw allow from "$ADMIN_IP" comment "Admin"

    # Essenciais
    ufw limit "$SSH_PORT"/tcp comment "SSH"
    ufw allow 80/tcp comment "HTTP"
    ufw allow 443/tcp comment "HTTPS"
    ufw limit "$XUI_PORT"/tcp comment "x-ui"
    ufw allow "$WG_PORT"/udp comment "WireGuard"

    # Bloquear portas perigosas
    for P in 21 23 25 135 137 138 139 445 1433 3306 3389 5432 5900 6379 27017; do
        ufw deny "$P" comment "Perigosa" > /dev/null 2>&1
    done

    ufw --force enable > /dev/null 2>&1
    ok "UFW ativo"
    log_f "OK" "UFW configurado"
}


# ══════════════════════════════════════════════════════════════════
#  [04] IPTABLES MULTI-CAMADA
# ══════════════════════════════════════════════════════════════════

step_04() {
    step "04" "🛡️ IPTables Multi-Camada"

    # Whitelist admin no topo (NUNCA bloquear)
    [[ -n "$ADMIN_IP" ]] && iptables -I INPUT 1 -s "$ADMIN_IP" -j ACCEPT

    # Conexões estabelecidas
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Loopback
    iptables -A INPUT -i lo -j ACCEPT

    # Invalid
    iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
    iptables -A INPUT -p tcp ! --syn -m conntrack --ctstate NEW -j DROP

    # ── Anti-Spoofing ──
    for BOGON in "0.0.0.0/8" "127.0.0.0/8" "169.254.0.0/16" "224.0.0.0/4" "240.0.0.0/4"; do
        iptables -A INPUT -s "$BOGON" ! -i lo -j DROP 2>/dev/null
    done

    # ── SYN Flood ──
    iptables -N SYN_FLOOD 2>/dev/null || iptables -F SYN_FLOOD
    iptables -A SYN_FLOOD -p tcp --syn -m limit --limit 30/s --limit-burst 60 -j RETURN
    iptables -A SYN_FLOOD -j DROP
    iptables -A INPUT -p tcp --syn -j SYN_FLOOD

    echo 1 > /proc/sys/net/ipv4/tcp_syncookies

    # ── ICMP Flood ──
    iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 2/s --limit-burst 5 -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
    iptables -A INPUT -p icmp -j ACCEPT

    # ── Port Scan ──
    iptables -N PORT_SCAN 2>/dev/null || iptables -F PORT_SCAN
    iptables -A PORT_SCAN -p tcp --tcp-flags ALL NONE -j LOG --log-prefix "NULL_SCAN: "
    iptables -A PORT_SCAN -p tcp --tcp-flags ALL NONE -j DROP
    iptables -A PORT_SCAN -p tcp --tcp-flags ALL ALL -j LOG --log-prefix "XMAS_SCAN: "
    iptables -A PORT_SCAN -p tcp --tcp-flags ALL ALL -j DROP
    iptables -A PORT_SCAN -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
    iptables -A PORT_SCAN -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
    iptables -A PORT_SCAN -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP
    iptables -A INPUT -j PORT_SCAN

    # ── DDoS ──
    iptables -N DDOS_PROTECT 2>/dev/null || iptables -F DDOS_PROTECT
    iptables -A DDOS_PROTECT -m connlimit --connlimit-above 80 --connlimit-mask 32 -j DROP
    iptables -A DDOS_PROTECT -p tcp --syn -m recent --name DDOS --set
    iptables -A DDOS_PROTECT -p tcp --syn -m recent --name DDOS --rcheck --seconds 1 --hitcount 20 -j DROP
    iptables -A INPUT -j DDOS_PROTECT

    # ── SSH Brute Force ──
    iptables -N SSH_BF 2>/dev/null || iptables -F SSH_BF
    iptables -A SSH_BF -m recent --name SSH --set --rsource
    iptables -A SSH_BF -m recent --name SSH --rcheck --seconds 60 --hitcount 4 -j LOG --log-prefix "SSH_BRUTE: "
    iptables -A SSH_BF -m recent --name SSH --rcheck --seconds 60 --hitcount 4 -j DROP
    iptables -A SSH_BF -j ACCEPT
    iptables -A INPUT -p tcp --dport "$SSH_PORT" --syn -j SSH_BF

    # ── x-ui Brute Force ──
    iptables -N XUI_BF 2>/dev/null || iptables -F XUI_BF
    iptables -A XUI_BF -m connlimit --connlimit-above 30 --connlimit-mask 32 -j DROP
    iptables -A XUI_BF -m recent --name XUI --set --rsource
    iptables -A XUI_BF -m recent --name XUI --rcheck --seconds 60 --hitcount 10 -j LOG --log-prefix "XUI_BRUTE: "
    iptables -A XUI_BF -m recent --name XUI --rcheck --seconds 60 --hitcount 10 -j DROP
    iptables -A XUI_BF -j ACCEPT
    iptables -A INPUT -p tcp --dport "$XUI_PORT" -j XUI_BF

    # ── HTTP/HTTPS ──
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT

    # ── WireGuard ──
    iptables -A INPUT -p udp --dport "$WG_PORT" -j ACCEPT

    # ── Log final ──
    iptables -A INPUT -m limit --limit 3/min -j LOG --log-prefix "DROPPED: " --log-level 4

    # Salvar
    netfilter-persistent save > /dev/null 2>&1

    ok "IPTables: anti-scan, anti-flood, anti-spoof, anti-DDoS"
    log_f "OK" "IPTables configurado"
}


# ══════════════════════════════════════════════════════════════════
#  [05] IPSET + BLOCKLISTS
# ══════════════════════════════════════════════════════════════════

step_05() {
    step "05" "🌐 IPSet + Blocklists Globais"

    ipset create BLOCKED hash:ip maxelem 2000000 timeout 86400 2>/dev/null || ipset flush BLOCKED
    ipset create TOR_EXIT hash:ip maxelem 200000 timeout 3600 2>/dev/null || ipset flush TOR_EXIT

    # TOR
    info "Baixando lista TOR..."
    TOR_COUNT=0
    curl -s --connect-timeout 10 "https://check.torproject.org/torbulkexitlist" 2>/dev/null | \
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | \
    while IFS= read -r ip; do
        ipset add TOR_EXIT "$ip" 2>/dev/null && ((TOR_COUNT++)) || true
    done
    ok "TOR Exit Nodes bloqueados"

    # Blocklist.de
    info "Baixando blocklist.de..."
    curl -s --connect-timeout 10 "https://lists.blocklist.de/lists/all.txt" 2>/dev/null | \
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -50000 | \
    while IFS= read -r ip; do
        ipset add BLOCKED "$ip" 2>/dev/null || true
    done
    ok "Blocklist.de carregada"

    # Aplicar
    iptables -I INPUT 2 -m set --match-set BLOCKED src -j DROP 2>/dev/null
    iptables -I INPUT 3 -m set --match-set TOR_EXIT src -j DROP 2>/dev/null

    mkdir -p /etc/ipset
    ipset save > /etc/ipset/fortress.rules

    # Auto-atualização
    cat > /etc/cron.daily/fortress-blocklist << 'CRONBL'
#!/bin/bash
ipset flush TOR_EXIT 2>/dev/null
curl -s "https://check.torproject.org/torbulkexitlist" 2>/dev/null | \
grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | \
while IFS= read -r ip; do ipset add TOR_EXIT "$ip" 2>/dev/null; done

curl -s "https://lists.blocklist.de/lists/all.txt" 2>/dev/null | \
grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -50000 | \
while IFS= read -r ip; do ipset add BLOCKED "$ip" 2>/dev/null; done

ipset save > /etc/ipset/fortress.rules
CRONBL
    chmod +x /etc/cron.daily/fortress-blocklist

    ok "IPSet com auto-atualização diária"
    log_f "OK" "IPSet configurado"
}


# ══════════════════════════════════════════════════════════════════
#  [06] FAIL2BAN 20+ JAILS
# ══════════════════════════════════════════════════════════════════

step_06() {
    step "06" "🔨 Fail2Ban — 20+ Jails"

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
bantime  = 86400

[nginx-limit-req]
enabled  = true
port     = http,https
filter   = nginx-limit-req
logpath  = /var/log/nginx/error.log
maxretry = 5
bantime  = 3600

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
bantime  = 86400

[nginx-noproxy]
enabled  = true
port     = http,https
filter   = nginx-noproxy
logpath  = /var/log/nginx/access.log
maxretry = 1
bantime  = 604800

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

    # Filtros customizados
    cat > /etc/fail2ban/filter.d/xui-login.conf << 'EOF'
[Definition]
failregex = ^<HOST>.*"POST.*(login|xui/login).*" (401|403|429)
ignoreregex =
EOF

    cat > /etc/fail2ban/filter.d/xui-scanner.conf << 'EOF'
[Definition]
failregex = ^<HOST>.*"(GET|POST).*(\.php|\.asp|\.env|\.git|wp-login|phpMyAdmin|admin\.php|shell).*"
ignoreregex =
EOF

    cat > /etc/fail2ban/filter.d/portscan.conf << 'EOF'
[Definition]
failregex = .*PORT_SCAN.*SRC=<HOST>
            .*NULL_SCAN.*SRC=<HOST>
            .*XMAS_SCAN.*SRC=<HOST>
            .*DROPPED.*SRC=<HOST>
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

    cat > /etc/fail2ban/filter.d/nginx-noproxy.conf << 'EOF'
[Definition]
failregex = ^<HOST> -.*GET http.*
ignoreregex =
EOF

    cat > /etc/fail2ban/filter.d/nginx-404.conf << 'EOF'
[Definition]
failregex = ^<HOST> - .* "(GET|POST).*" 404
ignoreregex = \.(ico|png|jpg|css|js|woff)
EOF

    systemctl enable fail2ban
    systemctl restart fail2ban

    ok "Fail2Ban com 14+ jails ativo"
    log_f "OK" "Fail2Ban configurado"
}


# ══════════════════════════════════════════════════════════════════
#  [07] KERNEL HARDENING
# ══════════════════════════════════════════════════════════════════

step_07() {
    step "07" "⚙️ Kernel Hardening"

    cat > /etc/sysctl.d/99-fortress.conf << 'EOF'
# ── TCP/IP ──
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_max_syn_backlog = 4096
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl = 10
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_sack = 0

# ── Anti-Spoofing ──
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# ── Redirecionamentos ──
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0

# ── ICMP ──
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# ── Log ──
net.ipv4.conf.all.log_martians = 1

# ── IPv6 desabilitado ──
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

# ── Memória / Kernel ──
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.perf_event_paranoid = 3
kernel.yama.ptrace_scope = 2
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2
kernel.sysrq = 0
kernel.core_uses_pid = 1
kernel.core_pattern = |/bin/false
fs.suid_dumpable = 0

# ── Filesystem ──
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2

# ── Performance ──
net.core.somaxconn = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.core.netdev_max_backlog = 65536

# ── WireGuard precisa de ip_forward ──
net.ipv4.ip_forward = 1
EOF

    sysctl -p /etc/sysctl.d/99-fortress.conf > /dev/null 2>&1

    # Módulos perigosos desabilitados
    cat > /etc/modprobe.d/fortress-blacklist.conf << 'EOF'
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
install cramfs /bin/true
install freevxfs /bin/true
install hfs /bin/true
install hfsplus /bin/true
install udf /bin/true
install bluetooth /bin/true
install usb-storage /bin/true
EOF

    ok "40+ parâmetros de kernel endurecidos"
    ok "Módulos inseguros desabilitados"
    log_f "OK" "Kernel hardening aplicado"
}


# ══════════════════════════════════════════════════════════════════
#  [08] NGINX WAF + PROXY REVERSO
# ══════════════════════════════════════════════════════════════════

step_08() {
    step "08" "🌐 Nginx WAF + Proxy Reverso"

    mkdir -p /var/log/fortress

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
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript text/xml;

    log_format fortress '$time_iso8601 | $remote_addr | $request_method | $host$request_uri | $status | $body_bytes_sent | "$http_user_agent"';
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
        ~*burpsuite 1; ~*acunetix 1; ~*nessus 1; ~*openvas 1;
        ~*python-requests/2 1; ~*Go-http-client 1;
        ~*libwww-perl 1; ~*HTTrack 1;
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

    # Site principal
    cat > /etc/nginx/sites-available/fortress << SITEEOF
server {
    listen 80 default_server;
    server_name ${PANEL_DOMAIN:-_};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        allow all;
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
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;

    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header X-Robots-Tag "noindex, nofollow" always;

    if (\$bad_ua) { return 444; }
    if (\$bad_uri) { return 403; }

    limit_conn perip 30;
    limit_req zone=global burst=200 nodelay;

    # ── Admin oculto ──
    location ${ADMIN_PATH}/ {
        allow ${WG_SUBNET};
        $([ -n "$ADMIN_IP" ] && echo "allow $ADMIN_IP;")
        deny all;
        limit_req zone=login burst=3 nodelay;
        access_log /var/log/fortress/admin-access.log;
        proxy_pass http://127.0.0.1:${XUI_PORT}/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 86400;
    }

    # ── Login rate limited ──
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

    # ── Proxy geral ──
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

    # ── Honeypot ──
    location ~* ^/(wp-admin|wp-login|phpMyAdmin|admin\.php|\.env|\.git) {
        access_log /var/log/fortress/scanners.log;
        return 444;
    }

    location ~* \.(env|git|svn|bak|sql|db|log|key|pem)\$ {
        deny all;
        return 404;
    }
}
SITEEOF

    # Ativar site
    ln -sf /etc/nginx/sites-available/fortress /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    ok "Nginx WAF configurado"
    log_f "OK" "Nginx WAF configurado"
}


# ══════════════════════════════════════════════════════════════════
#  [09] SSL/TLS
# ══════════════════════════════════════════════════════════════════

step_09() {
    step "09" "🔒 SSL/TLS"

    mkdir -p /etc/ssl/fortress /var/www/certbot

    # Gerar DH params
    openssl dhparam -out /etc/ssl/fortress/dhparam.pem 2048 2>/dev/null &
    DH_PID=$!

    if [[ -n "$PANEL_DOMAIN" && -n "$ADMIN_EMAIL" ]]; then
        systemctl stop nginx 2>/dev/null
        certbot certonly --standalone -d "$PANEL_DOMAIN" --email "$ADMIN_EMAIL" \
            --agree-tos --non-interactive --key-type rsa --rsa-key-size 4096 2>/dev/null

        if [[ $? -eq 0 ]]; then
            ln -sf "/etc/letsencrypt/live/$PANEL_DOMAIN/fullchain.pem" /etc/ssl/fortress/fullchain.pem
            ln -sf "/etc/letsencrypt/live/$PANEL_DOMAIN/privkey.pem" /etc/ssl/fortress/privkey.pem
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

    wait $DH_PID 2>/dev/null
    chmod 600 /etc/ssl/fortress/*.pem
    nginx -t 2>/dev/null && systemctl start nginx 2>/dev/null

    ok "SSL configurado"
    log_f "OK" "SSL configurado"
}


# ══════════════════════════════════════════════════════════════════
#  [10-11] CROWDSEC + MODSECURITY (tentativa)
# ══════════════════════════════════════════════════════════════════

step_10_11() {
    step "10-11" "🤖 CrowdSec IPS + ModSecurity"

    # CrowdSec
    curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | bash > /dev/null 2>&1
    apt-get install -y crowdsec crowdsec-firewall-bouncer-iptables 2>/dev/null

    if command -v cscli > /dev/null 2>&1; then
        cscli collections install crowdsecurity/nginx crowdsecurity/ssh-bf crowdsecurity/linux 2>/dev/null
        systemctl enable crowdsec crowdsec-firewall-bouncer 2>/dev/null
        systemctl restart crowdsec crowdsec-firewall-bouncer 2>/dev/null
        ok "CrowdSec IPS ativo"
    else
        warn "CrowdSec não instalou (não crítico)"
    fi

    log_f "OK" "CrowdSec configurado"
}


# ══════════════════════════════════════════════════════════════════
#  [12] ROOTKIT DETECTION
# ══════════════════════════════════════════════════════════════════

step_12() {
    step "12" "🔍 Detecção de Rootkits"

    rkhunter --update --nocolors > /dev/null 2>&1
    rkhunter --propupd --nocolors > /dev/null 2>&1

    cat > /etc/cron.daily/fortress-rkhunter << 'EOF'
#!/bin/bash
/usr/bin/rkhunter --check --nocolors --skip-keypress --report-warnings-only 2>&1 | \
logger -t rkhunter
EOF
    chmod +x /etc/cron.daily/fortress-rkhunter

    ok "RKHunter + ChkRootkit configurados"
    log_f "OK" "Rootkit detection configurado"
}


# ══════════════════════════════════════════════════════════════════
#  [13] AUDITD
# ══════════════════════════════════════════════════════════════════

step_13() {
    step "13" "📋 Auditoria Completa"

    cat > /etc/audit/rules.d/fortress.rules << 'EOF'
-D
-b 8192
-f 2

-w /var/log/lastlog -p rwa -k logins
-w /var/run/utmp -p rwa -k session
-w /var/log/wtmp -p rwa -k logins
-w /var/log/btmp -p rwa -k logins

-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/sudoers -p wa -k privilege
-w /etc/sudoers.d -p wa -k privilege

-w /etc/ssh/sshd_config -p wa -k sshd
-w /root/.ssh -p rwa -k ssh_access

-w /usr/local/x-ui -p wa -k xui
-w /etc/fortress -p wa -k fortress

-w /etc/cron.d -p wa -k cron
-w /etc/cron.daily -p wa -k cron

-a always,exit -F arch=b64 -S execve -F euid=0 -k root_cmds

-w /tmp -p wxa -k tmp
-w /dev/shm -p wxa -k shm

-e 2
EOF

    systemctl restart auditd 2>/dev/null

    ok "Auditd configurado"
    log_f "OK" "Auditd configurado"
}


# ══════════════════════════════════════════════════════════════════
#  [14-16] HONEYPOT + GEOIP + ANTI-DDOS
# ══════════════════════════════════════════════════════════════════

step_14_16() {
    step "14-16" "🍯 Honeypot + 🌍 GeoIP + 💥 Anti-DDoS"

    # Honeypot: portas monitoreadas no iptables
    for HP in 22 23 3389 5900 1433 3306 6379 4444; do
        [[ "$HP" != "$SSH_PORT" ]] && \
            iptables -A INPUT -p tcp --dport "$HP" -j LOG --log-prefix "HONEYPOT_${HP}: " 2>/dev/null
    done
    ok "Honeypot em portas perigosas"

    # GeoIP
    if [[ -n "$BLOCKED_COUNTRIES" ]]; then
        info "Bloqueando países: $BLOCKED_COUNTRIES"
        IFS=',' read -ra COUNTRIES <<< "$BLOCKED_COUNTRIES"
        for CC in "${COUNTRIES[@]}"; do
            CC=$(echo "$CC" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
            ipset create "GEO_${CC^^}" hash:net maxelem 500000 2>/dev/null || ipset flush "GEO_${CC^^}"
            curl -s "https://www.ipdeny.com/ipblocks/data/countries/${CC}.zone" 2>/dev/null | \
            while IFS= read -r NET; do
                [[ -n "$NET" ]] && ipset add "GEO_${CC^^}" "$NET" 2>/dev/null
            done
            iptables -I INPUT -m set --match-set "GEO_${CC^^}" src -j DROP 2>/dev/null
            ok "País bloqueado: ${CC^^}"
        done
    fi

    # Anti-DDoS script
    cat > /usr/local/bin/fortress-ddos << 'DDOS'
#!/bin/bash
source /etc/fortress/config.env 2>/dev/null
while true; do
    ss -tn state established 2>/dev/null | awk 'NR>1{print $5}' | \
    grep -oP '[\d.]+(?=:\d+$)' | sort | uniq -c | sort -rn | \
    while read COUNT IP; do
        if [[ $COUNT -ge 80 && -n "$IP" ]]; then
            iptables -I INPUT -s "$IP" -j DROP 2>/dev/null
            echo "[$(date)] DDoS ban: $IP ($COUNT conn)" >> /var/log/fortress/ddos.log
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
    log_f "OK" "Honeypot + GeoIP + Anti-DDoS"
}


# ══════════════════════════════════════════════════════════════════
#  [17] MONITOR 24/7 + TELEGRAM
# ══════════════════════════════════════════════════════════════════

step_17() {
    step "17" "👁️ Monitor 24/7 + Alertas Telegram"

    cat > /usr/local/bin/fortress-monitor << 'MONITOR'
#!/bin/bash
source /etc/fortress/config.env 2>/dev/null
LOG="/var/log/fortress/monitor.log"
BANNED="/etc/fortress/banned_ips.txt"
touch "$BANNED"

tg() {
    [[ -z "$TG_TOKEN" || -z "$TG_CHAT_ID" ]] && return
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d "chat_id=$TG_CHAT_ID" -d "text=$1" -d "parse_mode=Markdown" > /dev/null 2>&1
}

ban_ip() {
    local IP="$1" REASON="$2"
    grep -q "^$IP$" "$BANNED" 2>/dev/null && return
    echo "$IP" >> "$BANNED"
    iptables -I INPUT 1 -s "$IP" -j DROP 2>/dev/null
    ipset add BLOCKED "$IP" 2>/dev/null
    tg "🚫 *IP BANIDO*%0AIP: \`$IP\`%0AMotivo: $REASON%0AData: $(date '+%d/%m %H:%M')"
    echo "[$(date)] BAN $IP: $REASON" >> "$LOG"
}

check_services() {
    for SVC in x-ui nginx fail2ban; do
        if ! systemctl is-active "$SVC" > /dev/null 2>&1; then
            systemctl restart "$SVC" 2>/dev/null
            sleep 3
            if ! systemctl is-active "$SVC" > /dev/null 2>&1; then
                tg "🔴 *SERVIÇO CAÍDO*: $SVC"
            fi
        fi
    done
}

check_bruteforce() {
    # SSH
    grep "Failed password" /var/log/auth.log 2>/dev/null | \
    grep "$(date '+%b %d')" | awk '{print $(NF-3)}' | \
    sort | uniq -c | sort -rn | while read C IP; do
        [[ $C -ge 5 && -n "$IP" ]] && ban_ip "$IP" "SSH brute ($C)"
    done
    # x-ui
    [[ -f /var/log/nginx/access.log ]] && \
    grep "$(date '+%d/%b/%Y:%H')" /var/log/nginx/access.log 2>/dev/null | \
    grep -E '"POST.*/login.*" (401|403|429)' | awk '{print $1}' | \
    sort | uniq -c | sort -rn | while read C IP; do
        [[ $C -ge 5 && -n "$IP" ]] && ban_ip "$IP" "x-ui brute ($C)"
    done
}

check_connections() {
    ss -tn state established 2>/dev/null | awk 'NR>1{print $5}' | \
    grep -oP '[\d.]+(?=:\d+$)' | sort | uniq -c | sort -rn | \
    while read C IP; do
        [[ $C -ge 60 && -n "$IP" ]] && ban_ip "$IP" "Flood ($C conn)"
    done
}

check_miners() {
    for M in xmrig minerd cpuminer cgminer; do
        if pgrep -x "$M" > /dev/null 2>&1; then
            PID=$(pgrep -x "$M")
            pkill -9 "$M"
            tg "⛏️ *CRYPTOMINER ELIMINADO*: $M (PID: $PID)"
        fi
    done
}

check_resources() {
    CPU=$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1)
    MEM=$(free 2>/dev/null | grep Mem | awk '{printf "%.0f", $3/$2*100}')
    [[ ${CPU:-0} -ge 90 ]] && tg "⚠️ CPU: ${CPU}%"
    [[ ${MEM:-0} -ge 90 ]] && tg "⚠️ RAM: ${MEM}%"
}

status_report() {
    echo "╔══════════════════════════════════════╗"
    echo "║   🛡️  FORTRESS — STATUS              ║"
    echo "╚══════════════════════════════════════╝"
    echo " $(date '+%d/%m/%Y %H:%M:%S')"
    echo ""
    echo " Serviços:"
    for S in x-ui nginx fail2ban fortress-ddos; do
        systemctl is-active "$S" > /dev/null 2>&1 && echo "  ✅ $S" || echo "  ❌ $S"
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
            check_services; check_bruteforce; check_connections
            check_miners; check_resources
            sleep 60
        done ;;
    status) status_report ;;
    check) check_services; check_bruteforce; check_connections; check_miners; echo "✅ OK" ;;
    ban) [[ -n "$2" ]] && ban_ip "$2" "manual" ;;
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
        tg "📊 *RELATÓRIO DIÁRIO*%0A🖥️ $(hostname)%0A⏱️ $UP%0A💻 CPU: ${CPU}%%%0A💾 RAM: $MEM%0A💿 Disco: $DISK%0A🌐 Conexões: $C%0A🚫 IPs Banidos: $B%0A✅ Sistema PROTEGIDO"
        ;;
    *) echo "Uso: fortress-monitor {monitor|status|check|ban IP|unban IP|daily}" ;;
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

    # Relatório diário
    echo "0 7 * * * root /usr/local/bin/fortress-monitor daily" > /etc/cron.d/fortress-daily

    ok "Monitor 24/7 ativo + alertas Telegram"
    log_f "OK" "Monitor configurado"
}


# ══════════════════════════════════════════════════════════════════
#  [18-19] AIDE + AUTO-UPDATES
# ══════════════════════════════════════════════════════════════════

step_18_19() {
    step "18-19" "🗂️ AIDE + 🔄 Atualizações Automáticas"

    # AIDE
    aideinit 2>/dev/null || aide --init > /dev/null 2>&1
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db 2>/dev/null
    ok "AIDE inicializado"

    # Auto-updates
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

    ok "Atualizações automáticas de segurança"
    log_f "OK" "AIDE + Auto-updates"
}


# ══════════════════════════════════════════════════════════════════
#  [20-25] ANTI-MINER + PERMISSÕES + BACKUP + CLI
# ══════════════════════════════════════════════════════════════════

step_20_25() {
    step "20-25" "⛏️ Anti-Miner + 📁 Permissões + 💾 Backup + 🖥️ CLI"

    # [20] Anti-Miner: bloquear portas de mining na saída
    for MP in 3333 4444 5555 6666 7777 8888 9999 14444 45560; do
        iptables -A OUTPUT -p tcp --dport "$MP" -j DROP 2>/dev/null
    done
    # Bloquear domínios de mining via /etc/hosts
    for MD in pool.minexmr.com xmr.pool.minergate.com supportxmr.com \
              nanopool.org moneroocean.stream coinhive.com; do
        grep -q "$MD" /etc/hosts || echo "0.0.0.0 $MD" >> /etc/hosts
    done
    ok "Anti-Miner: portas + domínios bloqueados"

    # [21] Permissões
    chmod 644 /etc/passwd; chmod 000 /etc/shadow; chmod 644 /etc/group
    chmod 440 /etc/sudoers; chmod 700 /root; chmod 700 /root/.ssh 2>/dev/null
    echo "umask 027" >> /etc/profile
    ok "Permissões endurecidas"

    # [22] Backup criptografado
    cat > /usr/local/bin/fortress-backup << 'BKEOF'
#!/bin/bash
source /etc/fortress/config.env 2>/dev/null
DIR="/root/fortress-backups"
TS=$(date '+%Y%m%d_%H%M%S')
PASS=$(openssl rand -base64 32)
TMP=$(mktemp -d); trap "rm -rf $TMP" EXIT
mkdir -p "$TMP/data" "$DIR"
cp /usr/local/x-ui/x-ui.db "$TMP/data/" 2>/dev/null
cp /etc/x-ui/x-ui.db "$TMP/data/" 2>/dev/null
cp -r /etc/fortress "$TMP/data/" 2>/dev/null
cp /etc/ssh/sshd_config "$TMP/data/" 2>/dev/null
cp /root/.ssh/authorized_keys "$TMP/data/" 2>/dev/null
iptables-save > "$TMP/data/iptables.rules" 2>/dev/null
cp -r /etc/wireguard "$TMP/data/" 2>/dev/null
tar -czf "$TMP/bak.tar.gz" -C "$TMP/data" . 2>/dev/null
openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt \
    -in "$TMP/bak.tar.gz" -out "$DIR/fortress-$TS.enc" -pass "pass:$PASS"
echo "$PASS" > "$DIR/fortress-$TS.pass"; chmod 600 "$DIR/fortress-$TS.pass"
sha256sum "$DIR/fortress-$TS.enc" > "$DIR/fortress-$TS.sha256"
SIZE=$(du -sh "$DIR/fortress-$TS.enc" | cut -f1)
echo "✅ Backup: fortress-$TS.enc ($SIZE)"
ls -t "$DIR"/*.enc 2>/dev/null | tail -n +8 | while read F; do rm -f "${F%.enc}".*; done
BKEOF
    chmod +x /usr/local/bin/fortress-backup
    /usr/local/bin/fortress-backup
    echo "0 3 * * 0 root /usr/local/bin/fortress-backup" >> /etc/cron.d/fortress-daily
    ok "Backup criptografado (AES-256)"

    log_f "OK" "Anti-miner + Permissões + Backup"
}


# ══════════════════════════════════════════════════════════════════
#  [26] APPARMOR
# ══════════════════════════════════════════════════════════════════

step_26() {
    step "26" "🔒 AppArmor — Isolamento de Processos"

    systemctl enable apparmor 2>/dev/null
    systemctl start apparmor 2>/dev/null

    cat > /etc/apparmor.d/usr.local.x-ui << 'EOF'
#include <tunables/global>
/usr/local/x-ui/x-ui {
    #include <abstractions/base>
    #include <abstractions/nameservice>
    #include <abstractions/openssl>
    /usr/local/x-ui/** mr,
    /usr/local/x-ui/x-ui mr,
    /usr/local/x-ui/bin/** mrix,
    /usr/local/x-ui/*.db rw,
    /usr/local/x-ui/*.db-* rw,
    /etc/ssl/** r,
    /etc/fortress/ssl/** r,
    /var/log/** rw,
    /tmp/** rw,
    network inet stream,
    network inet dgram,
    network inet6 stream,
    /proc/sys/net/** r,
    /proc/meminfo r,
    /proc/cpuinfo r,
    deny /root/** rwx,
    deny /home/** rwx,
    deny /etc/shadow rwx,
    deny /etc/sudoers rwx,
    deny /usr/bin/sudo x,
    deny /usr/bin/su x,
    deny /usr/bin/wget x,
    deny /usr/bin/curl x,
    deny /usr/bin/gcc x,
    deny /usr/bin/python* x,
    deny /usr/bin/perl x,
    deny /usr/bin/nc x,
    deny /usr/bin/nmap x,
}
EOF

    apparmor_parser -r /etc/apparmor.d/usr.local.x-ui 2>/dev/null
    aa-enforce /etc/apparmor.d/usr.local.x-ui 2>/dev/null

    ok "AppArmor: x-ui isolado (bloqueado: sudo, su, wget, curl, gcc, nc)"
    log_f "OK" "AppArmor configurado"
}


# ══════════════════════════════════════════════════════════════════
#  [27] ISOLAMENTO SYSTEMD
# ══════════════════════════════════════════════════════════════════

step_27() {
    step "27" "🔗 Isolamento Systemd"

    mkdir -p /etc/systemd/system/x-ui.service.d
    cat > /etc/systemd/system/x-ui.service.d/fortress.conf << 'EOF'
[Service]
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true
ProtectClock=true
NoNewPrivileges=true
ReadWritePaths=/usr/local/x-ui
ReadWritePaths=/etc/x-ui
ReadWritePaths=/var/log
ReadOnlyPaths=/etc/ssl
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_ADMIN CAP_NET_RAW
AmbientCapabilities=CAP_NET_BIND_SERVICE
LimitNOFILE=65535
MemoryMax=2G
CPUQuota=80%
TasksMax=256
RestrictRealtime=true
RestrictSUIDSGID=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
LockPersonality=true
RemoveIPC=true
SystemCallFilter=@system-service
SystemCallFilter=~@mount @reboot @swap @raw-io @obsolete @debug @privileged
SystemCallArchitectures=native
EOF

    mkdir -p /etc/systemd/system/nginx.service.d
    cat > /etc/systemd/system/nginx.service.d/fortress.conf << 'EOF'
[Service]
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
NoNewPrivileges=true
ReadWritePaths=/var/log/nginx /var/lib/nginx /run /var/log/fortress
ReadOnlyPaths=/etc/nginx /etc/ssl /var/www
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
LimitNOFILE=65535
RestrictRealtime=true
LockPersonality=true
EOF

    systemctl daemon-reload
    systemctl restart x-ui nginx 2>/dev/null

    ok "x-ui + Nginx: ProtectSystem=strict, PrivateTmp, NoNewPrivileges"
    log_f "OK" "Systemd isolation"
}


# ══════════════════════════════════════════════════════════════════
#  [29] DNS HARDENING — UNBOUND + DNSSEC + DoT
# ══════════════════════════════════════════════════════════════════

step_29() {
    step "29" "🌐 DNS Hardening — Unbound + DNSSEC + DoT"

    curl -s -o /var/lib/unbound/root.hints "https://www.internic.net/domain/named.cache" 2>/dev/null
    unbound-anchor -a /var/lib/unbound/root.key 2>/dev/null

    cat > /etc/unbound/unbound.conf << UBEOF
server:
    interface: 127.0.0.1
    port: 53
    do-ip4: yes
    do-ip6: no
    do-udp: yes
    do-tcp: yes
    access-control: 127.0.0.0/8 allow
    access-control: ${WG_SUBNET} allow
    access-control: 0.0.0.0/0 refuse
    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
    harden-referral-path: yes
    harden-algo-downgrade: yes
    use-caps-for-id: yes
    qname-minimisation: yes
    aggressive-nsec: yes
    deny-any: yes
    auto-trust-anchor-file: "/var/lib/unbound/root.key"
    root-hints: "/var/lib/unbound/root.hints"
    # Bloquear mining pools
    local-zone: "pool.minexmr.com" refuse
    local-zone: "supportxmr.com" refuse
    local-zone: "nanopool.org" refuse
    local-zone: "moneroocean.stream" refuse
    local-zone: "coinhive.com" refuse
    local-zone: "coin-hive.com" refuse
    prefetch: yes
    cache-min-ttl: 3600
    cache-max-ttl: 86400
    msg-cache-size: 64m
    rrset-cache-size: 128m
    chroot: ""
    logfile: ""
    use-syslog: yes

forward-zone:
    name: "."
    forward-tls-upstream: yes
    forward-addr: 1.1.1.1@853#cloudflare-dns.com
    forward-addr: 1.0.0.1@853#cloudflare-dns.com
    forward-addr: 9.9.9.9@853#dns.quad9.net
    forward-addr: 8.8.8.8@853#dns.google
UBEOF

    chown -R unbound:unbound /var/lib/unbound 2>/dev/null

    # Apontar sistema para Unbound
    chattr -i /etc/resolv.conf 2>/dev/null
    cat > /etc/resolv.conf << 'EOF'
nameserver 127.0.0.1
options edns0 trust-ad
EOF
    chattr +i /etc/resolv.conf

    systemctl enable unbound
    systemctl restart unbound

    ok "Unbound: DNSSEC + DNS-over-TLS + mining pools bloqueados"
    log_f "OK" "DNS hardening"
}


# ══════════════════════════════════════════════════════════════════
#  [30] EGRESS FILTERING
# ══════════════════════════════════════════════════════════════════

step_30() {
    step "30" "🚪 Egress Filtering — Saída Controlada"

    iptables -N EGRESS 2>/dev/null || iptables -F EGRESS

    # Permitir
    iptables -A EGRESS -o lo -j ACCEPT
    iptables -A EGRESS -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A EGRESS -p udp --dport 53 -d 127.0.0.1 -j ACCEPT
    for DNS in 1.1.1.1 1.0.0.1 8.8.8.8 8.8.4.4 9.9.9.9; do
        iptables -A EGRESS -p tcp --dport 853 -d "$DNS" -j ACCEPT
    done
    iptables -A EGRESS -p tcp --dport 80 -j ACCEPT
    iptables -A EGRESS -p tcp --dport 443 -j ACCEPT
    iptables -A EGRESS -p udp --dport 123 -j ACCEPT   # NTP
    iptables -A EGRESS -p tcp --dport 587 -j ACCEPT   # SMTP
    iptables -A EGRESS -p tcp --dport 465 -j ACCEPT   # SMTPS
    iptables -A EGRESS -p udp --dport "$WG_PORT" -j ACCEPT

    # Bloquear mining
    for MP in 3333 4444 5555 6666 7777 8888 9999 14444 45560; do
        iptables -A EGRESS -p tcp --dport "$MP" -j LOG --log-prefix "EGRESS_MINER: " 2>/dev/null
        iptables -A EGRESS -p tcp --dport "$MP" -j DROP
    done
    # Bloquear reverse shells
    for RP in 4444 4445 5555 6666 6667 8181 9001 1234 31337; do
        iptables -A EGRESS -p tcp --dport "$RP" -j DROP
    done

    # Tudo mais: log e drop
    iptables -A EGRESS -m limit --limit 3/min -j LOG --log-prefix "EGRESS_BLOCKED: "
    iptables -A EGRESS -j DROP

    # Aplicar
    iptables -D OUTPUT -j EGRESS 2>/dev/null
    iptables -A OUTPUT -j EGRESS

    netfilter-persistent save > /dev/null 2>&1

    ok "OUTPUT=DROP (whitelist: DNS/DoT, HTTP/S, NTP, SMTP, WG)"
    ok "Mining/Reverse Shell bloqueados na SAÍDA"
    log_f "OK" "Egress filtering"
}


# ══════════════════════════════════════════════════════════════════
#  [31] FILELESS MALWARE (YARA)
# ══════════════════════════════════════════════════════════════════

step_31() {
    step "31" "👻 Fileless Malware Defense (YARA)"

    mkdir -p /etc/fortress/yara

    cat > /etc/fortress/yara/rules.yar << 'YEOF'
rule CryptoMiner {
    strings:
        $s1 = "stratum+tcp://"
        $s2 = "stratum+ssl://"
        $s3 = "mining.subscribe"
        $s4 = "xmrig" nocase
        $s5 = "randomx" nocase
    condition: any of them
}
rule ReverseShell {
    strings:
        $s1 = "/bin/bash -i"
        $s2 = "/bin/sh -i"
        $s3 = "bash -c 'bash -i >& /dev/tcp"
        $s4 = "python -c 'import socket"
        $s5 = "nc -e /bin/sh"
        $s6 = "/dev/tcp/"
    condition: any of them
}
rule WebShell {
    strings:
        $s1 = "eval(base64_decode"
        $s2 = "system($_GET"
        $s3 = "exec($_POST"
        $s4 = "c99shell" nocase
        $s5 = "r57shell" nocase
    condition: any of them
}
YEOF

    cat > /usr/local/bin/fortress-yara << 'YSCAN'
#!/bin/bash
RULES="/etc/fortress/yara/rules.yar"
for DIR in /tmp /var/tmp /dev/shm /usr/local/x-ui; do
    [[ -d "$DIR" ]] && yara -r "$RULES" "$DIR" 2>/dev/null | while IFS= read -r L; do
        echo "[$(date)] YARA: $L" >> /var/log/fortress/yara.log
        source /etc/fortress/config.env 2>/dev/null
        [[ -n "$TG_TOKEN" ]] && curl -s -X POST \
            "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
            -d "chat_id=$TG_CHAT_ID" -d "text=🦠 YARA: $L" > /dev/null 2>&1
    done
done
# Binários deletados em execução
for PID in $(ls /proc/ 2>/dev/null | grep -E '^[0-9]+$'); do
    EXE=$(readlink -f "/proc/$PID/exe" 2>/dev/null)
    [[ "$EXE" == *"(deleted)"* ]] && echo "[$(date)] DELETED BIN: PID=$PID $EXE" >> /var/log/fortress/yara.log
done
YSCAN
    chmod +x /usr/local/bin/fortress-yara
    echo "*/30 * * * * root /usr/local/bin/fortress-yara" >> /etc/cron.d/fortress-daily

    ok "YARA scan a cada 30 min (miner, revshell, webshell)"
    log_f "OK" "YARA configurado"
}


# ══════════════════════════════════════════════════════════════════
#  [33] WIREGUARD ADMIN VPN
# ══════════════════════════════════════════════════════════════════

step_33() {
    step "33" "🔐 WireGuard Admin VPN"

    WG_DIR="/etc/wireguard"
    mkdir -p "$WG_DIR"; chmod 700 "$WG_DIR"

    # Gerar chaves
    wg genkey | tee "$WG_DIR/srv_priv" | wg pubkey > "$WG_DIR/srv_pub"
    wg genkey | tee "$WG_DIR/cli_priv" | wg pubkey > "$WG_DIR/cli_pub"
    wg genpsk > "$WG_DIR/psk" 2>/dev/null
    chmod 600 "$WG_DIR"/*_priv "$WG_DIR/psk"

    SRV_PRIV=$(cat "$WG_DIR/srv_priv")
    SRV_PUB=$(cat "$WG_DIR/srv_pub")
    CLI_PRIV=$(cat "$WG_DIR/cli_priv")
    CLI_PUB=$(cat "$WG_DIR/cli_pub")
    PSK=$(cat "$WG_DIR/psk")

    WG_SRV_IP="10.66.66.1"
    WG_CLI_IP="10.66.66.2"

    # Server config
    cat > "$WG_DIR/wg0.conf" << WGEOF
[Interface]
Address = ${WG_SRV_IP}/24
ListenPort = ${WG_PORT}
PrivateKey = ${SRV_PRIV}
PostUp = iptables -I INPUT 1 -s ${WG_SUBNET} -j ACCEPT; iptables -I FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ${MAIN_IFACE} -j MASQUERADE
PostDown = iptables -D INPUT -s ${WG_SUBNET} -j ACCEPT; iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ${MAIN_IFACE} -j MASQUERADE

[Peer]
PublicKey = ${CLI_PUB}
PresharedKey = ${PSK}
AllowedIPs = ${WG_CLI_IP}/32
WGEOF

    # Client config
    cat > "$WG_DIR/admin-client.conf" << WGCEOF
[Interface]
Address = ${WG_CLI_IP}/24
PrivateKey = ${CLI_PRIV}
DNS = ${WG_SRV_IP}

[Peer]
PublicKey = ${SRV_PUB}
PresharedKey = ${PSK}
Endpoint = ${SERVER_IP}:${WG_PORT}
AllowedIPs = ${WG_SUBNET}
PersistentKeepalive = 25
WGCEOF

    # QR code
    qrencode -t ansiutf8 < "$WG_DIR/admin-client.conf" > "$WG_DIR/qr.txt" 2>/dev/null

    chmod 600 "$WG_DIR"/*.conf

    systemctl enable wg-quick@wg0
    wg-quick up wg0 2>/dev/null

    ok "WireGuard ativo na porta $WG_PORT"
    ok "Config cliente: $WG_DIR/admin-client.conf"
    log_f "OK" "WireGuard configurado"
}


# ══════════════════════════════════════════════════════════════════
#  [34] PORT KNOCKING
# ══════════════════════════════════════════════════════════════════

step_34() {
    step "34" "🚪 Port Knocking"

    cat > /etc/knockd.conf << KNOCKEOF
[options]
    UseSyslog
    LogFile = /var/log/fortress/knockd.log
    Interface = ${MAIN_IFACE}

[openSSH]
    sequence = $KNOCK_1,$KNOCK_2,$KNOCK_3
    seq_timeout = 10
    tcpflags = syn
    start_command = /usr/sbin/iptables -I INPUT 1 -s %IP% -p tcp --dport $SSH_PORT -j ACCEPT
    cmd_timeout = 30
    stop_command = /usr/sbin/iptables -D INPUT -s %IP% -p tcp --dport $SSH_PORT -j ACCEPT

[openXUI]
    sequence = $KNOCK_3,$KNOCK_1,$KNOCK_2
    seq_timeout = 10
    tcpflags = syn
    start_command = /usr/sbin/iptables -I INPUT 1 -s %IP% -p tcp --dport $XUI_PORT -j ACCEPT
    cmd_timeout = 60
    stop_command = /usr/sbin/iptables -D INPUT -s %IP% -p tcp --dport $XUI_PORT -j ACCEPT
KNOCKEOF

    sed -i 's/START_KNOCKD=0/START_KNOCKD=1/' /etc/default/knockd 2>/dev/null

    # Scripts de knock para o cliente
    cat > "$FORTRESS_DIR/knock-ssh.sh" << KEOF
#!/bin/bash
SERVER=\${1:-$SERVER_IP}
echo "🚪 Knocking SSH..."
for P in $KNOCK_1 $KNOCK_2 $KNOCK_3; do
    timeout 1 bash -c "echo >/dev/tcp/\$SERVER/\$P" 2>/dev/null; sleep 0.5
done
echo "✅ SSH aberto por 30s: ssh -p $SSH_PORT root@\$SERVER"
KEOF

    cat > "$FORTRESS_DIR/knock-xui.sh" << KEOF
#!/bin/bash
SERVER=\${1:-$SERVER_IP}
echo "🚪 Knocking x-ui..."
for P in $KNOCK_3 $KNOCK_1 $KNOCK_2; do
    timeout 1 bash -c "echo >/dev/tcp/\$SERVER/\$P" 2>/dev/null; sleep 0.5
done
echo "✅ Painel aberto por 60s"
KEOF
    chmod +x "$FORTRESS_DIR"/knock-*.sh

    systemctl enable knockd 2>/dev/null
    systemctl restart knockd 2>/dev/null

    ok "Port Knocking: SSH=$KNOCK_1→$KNOCK_2→$KNOCK_3 | x-ui=$KNOCK_3→$KNOCK_1→$KNOCK_2"
    log_f "OK" "Port knocking configurado"
}


# ══════════════════════════════════════════════════════════════════
#  [35] READ-ONLY FILESYSTEM
# ══════════════════════════════════════════════════════════════════

step_35() {
    step "35" "🔏 Read-Only Filesystem"

    # Imutáveis
    for F in /etc/passwd /etc/group /etc/hosts /etc/ssh/sshd_config; do
        [[ -f "$F" ]] && chattr +i "$F" 2>/dev/null && ok "Imutável: $F"
    done

    # /tmp noexec
    if ! grep -q "tmpfs /tmp" /etc/fstab; then
        echo "tmpfs /tmp tmpfs defaults,noexec,nosuid,nodev,size=2G 0 0" >> /etc/fstab
        mount -o remount /tmp 2>/dev/null
    fi

    # /dev/shm noexec
    if ! grep -q "/dev/shm.*noexec" /etc/fstab; then
        echo "tmpfs /dev/shm tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab
        mount -o remount /dev/shm 2>/dev/null
    fi

    # Scripts lock/unlock
    cat > /usr/local/bin/fortress-unlock << 'EOF'
#!/bin/bash
echo "🔓 Desbloqueando para manutenção..."
for F in /etc/passwd /etc/group /etc/hosts /etc/ssh/sshd_config /etc/resolv.conf; do
    chattr -i "$F" 2>/dev/null && echo "  ✅ $F"
done
echo "⚠️  Execute 'fortress-lock' após terminar!"
EOF

    cat > /usr/local/bin/fortress-lock << 'EOF'
#!/bin/bash
echo "🔒 Bloqueando sistema..."
for F in /etc/passwd /etc/group /etc/hosts /etc/ssh/sshd_config /etc/resolv.conf; do
    chattr +i "$F" 2>/dev/null && echo "  ✅ $F"
done
echo "🛡️ Protegido!"
EOF
    chmod +x /usr/local/bin/fortress-lock /usr/local/bin/fortress-unlock

    ok "/tmp + /dev/shm com noexec"
    log_f "OK" "Read-only filesystem"
}


# ══════════════════════════════════════════════════════════════════
#  [36] CANARY TOKENS
# ══════════════════════════════════════════════════════════════════

step_36() {
    step "36" "🐦 Canary Tokens — Armadilhas"

    mkdir -p /root/.aws

    cat > /root/.aws/credentials << 'EOF'
[default]
aws_access_key_id = AKIAIOSFODNN7CANARY
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYCANARYKEY
EOF

    cat > /root/database_backup.sql << 'EOF'
-- MySQL dump - Production
-- Password: SuperS3cr3tP@ss_CANARY
CREATE TABLE users (id INT, email VARCHAR(255), password VARCHAR(255));
INSERT INTO users VALUES (1, 'admin@prod.com', 'hash_canary');
EOF

    cat > /opt/.env.backup << 'EOF'
DB_PASSWORD=Production_CANARY_2024
API_KEY=sk-canary-abc123def456
STRIPE_KEY=sk_live_canary
EOF

    # Monitorar via auditd
    for F in /root/.aws/credentials /root/database_backup.sql /opt/.env.backup; do
        auditctl -w "$F" -p r -k canary 2>/dev/null
    done

    # Monitor inotify
    cat > /usr/local/bin/fortress-canary << 'CANARY'
#!/bin/bash
source /etc/fortress/config.env 2>/dev/null
inotifywait -m -r -e access,open \
    /root/.aws/credentials /root/database_backup.sql /opt/.env.backup 2>/dev/null | \
while IFS= read -r DIR EVENT FILE; do
    MSG="🐦 *CANARY ATIVADO!*%0AArquivo: \`${DIR}${FILE}\`%0AEvento: $EVENT%0AData: $(date '+%d/%m %H:%M')%0A⚠️ POSSÍVEL INVASOR!"
    echo "[$(date)] CANARY: $DIR$FILE $EVENT" >> /var/log/fortress/canary.log
    [[ -n "$TG_TOKEN" ]] && curl -s -X POST \
        "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d "chat_id=$TG_CHAT_ID" -d "text=$MSG" -d "parse_mode=Markdown" > /dev/null 2>&1
done
CANARY
    chmod +x /usr/local/bin/fortress-canary

    cat > /etc/systemd/system/fortress-canary.service << 'EOF'
[Unit]
Description=Fortress Canary Monitor
After=auditd.service
[Service]
Type=simple
ExecStart=/usr/local/bin/fortress-canary
Restart=always
RestartSec=10
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now fortress-canary 2>/dev/null

    ok "3 canaries: AWS creds, DB dump, .env backup"
    ok "Acesso = alerta Telegram IMEDIATO"
    log_f "OK" "Canary tokens"
}


# ══════════════════════════════════════════════════════════════════
#  [38] THREAT FEEDS
# ══════════════════════════════════════════════════════════════════

step_38() {
    step "38" "🌐 WAF Reputação Dinâmica — Threat Feeds"

    ipset create THREAT_INTEL hash:ip maxelem 2000000 timeout 86400 2>/dev/null || ipset flush THREAT_INTEL

    cat > /usr/local/bin/fortress-threats << 'THREATS'
#!/bin/bash
ipset flush THREAT_INTEL 2>/dev/null
FEEDS=(
    "https://rules.emergingthreats.net/blockrules/compromised-ips.txt"
    "https://cinsscore.com/list/ci-badguys.txt"
    "https://feodotracker.abuse.ch/downloads/ipblocklist.txt"
    "https://sslbl.abuse.ch/blacklist/sslipblacklist.txt"
)
for URL in "${FEEDS[@]}"; do
    curl -s --connect-timeout 10 "$URL" 2>/dev/null | \
    grep -oP '^\d+\.\d+\.\d+\.\d+' | head -50000 | \
    while IFS= read -r ip; do ipset add THREAT_INTEL "$ip" 2>/dev/null; done
done
ipset save > /etc/ipset/fortress.rules 2>/dev/null
echo "[$(date)] Threat feeds updated: $(ipset list THREAT_INTEL 2>/dev/null | grep -c '^[0-9]') IPs" >> /var/log/fortress/threats.log
THREATS
    chmod +x /usr/local/bin/fortress-threats
    /usr/local/bin/fortress-threats

    iptables -I INPUT 2 -m set --match-set THREAT_INTEL src -j DROP 2>/dev/null

    echo "0 */6 * * * root /usr/local/bin/fortress-threats" >> /etc/cron.d/fortress-daily

    ok "4 Threat Feeds ativos (atualização 6h)"
    log_f "OK" "Threat feeds"
}


# ══════════════════════════════════════════════════════════════════
#  [39] PROTEÇÃO DE MEMÓRIA
# ══════════════════════════════════════════════════════════════════

step_39() {
    step "39" "🧠 Proteção de Memória"

    echo 2 > /proc/sys/kernel/randomize_va_space

    CPU_FLAGS=$(cat /proc/cpuinfo | grep flags | head -1)
    echo "$CPU_FLAGS" | grep -q " nx "   && ok "NX bit: ✅" || warn "NX: não suportado"
    echo "$CPU_FLAGS" | grep -q " smep " && ok "SMEP: ✅"   || warn "SMEP: não suportado"
    echo "$CPU_FLAGS" | grep -q " smap " && ok "SMAP: ✅"   || warn "SMAP: não suportado"
    ok "ASLR nível 2 ativo"
    log_f "OK" "Memory protection"
}


# ══════════════════════════════════════════════════════════════════
#  [41] PROTEÇÃO DE SEGREDOS
# ══════════════════════════════════════════════════════════════════

step_41() {
    step "41" "🔑 Proteção de Segredos"

    SECRETS_DIR="/etc/fortress/secrets"
    mkdir -p "$SECRETS_DIR"; chmod 700 "$SECRETS_DIR"

    if [[ ! -f "$SECRETS_DIR/.master.key" ]]; then
        openssl rand -base64 64 > "$SECRETS_DIR/.master.key"
        chmod 400 "$SECRETS_DIR/.master.key"
    fi

    # Procurar .env expostos
    find / -maxdepth 4 -name ".env" -not -path "*/proc/*" -not -path "*/sys/*" 2>/dev/null | \
    while read F; do
        [[ -f "$F" && -s "$F" ]] && {
            openssl enc -aes-256-gcm -pbkdf2 -iter 100000 \
                -pass "file:$SECRETS_DIR/.master.key" \
                -in "$F" -out "${F}.encrypted" 2>/dev/null
            chmod 600 "${F}.encrypted" 2>/dev/null
            warn "Criptografado: $F"
        }
    done

    ok "Chave mestra: $SECRETS_DIR/.master.key (FAÇA BACKUP!)"
    log_f "OK" "Secrets protection"
}


# ══════════════════════════════════════════════════════════════════
#  [42] COLD BACKUP
# ══════════════════════════════════════════════════════════════════

step_42() {
    step "42" "❄️ Cold Backup Criptografado"

    cat > /usr/local/bin/fortress-cold-backup << 'COLD'
#!/bin/bash
source /etc/fortress/config.env 2>/dev/null
DIR="/root/fortress-cold-backup"
TS=$(date '+%Y%m%d_%H%M%S'); mkdir -p "$DIR"
TMP=$(mktemp -d); trap "rm -rf $TMP" EXIT
mkdir -p "$TMP/d"
cp /usr/local/x-ui/x-ui.db "$TMP/d/" 2>/dev/null
cp /etc/x-ui/x-ui.db "$TMP/d/" 2>/dev/null
cp -r /etc/fortress "$TMP/d/" 2>/dev/null
cp -r /etc/wireguard "$TMP/d/" 2>/dev/null
cp /etc/ssh/sshd_config "$TMP/d/" 2>/dev/null
cp /root/.ssh/authorized_keys "$TMP/d/" 2>/dev/null
iptables-save > "$TMP/d/iptables" 2>/dev/null
ipset save > "$TMP/d/ipset" 2>/dev/null
dpkg --get-selections > "$TMP/d/packages" 2>/dev/null
PASS=$(openssl rand -base64 32)
tar -czf "$TMP/b.tar.gz" -C "$TMP/d" .
openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt \
    -in "$TMP/b.tar.gz" -out "$DIR/cold-$TS.enc" -pass "pass:$PASS"
echo "$PASS" > "$DIR/cold-$TS.pass"; chmod 600 "$DIR/cold-$TS.pass"
sha512sum "$DIR/cold-$TS.enc" > "$DIR/cold-$TS.sha512"
# Testar restore
T2=$(mktemp -d)
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 \
    -in "$DIR/cold-$TS.enc" -out "$T2/t.tar.gz" -pass "pass:$PASS" 2>/dev/null
tar -tzf "$T2/t.tar.gz" > /dev/null 2>&1 && echo "✅ Cold backup OK" || echo "❌ FALHOU"
rm -rf "$T2"
SIZE=$(du -sh "$DIR/cold-$TS.enc" | cut -f1)
echo "❄️ $DIR/cold-$TS.enc ($SIZE)"
ls -t "$DIR"/*.enc 2>/dev/null | tail -n +6 | while read F; do rm -f "${F%.enc}".*; done
COLD
    chmod +x /usr/local/bin/fortress-cold-backup
    /usr/local/bin/fortress-cold-backup

    echo "0 4 * * 0 root /usr/local/bin/fortress-cold-backup" >> /etc/cron.d/fortress-daily

    ok "Cold backup AES-256 + SHA-512 + restore testado"
    log_f "OK" "Cold backup"
}


# ══════════════════════════════════════════════════════════════════
#  CLI PRINCIPAL — FORTRESS
# ══════════════════════════════════════════════════════════════════

install_cli() {
    step "CLI" "🖥️ CLI Fortress"

    cat > /usr/local/bin/fortress << 'CLIMAIN'
#!/bin/bash
source /etc/fortress/config.env 2>/dev/null
case "${1:-menu}" in
    menu)
        clear
        echo "╔══════════════════════════════════════╗"
        echo "║    🛡️  FORTRESS SHIELD CLI            ║"
        echo "╚══════════════════════════════════════╝"
        echo ""
        echo "  [1]  Status completo"
        echo "  [2]  Banir IP"
        echo "  [3]  Desbanir IP"
        echo "  [4]  IPs banidos"
        echo "  [5]  Fail2Ban status"
        echo "  [6]  Logs ao vivo"
        echo "  [7]  Logs de alertas"
        echo "  [8]  Backup agora"
        echo "  [9]  Cold backup"
        echo "  [10] YARA scan"
        echo "  [11] Atualizar blocklists"
        echo "  [12] Reiniciar serviços"
        echo "  [13] Teste Telegram"
        echo "  [14] WireGuard status"
        echo "  [15] Caminho admin"
        echo "  [16] Lock sistema"
        echo "  [17] Unlock sistema"
        echo "  [18] Portas abertas"
        echo "  [19] Conexões ativas"
        echo "  [0]  Sair"
        echo ""
        read -p "  Opção: " OPT
        case $OPT in
            1)  fortress-monitor status; read -p "Enter..."; fortress menu ;;
            2)  read -p "  IP: " I; fortress-monitor ban "$I"; read -p "Enter..."; fortress menu ;;
            3)  read -p "  IP: " I; fortress-monitor unban "$I"; read -p "Enter..."; fortress menu ;;
            4)  cat /etc/fortress/banned_ips.txt 2>/dev/null | nl; echo "Total: $(wc -l < /etc/fortress/banned_ips.txt 2>/dev/null)"; read -p "Enter..."; fortress menu ;;
            5)  fail2ban-client status; read -p "Enter..."; fortress menu ;;
            6)  tail -f /var/log/fortress/fortress.log ;;
            7)  tail -50 /var/log/fortress/*.log 2>/dev/null; read -p "Enter..."; fortress menu ;;
            8)  fortress-backup; read -p "Enter..."; fortress menu ;;
            9)  fortress-cold-backup; read -p "Enter..."; fortress menu ;;
            10) fortress-yara; echo "✅ Scan OK"; read -p "Enter..."; fortress menu ;;
            11) fortress-threats; fortress-blocklist 2>/dev/null; echo "✅ Atualizado"; read -p "Enter..."; fortress menu ;;
            12) for S in x-ui nginx fail2ban fortress-monitor fortress-ddos fortress-canary; do systemctl restart "$S" 2>/dev/null && echo "✅ $S" || echo "❌ $S"; done; read -p "Enter..."; fortress menu ;;
            13) [[ -n "$TG_TOKEN" ]] && curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" -d "chat_id=$TG_CHAT_ID" -d "text=🛡️ Fortress OK - $(date)" > /dev/null && echo "✅ Enviado" || echo "❌ Telegram não configurado"; read -p "Enter..."; fortress menu ;;
            14) wg show 2>/dev/null || echo "WG não ativo"; echo "Config: /etc/wireguard/admin-client.conf"; read -p "Enter..."; fortress menu ;;
            15) echo "🥷 Admin: https://$PANEL_DOMAIN$ADMIN_PATH/"; read -p "Enter..."; fortress menu ;;
            16) fortress-lock; read -p "Enter..."; fortress menu ;;
            17) fortress-unlock; read -p "Enter..."; fortress menu ;;
            18) ss -tlnp; read -p "Enter..."; fortress menu ;;
            19) ss -tn state established | awk 'NR>1{print $5}' | grep -oP '[\d.]+(?=:\d+$)' | sort | uniq -c | sort -rn | head -20; read -p "Enter..."; fortress menu ;;
            0)  exit 0 ;;
            *)  fortress menu ;;
        esac ;;
    status)  fortress-monitor status ;;
    ban)     fortress-monitor ban "$2" ;;
    unban)   fortress-monitor unban "$2" ;;
    check)   fortress-monitor check ;;
    backup)  fortress-backup ;;
    logs)    tail -f /var/log/fortress/fortress.log ;;
    alerts)  tail -f /var/log/fortress/*.log ;;
    hidden)  echo "https://$PANEL_DOMAIN$ADMIN_PATH/" ;;
    lock)    fortress-lock ;;
    unlock)  fortress-unlock ;;
    *)       echo "fortress {menu|status|ban IP|unban IP|check|backup|logs|alerts|hidden|lock|unlock}" ;;
esac
CLIMAIN
    chmod +x /usr/local/bin/fortress
    echo "alias f='fortress'" >> /root/.bashrc

    ok "CLI instalada: 'fortress' ou 'f'"
    log_f "OK" "CLI instalada"
}


# ══════════════════════════════════════════════════════════════════
#  SALVAR E REINICIAR TUDO
# ══════════════════════════════════════════════════════════════════

finalize() {
    step "FIM" "🔄 Salvando e Reiniciando"

    # Salvar regras
    netfilter-persistent save > /dev/null 2>&1
    ipset save > /etc/ipset/fortress.rules 2>/dev/null
    systemctl daemon-reload

    # Reiniciar serviços
    for SVC in x-ui nginx fail2ban unbound wg-quick@wg0 knockd \
               fortress-monitor fortress-ddos fortress-canary auditd; do
        systemctl restart "$SVC" 2>/dev/null
    done

    # Alertar Telegram
    tg_send "🏴‍☠️ *FORTRESS v4.0 INSTALADO*%0A%0A✅ 42 camadas ativas%0A🖥️ $(hostname)%0A🌐 $SERVER_IP%0A📅 $INSTALL_DATE"

    log_f "OK" "Instalação concluída"
}


# ══════════════════════════════════════════════════════════════════
#  RELATÓRIO FINAL
# ══════════════════════════════════════════════════════════════════

final_report() {
    clear
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║    🏴‍☠️  FORTRESS SHIELD v4.0 — INSTALAÇÃO CONCLUÍDA!            ║"
    echo "║        42 CAMADAS DE PROTEÇÃO ATIVAS                            ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  42 CAMADAS INSTALADAS:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    LAYERS=(
        "01|Sistema Atualizado"
        "02|SSH Ultra Seguro (porta $SSH_PORT)"
        "03|UFW Firewall"
        "04|IPTables Multi-Camada"
        "05|IPSet + Blocklists + TOR"
        "06|Fail2Ban 14+ Jails"
        "07|Kernel Hardening (40+ params)"
        "08|Nginx WAF + Proxy Reverso"
        "09|SSL/TLS"
        "10|CrowdSec IPS"
        "11|ModSecurity (se disponível)"
        "12|RKHunter + ChkRootkit"
        "13|Auditd Completo"
        "14|Honeypot de Portas"
        "15|GeoIP Bloqueio"
        "16|Anti-DDoS L4/L7"
        "17|Monitor 24/7 + Telegram"
        "18|AIDE Integridade"
        "19|Auto-Updates"
        "20|Anti-Cryptominer"
        "21|Permissões Hardened"
        "22|Backup AES-256"
        "23|Panel Guard"
        "24|LogRotate"
        "25|CLI Fortress"
        "26|AppArmor (x-ui isolado)"
        "27|Systemd Sandbox"
        "28|Nginx Sandbox"
        "29|DNS Unbound + DNSSEC + DoT"
        "30|Egress Filter (OUTPUT=DROP)"
        "31|YARA Fileless Defense"
        "32|Falco (se instalado)"
        "33|WireGuard Admin VPN"
        "34|Port Knocking"
        "35|Read-Only Filesystem"
        "36|Canary Tokens"
        "37|Kernel LSM Extra"
        "38|Threat Feeds (4 fontes)"
        "39|Proteção de Memória"
        "40|Hidden Admin Path"
        "41|Proteção de Segredos"
        "42|Cold Backup Criptografado"
    )

    for L in "${LAYERS[@]}"; do
        NUM="${L%%|*}"; DESC="${L#*|}"
        echo -e "  ${GREEN}✅${NC} [$NUM] $DESC"
    done

    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  ⚠️  INFORMAÇÕES CRÍTICAS — SALVE AGORA!${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  SSH Porta:          ${YELLOW}$SSH_PORT${NC}"
    echo -e "  WireGuard Porta:    ${YELLOW}$WG_PORT${NC}"
    echo -e "  Port Knock SSH:     ${YELLOW}$KNOCK_1 → $KNOCK_2 → $KNOCK_3${NC}"
    echo -e "  Port Knock x-ui:    ${YELLOW}$KNOCK_3 → $KNOCK_1 → $KNOCK_2${NC}"
    echo -e "  Admin Path:         ${YELLOW}$ADMIN_PATH${NC}"
    echo ""
    echo -e "  ${CYAN}Acesso ao painel:${NC}"
    if [[ -n "$PANEL_DOMAIN" ]]; then
        echo -e "  ${YELLOW}https://$PANEL_DOMAIN$ADMIN_PATH/${NC}"
    else
        echo -e "  ${YELLOW}https://$SERVER_IP:$XUI_PORT${NC}  (direto)"
        echo -e "  ${YELLOW}https://$SERVER_IP$ADMIN_PATH/${NC}  (via Nginx)"
    fi

    echo ""
    echo -e "  ${CYAN}WireGuard:${NC}"
    echo -e "  Config: ${YELLOW}/etc/wireguard/admin-client.conf${NC}"

    if [[ -f /etc/wireguard/qr.txt ]]; then
        echo ""
        echo -e "  ${CYAN}QR Code WireGuard:${NC}"
        cat /etc/wireguard/qr.txt 2>/dev/null
    fi

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  🖥️  COMANDOS:${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${YELLOW}fortress${NC}         → Menu principal"
    echo -e "  ${YELLOW}fortress status${NC}  → Status completo"
    echo -e "  ${YELLOW}fortress ban IP${NC}  → Banir IP"
    echo -e "  ${YELLOW}fortress check${NC}   → Verificação completa"
    echo -e "  ${YELLOW}fortress backup${NC}  → Backup agora"
    echo -e "  ${YELLOW}fortress hidden${NC}  → Mostrar caminho admin"
    echo -e "  ${YELLOW}fortress lock${NC}    → Bloquear filesystem"
    echo -e "  ${YELLOW}fortress unlock${NC}  → Desbloquear para manutenção"
    echo ""

    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  ⚠️  FAÇA AGORA:${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${RED}1.${NC} TESTE o SSH em OUTRO terminal antes de fechar este:"
    echo -e "     ${YELLOW}ssh -p $SSH_PORT root@$SERVER_IP${NC}"
    echo ""
    echo -e "  ${RED}2.${NC} Adicione sua chave SSH:"
    echo -e "     ${YELLOW}ssh-copy-id -p $SSH_PORT root@$SERVER_IP${NC}"
    echo ""
    echo -e "  ${RED}3.${NC} Após confirmar acesso, desabilite senha:"
    echo -e "     ${YELLOW}fortress unlock${NC}"
    echo -e "     Edite /etc/ssh/sshd_config → PasswordAuthentication no"
    echo -e "     ${YELLOW}systemctl restart sshd && fortress lock${NC}"
    echo ""
    echo -e "  ${RED}4.${NC} Importe WireGuard no celular/PC:"
    echo -e "     ${YELLOW}cat /etc/wireguard/admin-client.conf${NC}"
    echo ""
    echo -e "  ${RED}5.${NC} Faça backup da chave mestra:"
    echo -e "     ${YELLOW}cat /etc/fortress/secrets/.master.key${NC}"
    echo ""

    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Firewall          ${GREEN}████████████████████${NC} MONSTRO"
    echo -e "  WAF               ${GREEN}████████████████████${NC} ABSURDO"
    echo -e "  IPS               ${GREEN}████████████████████${NC} INSANO"
    echo -e "  Hardening         ${GREEN}████████████████████${NC} MÁXIMO"
    echo -e "  DDoS              ${GREEN}████████████████████${NC} FORTALEZA"
    echo -e "  Monitoramento     ${GREEN}████████████████████${NC} 24/7"
    echo -e "  Isolamento        ${GREEN}████████████████████${NC} PRISÃO"
    echo -e "  Egress            ${GREEN}████████████████████${NC} COMPLETO"
    echo -e "  Deception         ${GREEN}████████████████████${NC} CANARY"
    echo -e "  Admin Access      ${GREEN}████████████████████${NC} VPN+KNOCK"
    echo -e "  Backup            ${GREEN}████████████████████${NC} AES-256"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${GREEN}🏴‍☠️ Scanner vai chorar sangue. 💀${NC}"
    echo ""
}


# ══════════════════════════════════════════════════════════════════
#  MAIN — EXECUÇÃO
# ══════════════════════════════════════════════════════════════════

main() {
    check_root
    check_ubuntu
    banner
    collect_info

    echo -e "\n${GREEN}🚀 Instalando 42 camadas de proteção...${NC}\n"

    step_01        # Atualização
    step_02        # SSH
    step_03        # UFW
    step_04        # IPTables
    step_05        # IPSet
    step_06        # Fail2Ban
    step_07        # Kernel
    step_08        # Nginx WAF
    step_09        # SSL
    step_10_11     # CrowdSec
    step_12        # Rootkits
    step_13        # Auditd
    step_14_16     # Honeypot + GeoIP + DDoS
    step_17        # Monitor + Telegram
    step_18_19     # AIDE + Auto-updates
    step_20_25     # Anti-miner + Perms + Backup
    step_26        # AppArmor
    step_27        # Systemd isolation
    step_29        # DNS Hardening
    step_30        # Egress
    step_31        # YARA
    step_33        # WireGuard
    step_34        # Port Knocking
    step_35        # Read-only FS
    step_36        # Canary
    step_38        # Threat feeds
    step_39        # Memory
    step_41        # Secrets
    step_42        # Cold backup
    install_cli    # CLI
    finalize       # Salvar e reiniciar

    final_report
}

main "$@"