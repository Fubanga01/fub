/**
 * Tradução PT-BR para x-ui
 * Arquivo de localização para o frontend
 */

const LANG_PT_BR = {
  // ==================== GERAL ====================
  common: {
    success: "Sucesso",
    failed: "Falhou",
    error: "Erro",
    warning: "Aviso",
    confirm: "Confirmar",
    cancel: "Cancelar",
    save: "Salvar",
    delete: "Excluir",
    edit: "Editar",
    add: "Adicionar",
    search: "Pesquisar",
    reset: "Redefinir",
    submit: "Enviar",
    close: "Fechar",
    loading: "Carregando...",
    yes: "Sim",
    no: "Não",
    enable: "Ativar",
    disable: "Desativar",
    copy: "Copiar",
    copied: "Copiado!",
    refresh: "Atualizar",
    none: "Nenhum",
    unknown: "Desconhecido",
    actions: "Ações",
    status: "Status",
    total: "Total",
    enabled: "Ativo",
    disabled: "Inativo",
  },

  // ==================== MENU ====================
  menu: {
    home: "Início",
    inbounds: "Inbounds",
    xray: "Xray",
    settings: "Configurações",
    logout: "Sair",
  },

  // ==================== LOGIN ====================
  login: {
    title: "Acesso ao Painel",
    username: "Usuário",
    password: "Senha",
    login: "Entrar",
    username_placeholder: "Digite seu usuário",
    password_placeholder: "Digite sua senha",
    success: "Login realizado com sucesso!",
    failed: "Usuário ou senha incorretos!",
  },

  // ==================== DASHBOARD ====================
  dashboard: {
    title: "Painel Principal",
    system_status: "Status do Sistema",
    xray_status: "Status do Xray",
    cpu: "CPU",
    memory: "Memória",
    disk: "Disco",
    network: "Rede",
    upload: "Upload",
    download: "Download",
    uptime: "Online há",
    version: "Versão",
    running: "Em execução",
    stopped: "Parado",
    start: "Iniciar",
    stop: "Parar",
    restart: "Reiniciar",
    total_traffic: "Tráfego Total",
    online_users: "Usuários Online",
  },

  // ==================== INBOUNDS ====================
  inbound: {
    list: "Lista de Inbounds",
    add: "Adicionar Inbound",
    edit: "Editar Inbound",
    delete: "Excluir Inbound",
    delete_confirm: "Deseja excluir este inbound? Esta ação não pode ser desfeita.",
    enable: "Ativar",
    disable: "Desativar",
    remark: "Observação",
    remark_placeholder: "Nome ou descrição do inbound",
    protocol: "Protocolo",
    port: "Porta",
    listen: "Escutar em",
    listen_placeholder: "Vazio = todos os IPs",
    traffic: "Tráfego",
    upload: "Upload",
    download: "Download",
    total: "Total",
    expire: "Expiração",
    no_expire: "Sem expiração",
    no_limit: "Sem limite",
    clients: "Clientes",
    online: "Online",
    status: "Status",
    expired: "Expirado",
    traffic_exceeded: "Tráfego esgotado",
    reset_traffic: "Resetar Tráfego",
    reset_confirm: "Deseja resetar o tráfego deste inbound?",
    reset_all: "Resetar Tudo",
    reset_all_confirm: "Deseja resetar o tráfego de TODOS os inbounds?",
    copy_link: "Copiar Link",
    qrcode: "QR Code",
    export: "Exportar",
    
    // Mensagens de sucesso
    add_success: "Inbound adicionado com sucesso!",
    edit_success: "Inbound atualizado com sucesso!",
    delete_success: "Inbound excluído com sucesso!",
    enable_success: "Inbound ativado!",
    disable_success: "Inbound desativado!",
    reset_success: "Tráfego resetado com sucesso!",
    
    // Colunas
    col_status: "Status",
    col_remark: "Nome",
    col_port: "Porta",
    col_protocol: "Protocolo",
    col_traffic: "Tráfego",
    col_expire: "Expiração",
    col_clients: "Clientes",
    col_action: "Ações",
  },

  // ==================== CLIENTES ====================
  client: {
    title: "Clientes",
    add: "Adicionar Cliente",
    edit: "Editar Cliente",
    delete: "Excluir",
    delete_confirm: "Deseja excluir este cliente?",
    email: "Email/ID",
    email_placeholder: "Identificador único",
    uuid: "UUID",
    password: "Senha",
    generate: "Gerar",
    traffic_limit: "Limite de Tráfego",
    expire_date: "Validade",
    no_expire: "Sem validade",
    no_limit: "Sem limite",
    ip_limit: "Limite de IPs",
    ip_limit_placeholder: "0 = ilimitado",
    tg_id: "Telegram ID",
    sub_id: "ID de Assinatura",
    comment: "Comentário",
    enable: "Ativo",
    reset_traffic: "Resetar Tráfego",
    
    // Status
    online: "Online",
    offline: "Offline",
    expired: "Expirado",
    traffic_exceeded: "Esgotado",
    
    // Mensagens
    add_success: "Cliente adicionado!",
    edit_success: "Cliente atualizado!",
    delete_success: "Cliente excluído!",
    reset_success: "Tráfego resetado!",
  },

  // ==================== CONFIGURAÇÕES DO XRAY ====================
  xray: {
    title: "Configurações do Xray",
    save: "Salvar",
    reset: "Restaurar Padrão",
    save_success: "Configurações salvas!",
    restart: "Reiniciar Xray",
    restart_confirm: "Deseja reiniciar o Xray agora?",
    format: "Formatar JSON",
    validate: "Validar",
    valid: "✅ Configuração válida",
    invalid: "❌ Configuração inválida",
  },

  // ==================== CONFIGURAÇÕES DO PAINEL ====================
  settings: {
    title: "Configurações do Painel",
    save: "Salvar Configurações",
    save_success: "Configurações salvas com sucesso!",
    
    // Seções
    panel: "Painel",
    security: "Segurança",
    ssl: "SSL/TLS",
    telegram: "Telegram",
    database: "Banco de Dados",
    update: "Atualização",
    subscription: "Assinatura",
    
    // Painel
    web_port: "Porta do Painel",
    web_path: "Caminho Base",
    web_domain: "Domínio",
    username: "Usuário Admin",
    password: "Senha Admin",
    
    // SSL
    cert_file: "Certificado SSL",
    cert_placeholder: "Caminho para o arquivo .crt",
    key_file: "Chave SSL",
    key_placeholder: "Caminho para o arquivo .key",
    
    // Telegram
    tg_enable: "Ativar Bot Telegram",
    tg_token: "Token do Bot",
    tg_token_placeholder: "Token do BotFather",
    tg_chat_id: "Chat ID",
    tg_admin_id: "ID do Admin",
    tg_login_notify: "Notificar Login",
    tg_cpu_notify: "Notificar CPU Alta",
    tg_bandwidth_notify: "Notificar Banda Esgotada",
    
    // Banco de dados
    backup: "Fazer Backup",
    restore: "Restaurar Backup",
    restore_confirm: "ATENÇÃO: Restaurar irá substituir todos os dados atuais! Continuar?",
    backup_success: "Backup realizado com sucesso!",
    restore_success: "Banco de dados restaurado!",
    
    // Atualização
    check_update: "Verificar Atualização",
    current_version: "Versão Atual",
    latest_version: "Versão Disponível",
    update_available: "Nova versão disponível!",
    up_to_date: "Sistema atualizado",
    update: "Atualizar",
    update_confirm: "Deseja atualizar o painel? Ele será reiniciado.",
    update_success: "Painel atualizado com sucesso!",
    
    // Assinatura
    sub_enable: "Ativar Assinatura",
    sub_port: "Porta",
    sub_path: "Caminho",
    sub_domain: "Domínio",
    sub_interval: "Intervalo de Atualização",
    sub_encode: "Codificar Links",
  },

  // ==================== PROTOCOLOS ====================
  protocol: {
    vmess: "VMess",
    vless: "VLESS",
    trojan: "Trojan",
    shadowsocks: "Shadowsocks",
    socks: "SOCKS",
    http: "HTTP",
    wireguard: "WireGuard",
  },

  // ==================== TRANSPORTE ====================
  network: {
    title: "Tipo de Rede",
    tcp: "TCP",
    kcp: "mKCP",
    ws: "WebSocket",
    http: "HTTP/2",
    quic: "QUIC",
    grpc: "gRPC",
    httpupgrade: "HTTPUpgrade",
    splithttp: "SplitHTTP",
    
    // WebSocket
    ws_path: "Caminho",
    ws_host: "Host",
    
    // gRPC
    grpc_service: "Nome do Serviço",
    grpc_mode: "Modo",
    
    // HTTP/2
    http_host: "Host",
    http_path: "Caminho",
    
    // QUIC
    quic_security: "Segurança",
    quic_key: "Chave",
    quic_header: "Tipo de Cabeçalho",
    
    // mKCP
    kcp_mtu: "MTU",
    kcp_tti: "TTI",
    kcp_up_cap: "Capacidade Upload",
    kcp_down_cap: "Capacidade Download",
    kcp_congestion: "Controle de Congestionamento",
    kcp_read_buf: "Buffer de Leitura",
    kcp_write_buf: "Buffer de Escrita",
    kcp_header: "Tipo de Cabeçalho",
    kcp_seed: "Semente",
  },

  // ==================== SEGURANÇA ====================
  security: {
    title: "Segurança",
    none: "Nenhum",
    tls: "TLS",
    reality: "Reality",
    xtls: "XTLS",
    
    // TLS
    sni: "Server Name (SNI)",
    sni_placeholder: "Domínio do certificado",
    cert: "Certificado",
    cert_placeholder: "Caminho do certificado",
    key: "Chave Privada",
    key_placeholder: "Caminho da chave",
    alpn: "ALPN",
    fingerprint: "Fingerprint TLS",
    allow_insecure: "Permitir Conexão Insegura",
    
    // Reality
    dest: "Destino",
    dest_placeholder: "Ex: microsoft.com:443",
    server_names: "Server Names",
    server_names_placeholder: "Domínios separados por vírgula",
    private_key: "Chave Privada",
    public_key: "Chave Pública",
    short_ids: "Short IDs",
    spider_x: "Spider X",
    generate_keys: "Gerar Par de Chaves",
    
    // Fingerprints
    fp_chrome: "Chrome",
    fp_firefox: "Firefox",
    fp_safari: "Safari",
    fp_ios: "iOS",
    fp_android: "Android",
    fp_edge: "Edge",
    fp_random: "Aleatório",
  },

  // ==================== SNIFFING ====================
  sniffing: {
    title: "Detecção de Protocolo (Sniffing)",
    enable: "Ativar",
    dest_override: "Substituir Destino",
  },

  // ==================== MENSAGENS ====================
  msg: {
    confirm_delete: "Tem certeza que deseja excluir?",
    confirm_reset: "Tem certeza que deseja resetar?",
    confirm_restart: "Tem certeza que deseja reiniciar?",
    success: "Operação realizada com sucesso!",
    failed: "Operação falhou!",
    network_error: "Erro de rede. Verifique sua conexão.",
    server_error: "Erro no servidor.",
    invalid_input: "Dados inválidos.",
    required: "Campo obrigatório.",
    port_range: "Porta deve estar entre 1 e 65535.",
    invalid_uuid: "UUID inválido.",
    invalid_json: "JSON inválido.",
    copy_success: "Copiado para a área de transferência!",
    copy_failed: "Falha ao copiar. Tente manualmente.",
    no_data: "Nenhum dado disponível.",
    loading: "Carregando...",
    please_wait: "Por favor, aguarde...",
  },

  // ==================== ERROS ====================
  error: {
    404: "Não encontrado",
    401: "Sessão expirada. Faça login novamente.",
    403: "Acesso negado.",
    500: "Erro interno do servidor.",
    port_in_use: "Esta porta já está em uso.",
    invalid_config: "Configuração inválida.",
    connect_failed: "Falha na conexão com o servidor.",
  },

  // ==================== TEMPO ====================
  time: {
    never: "Nunca",
    expired: "Expirado",
    days: "dias",
    hours: "horas",
    minutes: "minutos",
    seconds: "segundos",
    ago: "atrás",
    remaining: "restantes",
  },

  // ==================== TRÁFEGO ====================
  traffic: {
    unit_b: "B",
    unit_kb: "KB",
    unit_mb: "MB",
    unit_gb: "GB",
    unit_tb: "TB",
    upload: "Upload",
    download: "Download",
    total: "Total",
    used: "Usado",
    remaining: "Restante",
    no_limit: "Ilimitado",
    expired: "Esgotado",
  },

  // ==================== QR CODE ====================
  qrcode: {
    title: "QR Code",
    scan: "Escaneie com seu cliente VPN",
    close: "Fechar",
    download: "Baixar QR Code",
  },
  
  // ==================== TOOLTIPS ====================
  tooltip: {
    remark: "Nome para identificar este inbound",
    port: "Porta de conexão (1-65535)",
    listen: "IP para escutar. Vazio = todos os IPs",
    total_traffic: "0 = tráfego ilimitado",
    expire_date: "Data de expiração do inbound",
    uuid: "Identificador único do cliente",
    ip_limit: "Número máximo de IPs simultâneos (0 = ilimitado)",
    tg_id: "ID do Telegram para notificações",
    sub_id: "ID único para link de assinatura",
  },
};

// Aplicar traduções
if (typeof i18n !== "undefined") {
  i18n.mergeLocaleMessage("pt_BR", LANG_PT_BR);
}

// Exportar para uso direto
if (typeof module !== "undefined" && module.exports) {
  module.exports = LANG_PT_BR;
}