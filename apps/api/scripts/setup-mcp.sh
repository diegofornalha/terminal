#!/bin/bash
# Setup MCP Neo4j Agent Memory in Docker container

echo "🔧 Configurando MCP Neo4j Agent Memory..."

# Check if MCP_AUTO_REGISTER is enabled
if [ "$MCP_AUTO_REGISTER" != "true" ]; then
    echo "⚠️  MCP auto-register desabilitado. Pulando configuração."
    exit 0
fi

# Wait for Neo4j to be ready
echo "⏳ Aguardando Neo4j estar pronto..."
for i in {1..30}; do
    if nc -z terminal-neo4j 7687 2>/dev/null; then
        echo "✅ Neo4j está acessível!"
        break
    fi
    echo "   Tentativa $i/30..."
    sleep 2
done

# Check if Neo4j is accessible
if ! nc -z terminal-neo4j 7687 2>/dev/null; then
    echo "❌ Neo4j não está acessível. Pulando configuração do MCP."
    exit 1
fi

# Check if MCP is already registered
if claude mcp list 2>/dev/null | grep -q "neo4j-memory"; then
    echo "✅ MCP Neo4j já está registrado"
else
    echo "📝 Registrando MCP Neo4j Agent Memory..."
    
    # Create MCP configuration
    cat > /tmp/mcp-config.json << EOF
{
  "command": "node",
  "args": ["/app/mcp-neo4j-agent-memory/build/index.js"],
  "env": {
    "NEO4J_URI": "${NEO4J_URI:-bolt://terminal-neo4j:7687}",
    "NEO4J_USERNAME": "${NEO4J_USERNAME:-neo4j}",
    "NEO4J_PASSWORD": "${NEO4J_PASSWORD:-password}",
    "NEO4J_DATABASE": "${NEO4J_DATABASE:-neo4j}"
  }
}
EOF

    # Register MCP with Claude
    if claude mcp add-json neo4j-memory "$(cat /tmp/mcp-config.json)" 2>/dev/null; then
        echo "✅ MCP registrado com sucesso!"
        
        # Test connection
        echo "🔍 Testando conexão..."
        if claude mcp list 2>/dev/null | grep -q "neo4j-memory.*Connected"; then
            echo "✅ MCP Neo4j conectado e funcionando!"
        else
            echo "⚠️  MCP registrado mas não conectado. Verifique as credenciais."
        fi
    else
        echo "❌ Falha ao registrar MCP"
        exit 1
    fi
    
    # Clean up
    rm -f /tmp/mcp-config.json
fi

# Setup worktree isolation if enabled
if [ "$MCP_WORKTREE_ISOLATION" = "true" ]; then
    echo "🔒 Configurando isolamento por worktree..."
    
    # Get current worktree or project
    CURRENT_WORKTREE=$(git rev-parse --show-toplevel 2>/dev/null | xargs basename 2>/dev/null)
    
    if [ -n "$CURRENT_WORKTREE" ]; then
        export NEO4J_LABEL_PREFIX="${CURRENT_WORKTREE}_"
        echo "   Prefixo de isolamento: $NEO4J_LABEL_PREFIX"
    fi
fi

echo "✨ Configuração do MCP concluída!"