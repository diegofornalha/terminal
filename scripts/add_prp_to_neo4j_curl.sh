#!/bin/bash

# Script para adicionar informações do PRP ao Neo4j usando curl

NEO4J_URL="http://localhost:7474/db/neo4j/tx/commit"
NEO4J_USER="neo4j"
# Carregar variável de ambiente
if [ -f /home/codable/terminal/.env ]; then
    export $(grep NEO4J_PASSWORD /home/codable/terminal/.env | xargs)
fi

if [ -z "$NEO4J_PASSWORD" ]; then
    echo "Erro: NEO4J_PASSWORD não configurada"
    exit 1
fi
NEO4J_PASS="$NEO4J_PASSWORD"

echo "🚀 Adicionando PRP ao Neo4j..."

# Função para executar query Cypher
execute_cypher() {
    local query="$1"
    local response=$(curl -s -X POST "$NEO4J_URL" \
        -u "$NEO4J_USER:$NEO4J_PASS" \
        -H "Content-Type: application/json" \
        -d "{\"statements\": [{\"statement\": \"$query\"}]}")
    
    if echo "$response" | grep -q '"errors":\[\]'; then
        return 0
    else
        echo "Erro na query: $response"
        return 1
    fi
}

# Limpar dados existentes
echo "Limpando dados PRP existentes..."
execute_cypher "MATCH (n:project {name: 'PRP Terminal Enhancement'}) DETACH DELETE n"

# Criar nó principal do projeto
echo "Criando nó do projeto PRP..."
execute_cypher "CREATE (p:project {name: 'PRP Terminal Enhancement', description: 'Melhoria do Sistema de Acesso Remoto ao Terminal', status: 'active', created_at: datetime(), methodology: 'PRP', objetivo: 'Aprimorar o sistema de acesso remoto ao terminal para garantir confiabilidade, segurança e experiência de usuário superior'})"

# Criar fases
echo "Criando fases do projeto..."
execute_cypher "CREATE (ph:phase {name: 'Fase 1 - Reconexão Automática', description: 'Implementar reconexão automática com heartbeat', status: 'pending', order: 1, created_at: datetime()})"
execute_cypher "CREATE (ph:phase {name: 'Fase 2 - Autenticação', description: 'Adicionar sistema de autenticação para terminal', status: 'pending', order: 2, created_at: datetime()})"
execute_cypher "CREATE (ph:phase {name: 'Fase 3 - Histórico Persistente', description: 'Implementar histórico de comandos persistente', status: 'pending', order: 3, created_at: datetime()})"
execute_cypher "CREATE (ph:phase {name: 'Fase 4 - Interface de Status', description: 'Criar interface visual de status', status: 'pending', order: 4, created_at: datetime()})"

# Conectar fases ao projeto
echo "Conectando fases ao projeto..."
execute_cypher "MATCH (p:project {name: 'PRP Terminal Enhancement'}), (ph:phase {name: 'Fase 1 - Reconexão Automática'}) CREATE (p)-[:HAS_PHASE {order: 1}]->(ph)"
execute_cypher "MATCH (p:project {name: 'PRP Terminal Enhancement'}), (ph:phase {name: 'Fase 2 - Autenticação'}) CREATE (p)-[:HAS_PHASE {order: 2}]->(ph)"
execute_cypher "MATCH (p:project {name: 'PRP Terminal Enhancement'}), (ph:phase {name: 'Fase 3 - Histórico Persistente'}) CREATE (p)-[:HAS_PHASE {order: 3}]->(ph)"
execute_cypher "MATCH (p:project {name: 'PRP Terminal Enhancement'}), (ph:phase {name: 'Fase 4 - Interface de Status'}) CREATE (p)-[:HAS_PHASE {order: 4}]->(ph)"

# Criar componentes
echo "Criando componentes..."
execute_cypher "CREATE (c:component {name: 'EnhancedTerminalWebSocket', type: 'class', file: '/home/codable/terminal/apps/api/app/claudable_terminal/enhanced_websocket.py', description: 'WebSocket melhorado com reconexão automática e heartbeat', created_at: datetime()})"
execute_cypher "CREATE (c:component {name: 'TerminalAuth', type: 'class', file: '/home/codable/terminal/apps/api/app/core/auth/terminal_auth.py', description: 'Autenticação para acesso remoto ao terminal', created_at: datetime()})"
execute_cypher "CREATE (c:component {name: 'TerminalHistory', type: 'model', file: '/home/codable/terminal/apps/api/app/models/terminal_history.py', description: 'Modelo de banco de dados para histórico de comandos', created_at: datetime()})"
execute_cypher "CREATE (c:component {name: 'WebSocketManager', type: 'class', file: '/home/codable/terminal/apps/api/app/core/websocket/manager.py', description: 'Gerenciador de conexões WebSocket existente', created_at: datetime()})"

