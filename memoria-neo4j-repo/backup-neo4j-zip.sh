#!/bin/bash
# Script de Backup do Neo4j com compressão ZIP
# Cria backups compactados para economizar espaço

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   📦 Neo4j Memory Backup (ZIP)         ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}\n"

# Configurações
BACKUP_DIR="/home/codable/terminal/memoria-neo4j-repo/backups-zip"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE=$(date +%Y-%m-%d)
BACKUP_NAME="${1:-backup_${TIMESTAMP}}"
TEMP_DIR="/tmp/neo4j_backup_${TIMESTAMP}"

# Criar diretórios necessários
mkdir -p "${BACKUP_DIR}"
mkdir -p "${TEMP_DIR}"

echo -e "${BLUE}📊 Exportando memórias do Neo4j...${NC}"

# Verificar se container está rodando
if ! docker ps | grep -q terminal-neo4j; then
    echo -e "${RED}❌ Container terminal-neo4j não está rodando!${NC}"
    exit 1
fi

# Função para exportar dados completos
export_memories() {
    local output_file="$1"
    
    # Query Cypher para exportar TUDO
    docker exec terminal-neo4j cypher-shell \
        -u neo4j \
        -p "${NEO4J_PASSWORD:-Cancela@1}" \
        --format plain << 'CYPHER' | grep "^{" > "${output_file}"
MATCH (n)
WITH collect({
    id: id(n),
    labels: labels(n),
    properties: properties(n),
    created_at: n.created_at,
    updated_at: n.updated_at
}) as nodes
MATCH ()-[r]->()
WITH nodes, collect({
    id: id(r),
    type: type(r),
    startNode: id(startNode(r)),
    endNode: id(endNode(r)),
    properties: properties(r)
}) as relationships
RETURN {
    exportDate: datetime(),
    exportVersion: "2.0",
    stats: {
        nodeCount: size(nodes),
        relationshipCount: size(relationships),
        totalSize: size(nodes) + size(relationships)
    },
    nodes: nodes,
    relationships: relationships
}
CYPHER
}

# Função para exportar schema
export_schema() {
    local output_file="$1"
    
    echo "// Neo4j Schema Export - ${DATE}" > "${output_file}"
    echo "// ================================" >> "${output_file}"
    echo "" >> "${output_file}"
    
    # Exportar labels
    docker exec terminal-neo4j cypher-shell \
        -u neo4j \
        -p "${NEO4J_PASSWORD:-Cancela@1}" \
        "CALL db.labels() YIELD label RETURN 'Label: ' + label as output" \
        --format plain >> "${output_file}" 2>/dev/null || true
    
    # Exportar relationship types
    docker exec terminal-neo4j cypher-shell \
        -u neo4j \
        -p "${NEO4J_PASSWORD:-Cancela@1}" \
        "CALL db.relationshipTypes() YIELD relationshipType RETURN 'RelType: ' + relationshipType as output" \
        --format plain >> "${output_file}" 2>/dev/null || true
    
    # Exportar constraints e indexes
    docker exec terminal-neo4j cypher-shell \
        -u neo4j \
        -p "${NEO4J_PASSWORD:-Cancela@1}" \
        "SHOW CONSTRAINTS" \
        --format plain >> "${output_file}" 2>/dev/null || true
}

# Função para criar queries de restore
create_restore_script() {
    local input_file="$1"
    local output_file="$2"
    
    cat > "${output_file}" << 'SCRIPT'
#!/bin/bash
# Auto-generated restore script
echo "🔄 Restaurando memórias do Neo4j..."

# Verificar senha
if [ -z "$NEO4J_PASSWORD" ]; then
    read -s -p "Digite a senha do Neo4j: " NEO4J_PASSWORD
    echo
fi

# Limpar banco atual
docker exec terminal-neo4j cypher-shell \
    -u neo4j -p "$NEO4J_PASSWORD" \
    "MATCH (n) DETACH DELETE n" || exit 1

# Restaurar dados
docker exec -i terminal-neo4j cypher-shell \
    -u neo4j -p "$NEO4J_PASSWORD" < restore_queries.cypher

echo "✅ Restore concluído!"
SCRIPT
    
    chmod +x "${output_file}"
}

# 1. Exportar memórias
echo -e "${YELLOW}  📝 Exportando dados...${NC}"
export_memories "${TEMP_DIR}/memories.json"

