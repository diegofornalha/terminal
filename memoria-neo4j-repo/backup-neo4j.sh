#!/bin/bash
# Script de Backup do Neo4j - Preserva todas as memórias
# Uso: ./backup-neo4j.sh [nome-opcional]

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configurações
BACKUP_DIR="/home/codable/terminal/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="${1:-backup_${TIMESTAMP}}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

echo -e "${GREEN}🔄 Iniciando backup do Neo4j...${NC}"

# Criar diretório de backups se não existir
mkdir -p "${BACKUP_DIR}"

# Verificar se o container está rodando
if ! docker ps | grep -q terminal-neo4j; then
    echo -e "${RED}❌ Container terminal-neo4j não está rodando!${NC}"
    exit 1
fi

# Método 1: Backup via Cypher (dados apenas)
echo -e "${YELLOW}📊 Exportando dados via Cypher...${NC}"
mkdir -p "${BACKUP_PATH}"

# Exportar todos os nós e relacionamentos
docker exec terminal-neo4j cypher-shell -u neo4j -p "${NEO4J_PASSWORD}" \
    "CALL apoc.export.json.all('/var/lib/neo4j/import/backup.json', {useTypes:true})" 2>/dev/null || {
    
    # Se APOC não estiver disponível, usar método alternativo
    echo -e "${YELLOW}⚠️ APOC não disponível, usando método alternativo...${NC}"
    
    # Exportar estrutura via dump nativo
    docker exec terminal-neo4j bash -c "
        echo 'MATCH (n) RETURN n' | cypher-shell -u neo4j -p '${NEO4J_PASSWORD:-Cancela@1}' --format plain > /tmp/nodes.cypher
        echo 'MATCH ()-[r]->() RETURN r' | cypher-shell -u neo4j -p '${NEO4J_PASSWORD:-Cancela@1}' --format plain > /tmp/relationships.cypher
    " 2>/dev/null
}

# Copiar arquivos de backup do container
docker cp terminal-neo4j:/var/lib/neo4j/import/backup.json "${BACKUP_PATH}/data.json" 2>/dev/null || true
docker cp terminal-neo4j:/tmp/nodes.cypher "${BACKUP_PATH}/nodes.cypher" 2>/dev/null || true
docker cp terminal-neo4j:/tmp/relationships.cypher "${BACKUP_PATH}/relationships.cypher" 2>/dev/null || true

# Método 2: Backup dos volumes Docker (backup completo)
echo -e "${YELLOW}💾 Fazendo backup dos volumes Docker...${NC}"

# Parar o container temporariamente para garantir consistência
docker stop terminal-neo4j >/dev/null 2>&1

# Fazer backup dos volumes
for volume in neo4j_data neo4j_logs neo4j_import neo4j_plugins; do
    if docker volume ls | grep -q "terminal_${volume}"; then
        echo -e "  Salvando volume: terminal_${volume}"
        docker run --rm \
            -v "terminal_${volume}:/source:ro" \
            -v "${BACKUP_PATH}:/backup" \
            alpine tar czf "/backup/${volume}.tar.gz" -C /source . 2>/dev/null
    fi
done

# Reiniciar o container
docker start terminal-neo4j >/dev/null 2>&1

# Salvar metadados do backup
cat > "${BACKUP_PATH}/metadata.json" << EOF
{
    "timestamp": "${TIMESTAMP}",
    "backup_name": "${BACKUP_NAME}",
    "neo4j_version": "5.26.10",
    "method": "hybrid",
    "includes": {
        "data_export": $([ -f "${BACKUP_PATH}/data.json" ] && echo "true" || echo "false"),
        "volume_backup": $([ -f "${BACKUP_PATH}/neo4j_data.tar.gz" ] && echo "true" || echo "false")
    }
}
EOF

# Criar script de restore específico para este backup
cat > "${BACKUP_PATH}/restore.sh" << 'EOF'
#!/bin/bash
# Script de Restore gerado automaticamente

BACKUP_DIR="$(dirname "$0")"
echo "🔄 Restaurando backup de: $BACKUP_DIR"

# Verificar senha
if [ -z "$NEO4J_PASSWORD" ]; then
    echo "⚠️ Defina NEO4J_PASSWORD antes de restaurar"
    exit 1
fi

# Parar container
docker stop terminal-neo4j 2>/dev/null

# Restaurar volumes
for volume in neo4j_data neo4j_logs neo4j_import neo4j_plugins; do
    if [ -f "$BACKUP_DIR/${volume}.tar.gz" ]; then
        echo "Restaurando volume: terminal_${volume}"
        docker run --rm \
            -v "terminal_${volume}:/target" \
            -v "$BACKUP_DIR:/backup:ro" \
            alpine sh -c "rm -rf /target/* && tar xzf /backup/${volume}.tar.gz -C /target"
    fi
done

# Reiniciar container
docker start terminal-neo4j

echo "✅ Restore concluído!"
EOF

chmod +x "${BACKUP_PATH}/restore.sh"

# Resumo
echo -e "${GREEN}✅ Backup concluído!${NC}"
echo -e "${GREEN}📁 Localização: ${BACKUP_PATH}${NC}"
echo -e "${GREEN}📊 Arquivos criados:${NC}"
ls -lh "${BACKUP_PATH}/" | tail -n +2

# Listar últimos 5 backups
echo -e "\n${YELLOW}📚 Últimos backups disponíveis:${NC}"
ls -lt "${BACKUP_DIR}" | head -6 | tail -n +2

echo -e "\n${GREEN}💡 Para restaurar este backup, execute:${NC}"
echo -e "   ${BACKUP_PATH}/restore.sh"