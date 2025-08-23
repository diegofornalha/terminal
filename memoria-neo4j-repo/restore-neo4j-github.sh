#!/bin/bash
# Script de Restore do Neo4j a partir do GitHub
# Uso: ./restore-neo4j-github.sh [YYYY-MM-DD] [tipo]

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configurações
BACKUP_REPO_DIR="/home/codable/terminal/neo4j-backups"
RESTORE_DATE="${1:-$(date +%Y-%m-%d)}"
BACKUP_TYPE="${2:-daily}"

echo -e "${BLUE}🔄 Restore do Neo4j a partir do GitHub${NC}"
echo -e "${BLUE}======================================\n${NC}"

# Verificar se repositório existe
if [ ! -d "${BACKUP_REPO_DIR}" ]; then
    echo -e "${RED}❌ Repositório de backups não encontrado!${NC}"
    echo -e "${YELLOW}Execute primeiro: ./backup-neo4j-github.sh${NC}"
    exit 1
fi

# Atualizar repositório
echo -e "${YELLOW}📥 Atualizando repositório de backups...${NC}"
cd "${BACKUP_REPO_DIR}"
git pull --rebase 2>/dev/null || true

# Procurar arquivo de backup
find_backup_file() {
    local date="$1"
    local file=""
    
    # Procurar em ordem: manual, daily, weekly, monthly
    for type in manual daily weekly monthly; do
        file="${BACKUP_REPO_DIR}/${type}/${date}_memories.json"
        if [ -f "$file" ]; then
            echo "$file"
            return 0
        fi
    done
    
    return 1
}