# Verificar se tem dados
if [ -s "${TEMP_DIR}/memories.json" ]; then
    NODE_COUNT=$(grep -o '"nodeCount":[0-9]*' "${TEMP_DIR}/memories.json" | cut -d: -f2)
    REL_COUNT=$(grep -o '"relationshipCount":[0-9]*' "${TEMP_DIR}/memories.json" | cut -d: -f2)
    echo -e "${GREEN}    ✅ ${NODE_COUNT:-0} nós e ${REL_COUNT:-0} relacionamentos${NC}"
else
    echo -e "${YELLOW}    ⚠️ Banco de dados vazio${NC}"
fi

# 2. Exportar schema
echo -e "${YELLOW}  📐 Exportando schema...${NC}"
export_schema "${TEMP_DIR}/schema.cypher"

# 3. Criar metadata
echo -e "${YELLOW}  📋 Criando metadata...${NC}"
cat > "${TEMP_DIR}/metadata.json" << EOF
{
    "backup_date": "${DATE}",
    "backup_time": "$(date +%H:%M:%S)",
    "backup_name": "${BACKUP_NAME}",
    "neo4j_version": "5.26.10",
    "system": "terminal",
    "compressed": true,
    "format": "zip",
    "stats": {
        "nodes": ${NODE_COUNT:-0},
        "relationships": ${REL_COUNT:-0}
    }
}
EOF

# 4. Criar script de restore
echo -e "${YELLOW}  🔧 Criando script de restore...${NC}"
create_restore_script "${TEMP_DIR}/memories.json" "${TEMP_DIR}/restore.sh"

# 5. Criar README no ZIP
cat > "${TEMP_DIR}/README.txt" << EOF
═══════════════════════════════════════════
    Neo4j Memory Backup
    Data: ${DATE}
    Hora: $(date +%H:%M:%S)
═══════════════════════════════════════════

Conteúdo:
---------
• memories.json    - Dados completos do Neo4j
• schema.cypher    - Estrutura do banco
• metadata.json    - Informações do backup
• restore.sh       - Script de restauração

Como Restaurar:
--------------
1. Extrair o ZIP:
   unzip ${BACKUP_NAME}.zip

2. Executar restore:
   ./restore.sh

Ou manualmente:
   docker exec -i terminal-neo4j cypher-shell \\
     -u neo4j -p "SuaSenha" < memories.json

Estatísticas:
------------
• Nós: ${NODE_COUNT:-0}
• Relacionamentos: ${REL_COUNT:-0}
• Tamanho original: $(du -sh "${TEMP_DIR}" | cut -f1)

═══════════════════════════════════════════
EOF

# 6. Criar arquivo ZIP
echo -e "${BLUE}📦 Comprimindo backup...${NC}"
ZIP_FILE="${BACKUP_DIR}/${BACKUP_NAME}.zip"

cd "${TEMP_DIR}"
zip -r "${ZIP_FILE}" . -q

# Calcular tamanhos
ORIGINAL_SIZE=$(du -sb "${TEMP_DIR}" | cut -f1)
ZIP_SIZE=$(stat -f%z "${ZIP_FILE}" 2>/dev/null || stat -c%s "${ZIP_FILE}" 2>/dev/null)
COMPRESSION_RATIO=$(echo "scale=1; 100 - ($ZIP_SIZE * 100 / $ORIGINAL_SIZE)" | bc 2>/dev/null || echo "0")

# 7. Limpar temporários
rm -rf "${TEMP_DIR}"

# 8. Criar link simbólico para último backup
ln -sf "${ZIP_FILE}" "${BACKUP_DIR}/latest.zip"

# 9. Limpeza de backups antigos (manter últimos 30)
echo -e "${YELLOW}🧹 Limpando backups antigos...${NC}"
cd "${BACKUP_DIR}"
ls -t *.zip 2>/dev/null | tail -n +31 | xargs rm -f 2>/dev/null || true

# 10. Listar backups disponíveis
echo -e "\n${CYAN}📚 Backups disponíveis:${NC}"
ls -lht "${BACKUP_DIR}"/*.zip 2>/dev/null | head -5 | while read line; do
    echo "  $line"
done

# Resumo final
echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         ✅ Backup Concluído!           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo -e "${GREEN}📁 Arquivo: ${ZIP_FILE}${NC}"
echo -e "${GREEN}📊 Tamanho: $(du -h "${ZIP_FILE}" | cut -f1)${NC}"
echo -e "${GREEN}🗜️  Compressão: ${COMPRESSION_RATIO}%${NC}"
echo -e "${GREEN}🔗 Link: ${BACKUP_DIR}/latest.zip${NC}"
echo -e "\n${BLUE}💡 Para restaurar:${NC}"
echo -e "   unzip ${ZIP_FILE} -d /tmp/restore"
echo -e "   cd /tmp/restore && ./restore.sh"