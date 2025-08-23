#!/bin/bash
# 🏥 Terminal System Health Check
# Verifica se todos os componentes críticos estão funcionando

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}       🏥 TERMINAL SYSTEM HEALTH CHECK${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Contador de erros
ERRORS=0
WARNINGS=0

# Função para verificar status
check_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
        ERRORS=$((ERRORS + 1))
    fi
}

# Função para warning
warning_status() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    WARNINGS=$((WARNINGS + 1))
}

echo -e "${BLUE}1. DOCKER CONTAINERS${NC}"
echo "-------------------"

# Verificar terminal-api
docker ps | grep -q "terminal-api.*healthy"
check_status $? "terminal-api (Backend FastAPI)"

# Verificar terminal-web
docker ps | grep -q "terminal-web.*healthy\|starting"
check_status $? "terminal-web (Frontend Next.js)"

# Verificar terminal-neo4j
docker ps | grep -q "terminal-neo4j.*healthy"
check_status $? "terminal-neo4j (Database)"

echo ""
echo -e "${BLUE}2. SERVIÇOS DE REDE${NC}"
echo "-------------------"

# Verificar API endpoint
curl -s http://localhost:8000/health > /dev/null 2>&1
check_status $? "API Health endpoint (porta 8000)"

# Verificar Frontend
curl -s http://localhost:3005 | grep -q "Terminal Web" > /dev/null 2>&1
check_status $? "Frontend Web (porta 3005)"

# Verificar Neo4j
nc -zv localhost 7687 > /dev/null 2>&1
check_status $? "Neo4j Bolt (porta 7687)"

echo ""
echo -e "${BLUE}3. MCP NEO4J AGENT MEMORY${NC}"
echo "-------------------------"

# Verificar MCP no container
MCP_STATUS=$(docker exec terminal-api claude mcp list 2>/dev/null | grep neo4j-memory)
if [[ $MCP_STATUS == *"Connected"* ]]; then
    echo -e "${GREEN}✅ MCP Neo4j conectado${NC}"
    echo "   $MCP_STATUS"
else
    echo -e "${RED}❌ MCP Neo4j não conectado${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo -e "${BLUE}4. CLAUDE SAFE${NC}"
echo "--------------"

# Verificar Claude Safe local
if command -v claude-safe &> /dev/null; then
    CLAUDE_VERSION=$(claude-safe --version 2>/dev/null)
    echo -e "${GREEN}✅ Claude Safe instalado${NC}"
    echo "   Versão: $CLAUDE_VERSION"
else
    echo -e "${RED}❌ Claude Safe não encontrado${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Verificar aliases
ALIAS_COUNT=$(alias | grep -c claude)
if [ $ALIAS_COUNT -gt 0 ]; then
    echo -e "${GREEN}✅ $ALIAS_COUNT aliases do Claude configurados${NC}"
else
    warning_status "Nenhum alias do Claude encontrado"
fi

echo ""
echo -e "${BLUE}5. SISTEMA DE ARQUIVOS${NC}"
echo "----------------------"

# Verificar diretórios críticos
CRITICAL_DIRS=(
    "/home/codable/terminal/apps/api"
    "/home/codable/terminal/apps/web"
    "/home/codable/terminal/docs"
    "/home/codable/terminal/mcp-neo4j-agent-memory"
)

for dir in "${CRITICAL_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✅ $dir${NC}"
    else
        echo -e "${RED}❌ $dir não encontrado${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo -e "${BLUE}6. PROBLEMAS CONHECIDOS${NC}"
echo "-----------------------"

# Verificar WebSocket proxy (problema conhecido)
if grep -q "Temporarily disable WebSocket proxy" /home/codable/terminal/apps/web/server.js 2>/dev/null; then
    warning_status "WebSocket proxy desabilitado (workaround ativo)"
fi

# Verificar espaço em disco
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    warning_status "Uso de disco alto: ${DISK_USAGE}%"
elif [ $DISK_USAGE -gt 90 ]; then
    echo -e "${RED}❌ Disco quase cheio: ${DISK_USAGE}%${NC}"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✅ Espaço em disco OK: ${DISK_USAGE}% usado${NC}"
fi

echo ""
echo -e "${BLUE}7. MEMÓRIA E CPU${NC}"
echo "----------------"

# Verificar memória
MEM_USAGE=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
if [ $MEM_USAGE -gt 90 ]; then
    warning_status "Uso de memória alto: ${MEM_USAGE}%"
else
    echo -e "${GREEN}✅ Memória OK: ${MEM_USAGE}% usado${NC}"
fi

# Verificar load average
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}')
echo -e "${GREEN}✅ Load Average:${LOAD_AVG}${NC}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                    RESUMO${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}🎉 Sistema 100% saudável!${NC}"
    EXIT_CODE=0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Sistema funcionando com $WARNINGS avisos${NC}"
    EXIT_CODE=0
else
    echo -e "${RED}❌ Sistema com $ERRORS erros e $WARNINGS avisos${NC}"
    echo ""
    echo -e "${YELLOW}Ações recomendadas:${NC}"
    echo "1. Verificar logs: docker-compose logs"
    echo "2. Reiniciar containers: docker-compose restart"
    echo "3. Consultar: /home/codable/terminal/CRITICAL_COMPONENTS.md"
    EXIT_CODE=1
fi

echo ""
echo -e "${BLUE}Última verificação: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

exit $EXIT_CODE