# Listar backups disponíveis
list_available_backups() {
    echo -e "${YELLOW}📚 Backups disponíveis:${NC}"
    
    for type in manual daily weekly monthly; do
        if [ -d "${BACKUP_REPO_DIR}/${type}" ]; then
            local count=$(ls "${BACKUP_REPO_DIR}/${type}"/*_memories.json 2>/dev/null | wc -l)
            if [ "$count" -gt 0 ]; then
                echo -e "\n${GREEN}${type^^}:${NC}"
                ls -1 "${BACKUP_REPO_DIR}/${type}"/*_memories.json 2>/dev/null | \
                    xargs -n1 basename | \
                    sed 's/_memories.json//' | \
                    sort -r | \
                    head -10
            fi
        fi
    done
}

# Encontrar arquivo de backup
BACKUP_FILE=$(find_backup_file "$RESTORE_DATE") || {
    echo -e "${RED}❌ Backup não encontrado para: ${RESTORE_DATE}${NC}"
    echo ""
    list_available_backups
    exit 1
}

echo -e "${GREEN}✅ Backup encontrado: $(basename "$BACKUP_FILE")${NC}"

# Verificar metadata
METADATA_FILE="${BACKUP_FILE/_memories.json/_metadata.json}"
if [ -f "$METADATA_FILE" ]; then
    echo -e "${BLUE}📋 Informações do backup:${NC}"
    cat "$METADATA_FILE" | python3 -m json.tool 2>/dev/null || cat "$METADATA_FILE"
    echo ""
fi

# Confirmar restore
echo -e "${YELLOW}⚠️  ATENÇÃO: Isso irá SUBSTITUIR todos os dados atuais!${NC}"
read -p "Continuar com o restore? (s/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${RED}Restore cancelado.${NC}"
    exit 1
fi

# Parar container
echo -e "${YELLOW}🛑 Parando container Neo4j...${NC}"
docker stop terminal-neo4j 2>/dev/null || true

# Limpar dados atuais
echo -e "${YELLOW}🧹 Limpando dados atuais...${NC}"
docker run --rm \
    -v terminal_neo4j_data:/data \
    alpine sh -c "rm -rf /data/*" 2>/dev/null || true

# Iniciar container
echo -e "${YELLOW}▶️ Iniciando container Neo4j...${NC}"
docker start terminal-neo4j 2>/dev/null || docker compose up -d terminal-neo4j

# Aguardar Neo4j ficar pronto
echo -e "${YELLOW}⏳ Aguardando Neo4j inicializar...${NC}"
sleep 10

# Verificar se Neo4j está pronto
for i in {1..30}; do
    if docker exec terminal-neo4j cypher-shell -u neo4j -p "${NEO4J_PASSWORD}" "RETURN 1" &>/dev/null; then
        echo -e "${GREEN}✅ Neo4j pronto!${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

# Preparar arquivo de import
echo -e "${YELLOW}📥 Importando dados...${NC}"

# Converter JSON para comandos Cypher
python3 << EOF
import json
import sys

with open('$BACKUP_FILE', 'r') as f:
    data = json.loads(f.read())
    
if 'data' in data:
    data = data['data']

# Criar arquivo Cypher
with open('/tmp/restore.cypher', 'w') as out:
    # Limpar banco
    out.write("MATCH (n) DETACH DELETE n;\n")
    
    # Criar nós
    nodes = data.get('nodes', [])
    node_mapping = {}
    
    for node in nodes:
        labels = ':'.join(node.get('labels', ['Node']))
        props = json.dumps(node.get('properties', {}))
        node_id = node.get('id', node.get('_id'))
        
        out.write(f"CREATE (n{node_id}:{labels} {props});\n")
        node_mapping[node_id] = f"n{node_id}"
    
    # Criar relacionamentos
    relationships = data.get('relationships', [])
    
    for rel in relationships:
        start = rel.get('startNode', rel.get('start'))
        end = rel.get('endNode', rel.get('end'))
        rel_type = rel.get('type', 'RELATED_TO')
        props = json.dumps(rel.get('properties', {}))
        
        if start in node_mapping and end in node_mapping:
            out.write(f"MATCH (a), (b) WHERE id(a) = {start} AND id(b) = {end} ")
            out.write(f"CREATE (a)-[:{rel_type} {props}]->(b);\n")

print(f"✅ Preparados {len(nodes)} nós e {len(relationships)} relacionamentos")
EOF

# Executar restore
if [ -f /tmp/restore.cypher ]; then
    echo -e "${YELLOW}🔄 Executando restore...${NC}"
    
    docker cp /tmp/restore.cypher terminal-neo4j:/tmp/restore.cypher
    
    docker exec terminal-neo4j cypher-shell \
        -u neo4j \
        -p "${NEO4J_PASSWORD}" \
        -f /tmp/restore.cypher || {
        
        # Método alternativo se falhar
        echo -e "${YELLOW}Tentando método alternativo...${NC}"
        cat /tmp/restore.cypher | docker exec -i terminal-neo4j cypher-shell \
            -u neo4j \
            -p "${NEO4J_PASSWORD}"
    }
    
    rm /tmp/restore.cypher
fi

# Verificar resultado
echo -e "\n${YELLOW}📊 Verificando restore...${NC}"
NODE_COUNT=$(docker exec terminal-neo4j cypher-shell \
    -u neo4j \
    -p "${NEO4J_PASSWORD}" \
    "MATCH (n) RETURN count(n) as count" \
    --format plain 2>/dev/null | grep -o '[0-9]*' | head -1)

REL_COUNT=$(docker exec terminal-neo4j cypher-shell \
    -u neo4j \
    -p "${NEO4J_PASSWORD}" \
    "MATCH ()-[r]->() RETURN count(r) as count" \
    --format plain 2>/dev/null | grep -o '[0-9]*' | head -1)

echo -e "${GREEN}✅ Restore concluído!${NC}"
echo -e "${GREEN}   Nós restaurados: ${NODE_COUNT:-0}${NC}"
echo -e "${GREEN}   Relacionamentos: ${REL_COUNT:-0}${NC}"

# Log do restore
echo "$(date): Restore executado de $BACKUP_FILE" >> "${BACKUP_REPO_DIR}/restore.log"

echo -e "\n${BLUE}💡 Acesse http://localhost:7474 para verificar os dados${NC}"