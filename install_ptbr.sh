#!/bin/bash

# ============================================
# Script de Instalação x-ui em Português BR
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # Sem cor
BOLD='\033[1m'

# Verificar root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ Este script deve ser executado como root!${NC}"
        echo -e "${YELLOW}Execute: sudo bash install_ptbr.sh${NC}"
        exit 1
    fi
}

# Banner
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║                                                  ║"
    echo "║         X-UI PAINEL - INSTALADOR PT-BR           ║"
    echo "║                                                  ║"
    echo "║     Gerenciador de Proxies com Interface Web     ║"
    echo "║                                                  ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${YELLOW}Sistema: $(uname -o) $(uname -m)${NC}"
    echo -e "${YELLOW}Data: $(date '+%d/%m/%Y %H:%M:%S')${NC}"
    echo ""
}

# Verificar OS
check_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        echo -e "${RED}❌ Sistema operacional não suportado!${NC}"
        exit 1
    fi
    
    case $OS in
        ubuntu|debian)
            PKG_MANAGER="apt-get"
            ;;
        centos|rhel|fedora)
            PKG_MANAGER="yum"
            ;;
        *)
            echo -e "${RED}❌ Distribuição $OS não suportada!${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}✅ Sistema compatível: $OS $OS_VERSION${NC}"
}

# Instalar dependências
install_deps() {
    echo -e "\n${BLUE}📦 Instalando dependências...${NC}"
    
    $PKG_MANAGER update -y > /dev/null 2>&1
    $PKG_MANAGER install -y curl wget unzip tar socat > /dev/null 2>&1
    
    echo -e "${GREEN}✅ Dependências instaladas!${NC}"
}

# Baixar x-ui (Modificado para usar os arquivos locais do seu clone Git)
download_xui() {
    echo -e "\n${BLUE}📥 Preparando pacotes locais da NYX ULTRA...${NC}"
    
    # Navega até a pasta onde está o repositório clonado
    cd /root/fub
    
    # Compacta a sua estrutura modificada para o /tmp para o próximo passo ler
    tar -czf /tmp/x-ui.tar.gz .
    
    echo -e "${GREEN}✅ Pacote local estruturado com sucesso!${NC}"
}

# Instalar x-ui
install_xui() {
    echo -e "\n${BLUE}⚙️ Instalando x-ui...${NC}"
    
    # Parar serviço se existir
    if systemctl is-active x-ui > /dev/null 2>&1; then
        systemctl stop x-ui
        echo -e "${YELLOW}⚠️ Serviço x-ui parado para atualização${NC}"
    fi
    
    # Extrair
    mkdir -p /usr/local/x-ui
    tar -xzf /tmp/x-ui.tar.gz -C /usr/local/x-ui --strip-components=1
    rm -f /tmp/x-ui.tar.gz
    
    # Garante permissão nos binários internos
    chmod +x /usr/local/x-ui/x-ui 2>/dev/null || true
    chmod +x /usr/local/x-ui/bin/xray-linux-* 2>/dev/null || true
    
    # Criar serviço systemd
    cat > /etc/systemd/system/x-ui.service << EOF
[Unit]
Description=x-ui Painel de Gerenciamento
After=network.target
Wants=network.target

[Service]
Type=simple
WorkingDirectory=/usr/local/x-ui/
ExecStart=/usr/local/x-ui/x-ui
Restart=on-failure
RestartSec=5s
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    
    echo -e "${GREEN}✅ x-ui instalado e iniciado!${NC}"
}

