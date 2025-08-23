#!/bin/bash
# Script de Backup do Neo4j com sincronização para GitHub
# Salva backups em um submódulo Git para versionamento

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
BACKUP_REPO_DIR="/home/codable/terminal/neo4j-backups"
BACKUP_REPO_URL="${BACKUP_REPO_URL:-https://github.com/SEU_USUARIO/terminal-neo4j-backups.git}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATE=$(date +%Y-%m-%d)
BACKUP_NAME="${1:-backup_${TIMESTAMP}}"

echo -e "${BLUE}🔄 Sistema de Backup Neo4j com GitHub${NC}"
echo -e "${BLUE}=====================================\n${NC}"

# Função para inicializar repositório de backups
init_backup_repo() {
    if [ ! -d "${BACKUP_REPO_DIR}" ]; then
        echo -e "${YELLOW}📦 Inicializando repositório de backups...${NC}"
        
        # Criar diretório e inicializar git
        mkdir -p "${BACKUP_REPO_DIR}"
        cd "${BACKUP_REPO_DIR}"
        git init
        
        # Criar estrutura inicial
        cat > README.md << 'EOF'
# Neo4j Backups - Terminal System

Este repositório contém backups automáticos do banco de dados Neo4j do sistema Terminal.

## Estrutura

```
├── daily/          # Backups diários (últimos 7 dias)
├── weekly/         # Backups semanais (últimas 4 semanas)
├── monthly/        # Backups mensais (últimos 12 meses)
└── manual/         # Backups manuais importantes
```

## Restaurar Backup

```bash
cd /home/codable/terminal
./restore-neo4j-github.sh [YYYY-MM-DD]
```

## Formato dos Backups

Cada backup contém:
- `memories.json` - Exportação completa das memórias
- `metadata.json` - Informações sobre o backup
- `schema.cypher` - Estrutura do banco de dados
EOF
        
        # Criar diretórios
        mkdir -p daily weekly monthly manual
        
        # Criar .gitignore
        cat > .gitignore << 'EOF'
*.tmp
*.log
.DS_Store
EOF
        
        git add .
        git commit -m "Initial backup repository structure"
        
        echo -e "${GREEN}✅ Repositório de backups inicializado${NC}"
    else
        cd "${BACKUP_REPO_DIR}"
        git pull --rebase 2>/dev/null || true
    fi
}

# Função para exportar dados do Neo4j
export_neo4j_data() {
    local output_file="$1"
    
    echo -e "${YELLOW}📊 Exportando dados do Neo4j...${NC}"
    
    # Verificar se container está rodando
    if ! docker ps | grep -q terminal-neo4j; then
        echo -e "${RED}❌ Container terminal-neo4j não está rodando!${NC}"
        return 1
    fi
    
    # Criar query Cypher para exportar tudo
    local export_query='
    CALL {
        MATCH (n)
        WITH collect(n) as nodes
        MATCH ()-[r]->()
        WITH nodes, collect(r) as relationships
        RETURN {
            nodes: [n in nodes | {
                id: id(n),
                labels: labels(n),
                properties: properties(n)
            }],
            relationships: [r in relationships | {
                id: id(r),
                type: type(r),
                startNode: id(startNode(r)),
                endNode: id(endNode(r)),
                properties: properties(r)
            }],
            exportDate: datetime(),
            nodeCount: size(nodes),
            relationshipCount: size(relationships)
        } as data
    }
    RETURN data
    '
    
    # Executar export
    docker exec terminal-neo4j cypher-shell \
        -u neo4j \
        -p "${NEO4J_PASSWORD}" \
        --format plain \
        "$export_query" > "${output_file}.tmp" 2>/dev/null
    
    # Processar output para JSON válido
    if [ -f "${output_file}.tmp" ]; then
        # Extrair apenas o JSON da saída
        grep "^{" "${output_file}.tmp" | head -1 > "${output_file}"
        rm "${output_file}.tmp"
        
        # Verificar se tem dados
        if [ -s "${output_file}" ]; then
            local node_count=$(grep -o '"nodeCount":[0-9]*' "${output_file}" | cut -d: -f2)
            echo -e "${GREEN}  ✅ Exportados ${node_count:-0} nós${NC}"
        else
            echo -e "${YELLOW}  ⚠️ Banco de dados vazio${NC}"
            echo '{"nodes":[],"relationships":[],"exportDate":"'$(date -Iseconds)'"}' > "${output_file}"
        fi
    fi
}

# Função para exportar schema
export_schema() {
    local output_file="$1"
    
    echo -e "${YELLOW}📐 Exportando schema...${NC}"
    
    docker exec terminal-neo4j cypher-shell \
        -u neo4j \
        -p "${NEO4J_PASSWORD}" \
        "CALL db.schema.visualization()" \
        --format plain > "${output_file}" 2>/dev/null || {
        echo "// Schema export at $(date)" > "${output_file}"
        docker exec terminal-neo4j cypher-shell \
            -u neo4j \
            -p "${NEO4J_PASSWORD}" \
            "CALL db.labels()" >> "${output_file}" 2>/dev/null || true
    }
}