# Conectar componentes ao projeto
echo "Conectando componentes ao projeto..."
execute_cypher "MATCH (p:project {name: 'PRP Terminal Enhancement'}), (c:component {name: 'EnhancedTerminalWebSocket'}) CREATE (p)-[:USES_COMPONENT]->(c)"
execute_cypher "MATCH (p:project {name: 'PRP Terminal Enhancement'}), (c:component {name: 'TerminalAuth'}) CREATE (p)-[:USES_COMPONENT]->(c)"
execute_cypher "MATCH (p:project {name: 'PRP Terminal Enhancement'}), (c:component {name: 'TerminalHistory'}) CREATE (p)-[:USES_COMPONENT]->(c)"
execute_cypher "MATCH (p:project {name: 'PRP Terminal Enhancement'}), (c:component {name: 'WebSocketManager'}) CREATE (p)-[:USES_COMPONENT]->(c)"

# Criar tecnologias
echo "Criando tecnologias..."
execute_cypher "CREATE (t:technology {name: 'FastAPI', type: 'framework', purpose: 'WebSocket support', created_at: datetime()})"
execute_cypher "CREATE (t:technology {name: 'SQLAlchemy', type: 'orm', purpose: 'Persistência de dados', created_at: datetime()})"
execute_cypher "CREATE (t:technology {name: 'JWT', type: 'authentication', purpose: 'Tokens de autenticação', created_at: datetime()})"
execute_cypher "CREATE (t:technology {name: 'asyncio', type: 'library', purpose: 'Operações assíncronas', created_at: datetime()})"
execute_cypher "CREATE (t:technology {name: 'Docker', type: 'containerization', purpose: 'Sandboxing e isolamento', created_at: datetime()})"

# Conectar tecnologias ao projeto
echo "Conectando tecnologias ao projeto..."
execute_cypher "MATCH (p:project {name: 'PRP Terminal Enhancement'}), (t:technology {name: 'FastAPI'}) CREATE (p)-[:USES_TECHNOLOGY]->(t)"
execute_cypher "MATCH (p:project {name: 'PRP Terminal Enhancement'}), (t:technology {name: 'SQLAlchemy'}) CREATE (p)-[:USES_TECHNOLOGY]->(t)"
execute_cypher "MATCH (p:project {name: 'PRP Terminal Enhancement'}), (t:technology {name: 'JWT'}) CREATE (p)-[:USES_TECHNOLOGY]->(t)"
execute_cypher "MATCH (p:project {name: 'PRP Terminal Enhancement'}), (t:technology {name: 'asyncio'}) CREATE (p)-[:USES_TECHNOLOGY]->(t)"
execute_cypher "MATCH (p:project {name: 'PRP Terminal Enhancement'}), (t:technology {name: 'Docker'}) CREATE (p)-[:USES_TECHNOLOGY]->(t)"

# Criar métricas
echo "Criando métricas de sucesso..."
execute_cypher "CREATE (m:metric {name: 'Tempo de Reconexão', target: '< 2 segundos', type: 'performance', created_at: datetime()})"
execute_cypher "CREATE (m:metric {name: 'Taxa de Sucesso de Reconexão', target: '> 95%', type: 'reliability', created_at: datetime()})"
execute_cypher "CREATE (m:metric {name: 'Latência de Comando', target: '< 50ms', type: 'performance', created_at: datetime()})"
execute_cypher "CREATE (m:metric {name: 'Uptime do Serviço', target: '> 99.9%', type: 'availability', created_at: datetime()})"
execute_cypher "CREATE (m:metric {name: 'Perda de Histórico', target: 'Zero', type: 'data_integrity', created_at: datetime()})"

# Conectar métricas ao projeto
echo "Conectando métricas ao projeto..."
execute_cypher "MATCH (p:project {name: 'PRP Terminal Enhancement'}), (m:metric {name: 'Tempo de Reconexão'}) CREATE (p)-[:HAS_METRIC]->(m)"
execute_cypher "MATCH (p:project {name: 'PRP Terminal Enhancement'}), (m:metric {name: 'Taxa de Sucesso de Reconexão'}) CREATE (p)-[:HAS_METRIC]->(m)"
execute_cypher "MATCH (p:project {name: 'PRP Terminal Enhancement'}), (m:metric {name: 'Latência de Comando'}) CREATE (p)-[:HAS_METRIC]->(m)"
execute_cypher "MATCH (p:project {name: 'PRP Terminal Enhancement'}), (m:metric {name: 'Uptime do Serviço'}) CREATE (p)-[:HAS_METRIC]->(m)"
execute_cypher "MATCH (p:project {name: 'PRP Terminal Enhancement'}), (m:metric {name: 'Perda de Histórico'}) CREATE (p)-[:HAS_METRIC]->(m)"

# Criar riscos
echo "Criando riscos identificados..."
execute_cypher "CREATE (r:risk {name: 'Segurança - Execução de comandos', severity: 'high', mitigation: 'Implementar whitelist de comandos e sandboxing via Docker', created_at: datetime()})"
execute_cypher "CREATE (r:risk {name: 'Performance - Múltiplas conexões', severity: 'medium', mitigation: 'Pool de conexões e rate limiting por usuário', created_at: datetime()})"
execute_cypher "CREATE (r:risk {name: 'Estabilidade - Reconexões frequentes', severity: 'medium', mitigation: 'Backoff exponencial e circuit breaker pattern', created_at: datetime()})"