# Configurar credenciais
configure_credentials() {
    echo -e "\n${PURPLE}🔐 Configuração de Acesso${NC}"
    echo "═══════════════════════════════════════"
    
    read -p "$(echo -e ${YELLOW})Digite o usuário do painel [padrão: admin]: $(echo -e ${NC})" USERNAME
    USERNAME=${USERNAME:-admin}
    
    while true; do
        read -s -p "$(echo -e ${YELLOW})Digite a senha do painel: $(echo -e ${NC})" PASSWORD
        echo ""
        read -s -p "$(echo -e ${YELLOW})Confirme a senha: $(echo -e ${NC})" PASSWORD2
        echo ""
        
        if [[ "$PASSWORD" == "$PASSWORD2" ]]; then
            if [[ ${#PASSWORD} -ge 6 ]]; then
                break
            else
                echo -e "${RED}❌ A senha deve ter pelo menos 6 caracteres!${NC}"
            fi
        else
            echo -e "${RED}❌ As senhas não coincidem!${NC}"
        fi
    done
    
    read -p "$(echo -e ${YELLOW})Porta do painel [padrão: 54321]: $(echo -e ${NC})" PORT
    PORT=${PORT:-54321}
    
    # Configurar no x-ui
    /usr/local/x-ui/x-ui setting -username "$USERNAME" -password "$PASSWORD" -port "$PORT" > /dev/null 2>&1
    
    systemctl restart x-ui
    
    echo -e "${GREEN}✅ Credenciais configuradas!${NC}"
}

# Configurar firewall
setup_firewall() {
    echo -e "\n${BLUE}🔥 Configurando Firewall...${NC}"
    
    if command -v ufw > /dev/null 2>&1; then
        ufw allow "$PORT"/tcp > /dev/null 2>&1
        echo -e "${GREEN}✅ UFW: Porta $PORT liberada${NC}"
    fi
    
    if command -v firewall-cmd > /dev/null 2>&1; then
        firewall-cmd --permanent --add-port="$PORT"/tcp > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
        echo -e "${GREEN}✅ FirewallD: Porta $PORT liberada${NC}"
    fi
}

# Instalar x-ui CLI
install_cli() {
    echo -e "\n${BLUE}🛠️ Instalando comando xui...${NC}"
    
    cat > /usr/local/bin/xui << 'SCRIPT'
#!/bin/bash
# Comando de gerenciamento x-ui em PT-BR

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

show_menu() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════╗"
    echo "║      GERENCIADOR x-ui PT-BR          ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
    
    STATUS=$(systemctl is-active x-ui)
    if [[ "$STATUS" == "active" ]]; then
        echo -e "  Status: ${GREEN}● Em execução${NC}"
    else
        echo -e "  Status: ${RED}● Parado${NC}"
    fi
    
    echo ""
    echo -e "  ${YELLOW}[0]${NC} Sair"
    echo -e "  ${YELLOW}[1]${NC} Instalar x-ui"
    echo -e "  ${YELLOW}[2]${NC} Desinstalar x-ui"
    echo -e "  ${YELLOW}[3]${NC} Reiniciar x-ui"
    echo -e "  ${YELLOW}[4]${NC} Ver Status"
    echo -e "  ${YELLOW}[5]${NC} Ver Logs"
    echo -e "  ${YELLOW}[6]${NC} Alterar Credenciais"
    echo -e "  ${YELLOW}[7]${NC} Alterar Porta"
    echo -e "  ${YELLOW}[8]${NC} Verificar Versão"
    echo -e "  ${YELLOW}[9]${NC} Instalar Certificado SSL"
    echo -e "  ${YELLOW}[10]${NC} Backup do Banco de Dados"
    echo ""
    read -p "Escolha uma opção: " choice
    
    case $choice in
        0) exit 0 ;;
        1) bash <(curl -Ls https://raw.githubusercontent.com/FranzKafkaYu/x-ui/master/install.sh) ;;
        2) confirm_uninstall ;;
        3) restart_service ;;
        4) show_status ;;
        5) show_logs ;;
        6) change_credentials ;;
        7) change_port ;;
        8) check_version ;;
        9) install_ssl ;;
        10) backup_db ;;
        *) echo -e "${RED}Opção inválida!${NC}" ; sleep 1 ; show_menu ;;
    esac
}

restart_service() {
    echo -e "${BLUE}🔄 Reiniciando x-ui...${NC}"
    systemctl restart x-ui
    sleep 2
    STATUS=$(systemctl is-active x-ui)
    if [[ "$STATUS" == "active" ]]; then
        echo -e "${GREEN}✅ x-ui reiniciado com sucesso!${NC}"
    else
        echo -e "${RED}❌ Falha ao reiniciar x-ui!${NC}"
    fi
    read -p "Pressione Enter para continuar..."
    show_menu
}

show_status() {
    echo -e "\n${BLUE}📊 Status do x-ui${NC}"
    echo "═══════════════════════════════════"
    systemctl status x-ui
    echo ""
    read -p "Pressione Enter para continuar..."
    show_menu
}

show_logs() {
    echo -e "\n${BLUE}📋 Logs do x-ui (Ctrl+C para sair)${NC}"
    echo "═══════════════════════════════════"
    journalctl -u x-ui -f --no-pager
    show_menu
}

change_credentials() {
    echo -e "\n${PURPLE}🔐 Alterar Credenciais${NC}"
    echo "═══════════════════════════════════"
    
    read -p "Novo usuário: " new_user
    read -s -p "Nova senha: " new_pass
    echo ""
    
    /usr/local/x-ui/x-ui setting -username "$new_user" -password "$new_pass" > /dev/null 2>&1
    systemctl restart x-ui
    
    echo -e "${GREEN}✅ Credenciais atualizadas!${NC}"
    read -p "Pressione Enter para continuar..."
    show_menu
}