# Função para determinar tipo de backup
get_backup_type() {
    local day_of_week=$(date +%u)
    local day_of_month=$(date +%d)
    
    if [ "$1" == "manual" ]; then
        echo "manual"
    elif [ "$day_of_month" == "01" ]; then
        echo "monthly"
    elif [ "$day_of_week" == "7" ]; then
        echo "weekly"
    else
        echo "daily"
    fi
}

# Função para limpar backups antigos
cleanup_old_backups() {
    echo -e "${YELLOW}🧹 Limpando backups antigos...${NC}"
    
    cd "${BACKUP_REPO_DIR}"
    
    # Manter apenas últimos 7 backups diários
    find daily -name "*.json" -mtime +7 -delete 2>/dev/null || true
    
    # Manter apenas últimas 4 semanas
    find weekly -name "*.json" -mtime +28 -delete 2>/dev/null || true
    
    # Manter apenas últimos 12 meses
    find monthly -name "*.json" -mtime +365 -delete 2>/dev/null || true
}

# Função principal de backup
perform_backup() {
    local backup_type=$(get_backup_type "$1")
    local backup_dir="${BACKUP_REPO_DIR}/${backup_type}"
    local backup_file="${backup_dir}/${DATE}_memories.json"
    local schema_file="${backup_dir}/${DATE}_schema.cypher"
    local metadata_file="${backup_dir}/${DATE}_metadata.json"
    
    echo -e "${GREEN}📁 Tipo de backup: ${backup_type}${NC}"
    
    # Exportar dados
    export_neo4j_data "${backup_file}"
    export_schema "${schema_file}"
    
    # Criar metadata
    cat > "${metadata_file}" << EOF
{
    "backup_date": "${DATE}",
    "backup_time": "$(date +%H:%M:%S)",
    "backup_type": "${backup_type}",
    "backup_name": "${BACKUP_NAME}",
    "neo4j_version": "5.26.10",
    "system": "terminal",
    "file_size": $(stat -f%z "${backup_file}" 2>/dev/null || stat -c%s "${backup_file}" 2>/dev/null || echo 0)
}
EOF
    
    echo -e "${GREEN}✅ Backup salvo em: ${backup_dir}/${NC}"
}

# Função para commit e push
sync_to_github() {
    echo -e "${YELLOW}📤 Sincronizando com GitHub...${NC}"
    
    cd "${BACKUP_REPO_DIR}"
    
    # Adicionar mudanças
    git add .
    
    # Commit
    local commit_msg="Backup ${DATE} - $(get_backup_type "$1")"
    git commit -m "$commit_msg" || {
        echo -e "${YELLOW}  ℹ️ Nenhuma mudança para commitar${NC}"
        return 0
    }
    
    # Push (se remoto configurado)
    if git remote get-url origin &>/dev/null; then
        git push origin main 2>/dev/null || {
            echo -e "${YELLOW}  ⚠️ Push falhou - verifique configuração do remoto${NC}"
            echo -e "${YELLOW}  Configure com: git remote add origin ${BACKUP_REPO_URL}${NC}"
        }
    else
        echo -e "${YELLOW}  ℹ️ Remoto não configurado. Para sincronizar:${NC}"
        echo -e "${YELLOW}     cd ${BACKUP_REPO_DIR}${NC}"
        echo -e "${YELLOW}     git remote add origin ${BACKUP_REPO_URL}${NC}"
        echo -e "${YELLOW}     git push -u origin main${NC}"
    fi
}

# Adicionar ao submódulo principal se necessário
add_as_submodule() {
    cd /home/codable/terminal
    
    if [ ! -f .gitmodules ] || ! grep -q "neo4j-backups" .gitmodules 2>/dev/null; then
        echo -e "${YELLOW}📎 Adicionando como submódulo...${NC}"
        git submodule add "${BACKUP_REPO_DIR}" neo4j-backups 2>/dev/null || true
        git add .gitmodules neo4j-backups
        git commit -m "Add neo4j-backups as submodule" 2>/dev/null || true
    fi
}

# ============ EXECUÇÃO PRINCIPAL ============

echo -e "${BLUE}🚀 Iniciando backup do Neo4j${NC}"

# Inicializar repositório
init_backup_repo

# Realizar backup
perform_backup "$1"

# Limpar backups antigos
cleanup_old_backups

# Sincronizar com GitHub
sync_to_github "$1"

# Adicionar como submódulo
add_as_submodule

# Estatísticas finais
echo -e "\n${GREEN}📊 Estatísticas de Backup:${NC}"
cd "${BACKUP_REPO_DIR}"
echo -e "  Total de backups: $(find . -name "*.json" -type f | grep -v metadata | wc -l)"
echo -e "  Espaço usado: $(du -sh . | cut -f1)"
echo -e "  Último backup: ${DATE}"

echo -e "\n${GREEN}✅ Backup concluído com sucesso!${NC}"
echo -e "${BLUE}💡 Para restaurar, use: ./restore-neo4j-github.sh [data]${NC}"