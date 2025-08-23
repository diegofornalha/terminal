#!/bin/bash
# 🔄 Terminal System - Script de Restart Rápido

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         🔄 TERMINAL SYSTEM - RESTART RÁPIDO           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Diretório do projeto
PROJECT_DIR="/home/codable/terminal"
cd "$PROJECT_DIR" || exit 1

# Função para mostrar status
show_status() {
    local service=$1
    local status=$2
    if [ "$status" = "ok" ]; then
        echo -e "  ${GREEN}✅${NC} $service"
    else
        echo -e "  ${RED}❌${NC} $service"
    fi
}

# Opções de restart
if [ "$1" = "--hard" ]; then
    echo -e "${YELLOW}🔧 Modo HARD: Reconstruindo containers...${NC}"
    echo ""
    
    echo "1. Parando todos os containers..."
    docker-compose down
    
    echo "2. Removendo volumes órfãos..."
    docker volume prune -f 2>/dev/null
    
    echo "3. Reconstruindo imagens..."
    docker-compose build
    
    echo "4. Iniciando containers..."
    docker-compose up -d
    
elif [ "$1" = "--soft" ]; then
    echo -e "${YELLOW}🔧 Modo SOFT: Apenas reiniciando containers...${NC}"
    echo ""
    
    echo "1. Reiniciando containers..."
    docker-compose restart
    
elif [ "$1" = "--quick" ]; then
    echo -e "${YELLOW}⚡ Modo QUICK: Restart do serviço especificado...${NC}"
    SERVICE=$2
    if [ -z "$SERVICE" ]; then
        echo -e "${RED}Erro: Especifique o serviço (api, web, neo4j)${NC}"
        exit 1
    fi
    
    echo "Reiniciando $SERVICE..."
    docker-compose restart $SERVICE
    
else
    # Modo padrão - restart inteligente
    echo -e "${YELLOW}🤖 Modo INTELIGENTE: Detectando melhor estratégia...${NC}"
    echo ""
    
    # Verificar se containers estão rodando
    RUNNING=$(docker-compose ps -q | wc -l)
    
    if [ "$RUNNING" -eq 0 ]; then
        echo "Nenhum container rodando. Iniciando sistema..."
        docker-compose up -d
    else
        echo "Containers detectados. Fazendo restart graceful..."
        
        # Restart na ordem correta
        echo -n "  1. Neo4j..."
        docker-compose restart neo4j 2>/dev/null && echo -e " ${GREEN}✓${NC}" || echo -e " ${RED}✗${NC}"
        
        sleep 2
        
        echo -n "  2. API..."
        docker-compose restart api 2>/dev/null && echo -e " ${GREEN}✓${NC}" || echo -e " ${RED}✗${NC}"
        
        echo -n "  3. Web..."
        docker-compose restart web 2>/dev/null && echo -e " ${GREEN}✓${NC}" || echo -e " ${RED}✗${NC}"
    fi
fi

echo ""
echo -e "${BLUE}═══ Aguardando serviços ficarem prontos... ═══${NC}"

# Aguardar serviços
MAX_WAIT=30
COUNTER=0

while [ $COUNTER -lt $MAX_WAIT ]; do
    # Verificar cada serviço
    API_OK=$(curl -s http://localhost:8000/health 2>/dev/null | grep -q '"ok":true' && echo "ok" || echo "fail")
    WEB_OK=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3005 2>/dev/null | grep -q "200" && echo "ok" || echo "fail")
    NEO4J_OK=$(nc -zv localhost 7687 2>&1 | grep -q succeeded && echo "ok" || echo "fail")
    
    # Se todos ok, sair
    if [ "$API_OK" = "ok" ] && [ "$WEB_OK" = "ok" ] && [ "$NEO4J_OK" = "ok" ]; then
        break
    fi
    
    echo -n "."
    sleep 1
    COUNTER=$((COUNTER + 1))
done

echo ""
echo ""
echo -e "${BLUE}═══ Status Final ═══${NC}"
show_status "API" "$API_OK"
show_status "Frontend" "$WEB_OK"
show_status "Neo4j" "$NEO4J_OK"

echo ""

# Verificar MCP
echo -e "${BLUE}═══ Verificando MCP ═══${NC}"
MCP_STATUS=$(docker exec terminal-api claude mcp list 2>/dev/null | grep -q neo4j-memory && echo "ok" || echo "fail")
show_status "MCP Neo4j Memory" "$MCP_STATUS"

echo ""

# Status geral
if [ "$API_OK" = "ok" ] && [ "$WEB_OK" = "ok" ] && [ "$NEO4J_OK" = "ok" ] && [ "$MCP_STATUS" = "ok" ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       ✅ SISTEMA REINICIADO COM SUCESSO!              ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "📌 Acesse:"
    echo "   Frontend: http://localhost:3005"
    echo "   API: http://localhost:8000"
    echo "   Neo4j: http://localhost:7474"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║       ⚠️  ALGUNS SERVIÇOS NÃO INICIARAM              ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "💡 Sugestões:"
    echo "   1. Verifique os logs: docker-compose logs"
    echo "   2. Tente restart hard: ./restart.sh --hard"
    echo "   3. Execute diagnóstico: ./scripts/health-check.sh"
    exit 1
fi