change_port() {
    echo -e "\n${BLUE}🔌 Alterar Porta${NC}"
    echo "═══════════════════════════════════"
    
    read -p "Nova porta: " new_port
    
    /usr/local/x-ui/x-ui setting -port "$new_port" > /dev/null 2>&1
    systemctl restart x-ui
    
    echo -e "${GREEN}✅ Porta alterada para: $new_port${NC}"
    read -p "Pressione Enter para continuar..."
    show_menu
}

check_version() {
    echo -e "\n${BLUE}📦 Versão do x-ui${NC}"
    echo "═══════════════════════════════════"
    /usr/local/x-ui/x-ui -v
    
    LATEST=$(curl -s "https://api.github.com/repos/FranzKafkaYu/x-ui/releases/latest" | grep '"tag_name"' | cut -d'"' -f4)
    echo -e "Versão mais recente: ${GREEN}$LATEST${NC}"
    
    read -p "Pressione Enter para continuar..."
    show_menu
}

install_ssl() {
    echo -e "\n${BLUE}🔒 Instalar Certificado SSL${NC}"
    echo "═══════════════════════════════════"
    echo -e "${YELLOW}Usando acme.sh para obter certificado gratuito da Let's Encrypt${NC}"
    echo ""
    
    read -p "Digite seu domínio: " domain
    read -p "Digite seu email: " email
    
    # Instalar acme.sh
    curl -s https://get.acme.sh | bash -s email="$email" > /dev/null 2>&1
    source ~/.bashrc
    
    # Obter certificado
    ~/.acme.sh/acme.sh --issue -d "$domain" --standalone
    
    CERT_DIR="/etc/ssl/x-ui"
    mkdir -p "$CERT_DIR"
    
    ~/.acme.sh/acme.sh --install-cert -d "$domain" \
        --cert-file "$CERT_DIR/$domain.crt" \
        --key-file "$CERT_DIR/$domain.key" \
        --reloadcmd "systemctl restart x-ui"
    
    echo -e "\n${GREEN}✅ Certificado instalado!${NC}"
    echo -e "Certificado: ${YELLOW}$CERT_DIR/$domain.crt${NC}"
    echo -e "Chave: ${YELLOW}$CERT_DIR/$domain.key${NC}"
    
    read -p "Pressione Enter para continuar..."
    show_menu
}

backup_db() {
    echo -e "\n${BLUE}💾 Backup do Banco de Dados${NC}"
    echo "═══════════════════════════════════"
    
    BACKUP_DIR="/root/x-ui-backups"
    mkdir -p "$BACKUP_DIR"
    
    BACKUP_FILE="$BACKUP_DIR/x-ui-backup-$(date '+%Y%m%d-%H%M%S').db"
    
    cp /etc/x-ui/x-ui.db "$BACKUP_FILE" 2>/dev/null || \
    cp /usr/local/x-ui/x-ui.db "$BACKUP_FILE" 2>/dev/null
    
    if [[ -f "$BACKUP_FILE" ]]; then
        echo -e "${GREEN}✅ Backup salvo em: $BACKUP_FILE${NC}"
    else
        echo -e "${RED}❌ Falha ao criar backup!${NC}"
    fi
    
    read -p "Pressione Enter para continuar..."
    show_menu
}

confirm_uninstall() {
    echo -e "\n${RED}⚠️  ATENÇÃO: Desinstalar x-ui?${NC}"
    echo "Todos os dados e configurações serão excluídos!"
    read -p "Digite 'sim' para confirmar: " confirm
    
    if [[ "$confirm" == "sim" ]]; then
        systemctl stop x-ui
        systemctl disable x-ui
        rm -f /etc/systemd/system/x-ui.service
        rm -rf /usr/local/x-ui
        rm -f /usr/local/bin/xui
        systemctl daemon-reload
        echo -e "${GREEN}✅ x-ui desinstalado com sucesso!${NC}"
    else
        echo -e "${YELLOW}Operação cancelada.${NC}"
    fi
    
    exit 0
}

show_menu
SCRIPT
    
    chmod +x /usr/local/bin/xui
    echo -e "${GREEN}✅ Comando 'xui' instalado!${NC}"
}

# Mostrar informações finais
show_info() {
    IP=$(curl -s4 ifconfig.me 2>/dev/null || curl -s ip.sb 2>/dev/null)
    
    echo -e "\n${GREEN}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "