#!/bin/bash
# Script para aplicar tradução PT-BR no x-ui

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🇧🇷 Aplicando tradução PT-BR no x-ui...${NC}"

# Verificar se x-ui está instalado
if [[ ! -d "/usr/local/x-ui" ]]; then
    echo -e "${RED}❌ x-ui não encontrado em /usr/local/x-ui${NC}"
    exit 1
fi

# Fazer backup dos arquivos originais
echo -e "${YELLOW}📦 Fazendo backup dos arquivos originais...${NC}"
BACKUP_DIR="/usr/local/x-ui/backup_original"
mkdir -p "$BACKUP_DIR"

# Copiar arquivos de tradução
echo -e "${BLUE}📝 Copiando arquivos de tradução...${NC}"

# Criar diretório de tradução se não existir
mkdir -p /usr/local/x-ui/web/translation/

# Copiar arquivo de tradução YAML
if [[ -f "pt_BR.yaml" ]]; then
    cp pt_BR.yaml /usr/local/x-ui/web/translation/
    echo -e "${GREEN}✅ Arquivo YAML copiado${NC}"
fi

# Copiar arquivo JS
if [[ -f "pt_BR.js" ]]; then
    mkdir -p /usr/local/x-ui/web/html/js/lang/
    cp pt_BR.js /usr/local/x-ui/web/html/js/lang/
    echo -e "${GREEN}✅ Arquivo JS copiado${NC}"
fi

# Reiniciar o serviço
echo -e "${BLUE}🔄 Reiniciando x-ui...${NC}"
systemctl restart x-ui

if systemctl is-active x-ui > /dev/null 2>&1; then
    echo -e "${GREEN}✅ x-ui reiniciado com sucesso!${NC}"
    echo -e "${GREEN}🇧🇷 Tradução PT-BR aplicada!${NC}"
else
    echo -e "${RED}❌ Falha ao reiniciar x-ui${NC}"
    echo -e "${YELLOW}Verifique os logs: journalctl -u x-ui -n 50${NC}"
fi