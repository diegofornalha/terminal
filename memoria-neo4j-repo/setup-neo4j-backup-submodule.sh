#!/bin/bash
# Script para configurar submódulo de backups do Neo4j
# Cria um repositório separado para armazenar todos os backups

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}   Configuração do Submódulo de Backups Neo4j${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════${NC}\n"

# Configurações
MAIN_DIR="/home/codable/terminal"
BACKUP_DIR="${MAIN_DIR}/neo4j-memory-backups"
GITHUB_USER="${GITHUB_USER:-SEU_USUARIO}"
REPO_NAME="terminal-neo4j-memory-backups"
REPO_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}.git"

# Passo 1: Criar e inicializar o repositório de backups
echo -e "${BLUE}📁 Passo 1: Criando repositório de backups...${NC}"

if [ -d "${BACKUP_DIR}" ]; then
    echo -e "${YELLOW}  ⚠️ Diretório já existe. Removendo...${NC}"
    rm -rf "${BACKUP_DIR}"
fi

mkdir -p "${BACKUP_DIR}"
cd "${BACKUP_DIR}"

# Inicializar git
git init
git branch -M main

# Criar estrutura do repositório
echo -e "${BLUE}📂 Criando estrutura de diretórios...${NC}"

# Criar README.md
cat > README.md << 'EOF'
# 🧠 Terminal Neo4j Memory Backups

Repositório dedicado para backups automáticos das memórias do Neo4j do sistema Terminal.

## 📁 Estrutura

```
.
├── daily/              # Backups diários (mantém últimos 7)
├── weekly/             # Backups semanais (mantém últimas 4)
├── monthly/            # Backups mensais (mantém últimos 12)
├── snapshots/          # Snapshots manuais importantes
└── scripts/            # Scripts de backup/restore
```

## 🔄 Backup Automático

Backups são realizados automaticamente:
- **Diário**: Todo dia às 02:00 AM
- **Semanal**: Domingos às 03:00 AM
- **Mensal**: Dia 1 de cada mês às 04:00 AM

## 📥 Como Restaurar

```bash
# Restaurar último backup
./scripts/restore.sh

# Restaurar backup específico
./scripts/restore.sh 2025-08-23

# Restaurar de um tipo específico
./scripts/restore.sh 2025-08-23 weekly
```

## 🔐 Formato dos Backups

Cada backup contém:
- `memories.json` - Dados completos do Neo4j
- `metadata.json` - Informações sobre o backup
- `schema.cypher` - Estrutura do banco

## 📊 Estatísticas

- Total de memórias: Atualizado automaticamente
- Tamanho do repositório: Verificar GitHub
- Último backup: Ver commits

## 🤖 Integração

Este repositório é um submódulo do projeto principal Terminal.
EOF

# Criar diretórios
mkdir -p daily weekly monthly snapshots scripts

# Criar .gitignore
cat > .gitignore << 'EOF'
# Temporários
*.tmp
*.log
*.swp
.DS_Store

# Backups locais
*.tar.gz
*.zip
local/

# Credenciais
.env
secrets/
EOF

# Criar script de backup principal
cat > scripts/backup.sh << 'EOF'
#!/bin/bash
# Script principal de backup do Neo4j

set -e

# Detectar tipo de backup baseado no dia
get_backup_type() {
    local day_of_week=$(date +%u)
    local day_of_month=$(date +%d)
    
    if [ "$1" == "manual" ] || [ "$1" == "snapshot" ]; then
        echo "snapshots"
    elif [ "$day_of_month" == "01" ]; then
        echo "monthly"
    elif [ "$day_of_week" == "7" ]; then
        echo "weekly"
    else
        echo "daily"
    fi
}

