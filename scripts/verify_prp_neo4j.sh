#!/bin/bash

# Script para verificar os dados do PRP no Neo4j

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

echo "📊 Verificando dados do PRP no Neo4j..."
echo ""

# Função para executar query e mostrar resultado
query_neo4j() {
    local query="$1"
    local description="$2"
    
    echo "🔍 $description"
    
    result=$(curl -s -X POST "$NEO4J_URL" \
        -u "$NEO4J_USER:$NEO4J_PASS" \
        -H "Content-Type: application/json" \
        -d "{\"statements\": [{\"statement\": \"$query\"}]}")
    
    # Extrair apenas os dados relevantes
    echo "$result" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'results' in data and len(data['results']) > 0:
        result = data['results'][0]
        if 'data' in result and len(result['data']) > 0:
            columns = result.get('columns', [])
            if columns:
                print('   Colunas:', ', '.join(columns))
            for row in result['data']:
                if 'row' in row:
                    print('   -', row['row'])
        else:
            print('   Nenhum resultado encontrado')
    else:
        print('   Erro na query')
except:
    print('   Erro ao processar resultado')
" 2>/dev/null
    echo ""
}

# Verificar projeto principal
query_neo4j "MATCH (p:project {name: 'PRP Terminal Enhancement'}) RETURN p.name as nome, p.methodology as metodologia, p.status as status" \
    "Projeto Principal:"

# Contar nós por tipo
query_neo4j "MATCH (n) WHERE n.name = 'PRP Terminal Enhancement' OR (n)-[:HAS_PHASE|USES_COMPONENT|USES_TECHNOLOGY|HAS_METRIC|HAS_RISK]-(p:project {name: 'PRP Terminal Enhancement'}) RETURN labels(n)[0] as tipo, count(n) as quantidade ORDER BY tipo" \
    "Contagem de nós relacionados ao PRP:"

# Listar fases
query_neo4j "MATCH (p:project {name: 'PRP Terminal Enhancement'})-[:HAS_PHASE]->(ph:phase) RETURN ph.name as fase, ph.order as ordem ORDER BY ph.order" \
    "Fases do Projeto:"

# Listar componentes
query_neo4j "MATCH (p:project {name: 'PRP Terminal Enhancement'})-[:USES_COMPONENT]->(c:component) RETURN c.name as componente, c.type as tipo" \
    "Componentes:"

# Listar tecnologias
query_neo4j "MATCH (p:project {name: 'PRP Terminal Enhancement'})-[:USES_TECHNOLOGY]->(t:technology) RETURN t.name as tecnologia, t.type as tipo" \
    "Tecnologias:"

# Listar métricas
query_neo4j "MATCH (p:project {name: 'PRP Terminal Enhancement'})-[:HAS_METRIC]->(m:metric) RETURN m.name as metrica, m.target as alvo" \
    "Métricas de Sucesso:"

# Listar riscos
query_neo4j "MATCH (p:project {name: 'PRP Terminal Enhancement'})-[:HAS_RISK]->(r:risk) RETURN r.name as risco, r.severity as severidade" \
    "Riscos Identificados:"

# Contar relacionamentos
query_neo4j "MATCH (p:project {name: 'PRP Terminal Enhancement'})-[r]-() RETURN type(r) as tipo_relacionamento, count(r) as quantidade GROUP BY type(r) ORDER BY quantidade DESC" \
    "Tipos de Relacionamentos:"

echo "✅ Verificação concluída!"
echo ""
echo "💡 Para visualizar o grafo completo:"
echo "   1. Acesse http://localhost:7474"
echo "   2. Execute: MATCH (p:project {name: 'PRP Terminal Enhancement'})-[r]-(n) RETURN p, r, n"