# Conectar riscos ao projeto
echo "Conectando riscos ao projeto..."
execute_cypher "MATCH (p:project {name: 'PRP Terminal Enhancement'}), (r:risk {name: 'Segurança - Execução de comandos'}) CREATE (p)-[:HAS_RISK]->(r)"
execute_cypher "MATCH (p:project {name: 'PRP Terminal Enhancement'}), (r:risk {name: 'Performance - Múltiplas conexões'}) CREATE (p)-[:HAS_RISK]->(r)"
execute_cypher "MATCH (p:project {name: 'PRP Terminal Enhancement'}), (r:risk {name: 'Estabilidade - Reconexões frequentes'}) CREATE (p)-[:HAS_RISK]->(r)"

# Criar relacionamentos entre fases
echo "Criando relacionamentos entre fases..."
execute_cypher "MATCH (ph1:phase), (ph2:phase) WHERE ph1.order = ph2.order - 1 CREATE (ph1)-[:PRECEDES]->(ph2)"

# Relacionar componentes com fases
echo "Relacionando componentes com fases..."
execute_cypher "MATCH (c:component {name: 'EnhancedTerminalWebSocket'}), (ph:phase {name: 'Fase 1 - Reconexão Automática'}) CREATE (ph)-[:IMPLEMENTS_COMPONENT]->(c)"
execute_cypher "MATCH (c:component {name: 'TerminalAuth'}), (ph:phase {name: 'Fase 2 - Autenticação'}) CREATE (ph)-[:IMPLEMENTS_COMPONENT]->(c)"
execute_cypher "MATCH (c:component {name: 'TerminalHistory'}), (ph:phase {name: 'Fase 3 - Histórico Persistente'}) CREATE (ph)-[:IMPLEMENTS_COMPONENT]->(c)"
execute_cypher "MATCH (c:component {name: 'WebSocketManager'}), (ph:phase {name: 'Fase 1 - Reconexão Automática'}) CREATE (ph)-[:IMPLEMENTS_COMPONENT]->(c)"

# Relacionar tecnologias com componentes
echo "Relacionando tecnologias com componentes..."
execute_cypher "MATCH (t:technology {name: 'FastAPI'}), (c:component {name: 'EnhancedTerminalWebSocket'}) CREATE (c)-[:USES]->(t)"
execute_cypher "MATCH (t:technology {name: 'JWT'}), (c:component {name: 'TerminalAuth'}) CREATE (c)-[:USES]->(t)"
execute_cypher "MATCH (t:technology {name: 'SQLAlchemy'}), (c:component {name: 'TerminalHistory'}) CREATE (c)-[:USES]->(t)"
execute_cypher "MATCH (t:technology {name: 'asyncio'}), (c:component {name: 'EnhancedTerminalWebSocket'}) CREATE (c)-[:USES]->(t)"
execute_cypher "MATCH (t:technology {name: 'Docker'}), (c:component {name: 'TerminalAuth'}) CREATE (c)-[:USES]->(t)"

# Relacionar riscos com fases
echo "Relacionando riscos com fases..."
execute_cypher "MATCH (r:risk {name: 'Segurança - Execução de comandos'}), (ph:phase {name: 'Fase 2 - Autenticação'}) CREATE (ph)-[:ADDRESSES_RISK]->(r)"
execute_cypher "MATCH (r:risk {name: 'Performance - Múltiplas conexões'}), (ph:phase {name: 'Fase 1 - Reconexão Automática'}) CREATE (ph)-[:ADDRESSES_RISK]->(r)"
execute_cypher "MATCH (r:risk {name: 'Estabilidade - Reconexões frequentes'}), (ph:phase {name: 'Fase 1 - Reconexão Automática'}) CREATE (ph)-[:ADDRESSES_RISK]->(r)"

# Verificar estatísticas
echo ""
echo "📊 Verificando estatísticas do grafo..."
stats=$(curl -s -X POST "$NEO4J_URL" \
    -u "$NEO4J_USER:$NEO4J_PASS" \
    -H "Content-Type: application/json" \
    -d '{"statements": [{"statement": "MATCH (p:project {name: \"PRP Terminal Enhancement\"}) OPTIONAL MATCH (p)-[r]-(connected) RETURN count(distinct connected) as connected_nodes"}]}' | \
    grep -o '"connected_nodes":[0-9]*' | cut -d':' -f2)

echo "   - Nós conectados ao projeto: $stats"

echo ""
echo "✅ PRP adicionado com sucesso ao Neo4j!"
echo ""
echo "📌 Para visualizar o grafo:"
echo "   1. Acesse http://localhost:7474"
echo "   2. Faça login com usuário: $NEO4J_USER e senha: $NEO4J_PASS"
echo "   3. Execute a query: MATCH (p:project {name: 'PRP Terminal Enhancement'})-[r]-(n) RETURN p, r, n"