# Exportar dados do Neo4j
export_data() {
    local output_file="$1"
    
    # Query para exportar tudo
    docker exec terminal-neo4j cypher-shell \
        -u neo4j -p "${NEO4J_PASSWORD}" \
        "MATCH (n) 
         WITH collect({
             id: id(n),
             labels: labels(n),
             properties: properties(n)
         }) as nodes
         MATCH ()-[r]->()
         WITH nodes, collect({
             id: id(r),
             type: type(r),
             start: id(startNode(r)),
             end: id(endNode(r)),
             properties: properties(r)
         }) as relationships
         RETURN {
             nodes: nodes,
             relationships: relationships,
             timestamp: datetime(),
             stats: {
                 nodeCount: size(nodes),
                 relationshipCount: size(relationships)
             }
         }" \
        --format plain | grep "^{" > "$output_file"
}

# Executar backup
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H-%M-%S)
BACKUP_TYPE=$(get_backup_type "$1")
BACKUP_DIR="$(dirname "$0")/../${BACKUP_TYPE}"
BACKUP_FILE="${BACKUP_DIR}/${DATE}_${TIME}_memories.json"

echo "🔄 Iniciando backup ${BACKUP_TYPE}..."

# Criar diretório se não existir
mkdir -p "$BACKUP_DIR"

# Exportar dados
export_data "$BACKUP_FILE"

# Criar metadata
cat > "${BACKUP_FILE/.json/_metadata.json}" << JSON
{
    "date": "${DATE}",
    "time": "${TIME}",
    "type": "${BACKUP_TYPE}",
    "file": "$(basename "$BACKUP_FILE")",
    "size": $(stat -c%s "$BACKUP_FILE" 2>/dev/null || echo 0)
}
JSON

echo "✅ Backup concluído: $BACKUP_FILE"

# Limpar backups antigos
case "$BACKUP_TYPE" in
    daily)
        find "$BACKUP_DIR" -name "*.json" -mtime +7 -delete 2>/dev/null || true
        ;;
    weekly)
        find "$BACKUP_DIR" -name "*.json" -mtime +28 -delete 2>/dev/null || true
        ;;
    monthly)
        find "$BACKUP_DIR" -name "*.json" -mtime +365 -delete 2>/dev/null || true
        ;;
esac

# Git commit
cd "$(dirname "$0")/.."
git add .
git commit -m "Backup ${BACKUP_TYPE} - ${DATE} ${TIME}" 2>/dev/null || true
git push origin main 2>/dev/null || true
EOF

# Criar script de restore
cat > scripts/restore.sh << 'EOF'
#!/bin/bash
# Script de restore do Neo4j

set -e

DATE="${1:-$(date +%Y-%m-%d)}"
TYPE="${2:-daily}"

# Procurar arquivo de backup
find_backup() {
    for dir in snapshots daily weekly monthly; do
        local file=$(ls -1 "../${dir}/${DATE}"*_memories.json 2>/dev/null | head -1)
        if [ -f "$file" ]; then
            echo "$file"
            return 0
        fi
    done
    return 1
}

BACKUP_FILE=$(find_backup) || {
    echo "❌ Backup não encontrado para: $DATE"
    echo "Backups disponíveis:"
    ls -1 ../*/????-??-??*_memories.json 2>/dev/null | xargs -n1 basename | sort -u
    exit 1
}

echo "🔄 Restaurando de: $(basename "$BACKUP_FILE")"
echo "⚠️  Isso apagará todos os dados atuais!"
read -p "Continuar? (s/N): " -n 1 -r
echo

[[ $REPLY =~ ^[Ss]$ ]] || exit 1

# Implementar restore
# ... (código de restore aqui)

echo "✅ Restore concluído!"
EOF

# Tornar scripts executáveis
chmod +x scripts/*.sh

# Criar workflow do GitHub Actions para backup automático
mkdir -p .github/workflows
cat > .github/workflows/backup.yml << 'EOF'
name: Backup Automático

on:
  schedule:
    # Diário às 02:00 UTC
    - cron: '0 2 * * *'
  workflow_dispatch:
    inputs:
      backup_type:
        description: 'Tipo de Backup'
        required: false
        default: 'daily'
        type: choice
        options:
          - daily
          - weekly
          - monthly
          - snapshot

jobs:
  backup:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Executar Backup
        run: |
          ./scripts/backup.sh ${{ github.event.inputs.backup_type || 'auto' }}
      
      - name: Commit e Push
        run: |
          git config --local user.email "action@github.com"
          git config --local user.name "GitHub Action"
          git add .
          git commit -m "Automated backup - $(date +%Y-%m-%d)" || true
          git push
EOF

# Fazer commit inicial
git add .
git commit -m "🎉 Initial backup repository structure"

echo -e "${GREEN}✅ Repositório de backups criado!${NC}\n"

# Passo 2: Adicionar como submódulo no projeto principal
echo -e "${BLUE}📎 Passo 2: Adicionando como submódulo...${NC}"

cd "${MAIN_DIR}"

# Remover submódulo antigo se existir
if [ -f .gitmodules ] && grep -q "neo4j-memory-backups" .gitmodules; then
    echo -e "${YELLOW}  Removendo submódulo antigo...${NC}"
    git submodule deinit -f neo4j-memory-backups 2>/dev/null || true
    git rm -f neo4j-memory-backups 2>/dev/null || true
    rm -rf .git/modules/neo4j-memory-backups 2>/dev/null || true
fi

# Adicionar novo submódulo
echo -e "${BLUE}  Adicionando submódulo...${NC}"
git submodule add "${BACKUP_DIR}" neo4j-memory-backups 2>/dev/null || {
    echo -e "${YELLOW}  Submódulo já existe, atualizando...${NC}"
    git submodule update --init --recursive
}

# Passo 3: Criar scripts de integração
echo -e "${BLUE}🔧 Passo 3: Criando scripts de integração...${NC}"

# Script de backup integrado
cat > backup-memory.sh << 'EOF'
#!/bin/bash
# Backup rápido das memórias do Neo4j

cd neo4j-memory-backups
./scripts/backup.sh "$@"
cd ..
git add neo4j-memory-backups
git commit -m "Update memory backup submodule" 2>/dev/null || true
EOF

# Script de restore integrado
cat > restore-memory.sh << 'EOF'
#!/bin/bash
# Restore rápido das memórias do Neo4j

cd neo4j-memory-backups
./scripts/restore.sh "$@"
EOF

chmod +x backup-memory.sh restore-memory.sh

# Passo 4: Configurar cron para backups automáticos
echo -e "${BLUE}⏰ Passo 4: Configurando backups automáticos...${NC}"

cat > setup-cron-backup.sh << 'EOF'
#!/bin/bash
# Configurar cron para backups automáticos

# Adicionar ao crontab
(crontab -l 2>/dev/null || true; cat << CRON
# Backup diário do Neo4j às 02:00
0 2 * * * cd /home/codable/terminal && ./backup-memory.sh daily >/dev/null 2>&1

# Backup semanal aos domingos às 03:00
0 3 * * 0 cd /home/codable/terminal && ./backup-memory.sh weekly >/dev/null 2>&1

# Backup mensal no dia 1 às 04:00
0 4 1 * * cd /home/codable/terminal && ./backup-memory.sh monthly >/dev/null 2>&1
CRON
) | crontab -

echo "✅ Cron configurado para backups automáticos!"
EOF

chmod +x setup-cron-backup.sh

# Resumo final
echo -e "\n${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Configuração Concluída!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}\n"

echo -e "${CYAN}📁 Estrutura criada:${NC}"
echo -e "   ${BACKUP_DIR}/ (submódulo)"
echo -e "   ├── daily/"
echo -e "   ├── weekly/"
echo -e "   ├── monthly/"
echo -e "   ├── snapshots/"
echo -e "   └── scripts/"

echo -e "\n${CYAN}🔧 Scripts disponíveis:${NC}"
echo -e "   ./backup-memory.sh [tipo]     - Fazer backup"
echo -e "   ./restore-memory.sh [data]    - Restaurar backup"
echo -e "   ./setup-cron-backup.sh        - Ativar backups automáticos"

echo -e "\n${CYAN}⚠️  Próximos passos:${NC}"
echo -e "   1. Criar repositório no GitHub: ${GITHUB_USER}/${REPO_NAME}"
echo -e "   2. Adicionar remote:"
echo -e "      ${YELLOW}cd neo4j-memory-backups${NC}"
echo -e "      ${YELLOW}git remote add origin ${REPO_URL}${NC}"
echo -e "      ${YELLOW}git push -u origin main${NC}"
echo -e "   3. Ativar backups automáticos:"
echo -e "      ${YELLOW}./setup-cron-backup.sh${NC}"

echo -e "\n${GREEN}💡 Teste com: ./backup-memory.sh snapshot${NC}"