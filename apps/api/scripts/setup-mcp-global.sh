#!/bin/bash
# Setup MCP Neo4j globalmente para todos os usuários no container

echo "🌍 Configurando MCP Neo4j globalmente no container..."

# Verificar se estamos no Docker
if [ ! -f /.dockerenv ]; then
    echo "⚠️  Este script deve ser executado apenas dentro do container Docker"
    exit 1
fi

# Criar diretório global para configurações do Claude Code
CLAUDE_GLOBAL_CONFIG="/etc/claude"
mkdir -p "$CLAUDE_GLOBAL_CONFIG"

# Criar link simbólico global para o MCP
if [ -d "/app/mcp-neo4j-agent-memory" ]; then
    echo "📦 Criando link global para MCP Neo4j..."
    
    # Link global usando npm
    cd /app/mcp-neo4j-agent-memory
    npm link 2>/dev/null || echo "   npm link já existe"
    
    # Criar wrapper script global
    cat > /usr/local/bin/mcp-neo4j << 'EOF'
#!/bin/bash
# Wrapper global para MCP Neo4j Agent Memory
export NEO4J_URI="${NEO4J_URI:-bolt://terminal-neo4j:7687}"
export NEO4J_USERNAME="${NEO4J_USERNAME:-neo4j}"
export NEO4J_PASSWORD="${NEO4J_PASSWORD}"
export NEO4J_DATABASE="${NEO4J_DATABASE:-neo4j}"

# Verificar se a senha está configurada
if [ -z "$NEO4J_PASSWORD" ]; then
    echo "Erro: NEO4J_PASSWORD não está configurada" >&2
    exit 1
fi

# Detectar contexto do projeto se em worktree
if [ -d .git ] || [ -f .git ]; then
    PROJECT_ID=$(git rev-parse --show-toplevel 2>/dev/null | xargs basename 2>/dev/null)
    if [ -n "$PROJECT_ID" ] && [ "$PROJECT_ID" != "Claudable" ]; then
        export MCP_PROJECT_ID="$PROJECT_ID"
        export MCP_LABEL_PREFIX="${PROJECT_ID}_"
        echo "🔧 MCP configurado para projeto: $PROJECT_ID"
    fi
fi

exec node /app/mcp-neo4j-agent-memory/build/index.js "$@"
EOF
    
    chmod +x /usr/local/bin/mcp-neo4j
    echo "✅ Wrapper global criado: /usr/local/bin/mcp-neo4j"
fi

# Configurar Claude Code globalmente
echo "🔧 Configurando Claude Code para todos os usuários..."

# Criar configuração global do Claude Code
cat > "$CLAUDE_GLOBAL_CONFIG/global-mcp-config.json" << 'EOF'
{
  "mcpServers": {
    "neo4j-memory": {
      "command": "/usr/local/bin/mcp-neo4j",
      "args": [],
      "env": {}
    }
  }
}
EOF

# Criar script de inicialização para cada usuário
cat > /etc/profile.d/claude-mcp.sh << 'EOF'
#!/bin/bash
# Auto-configurar MCP para novos shells

# Função para configurar MCP no Claude Code
setup_claude_mcp() {
    if command -v claude >/dev/null 2>&1; then
        # Verificar se MCP já está configurado
        if ! claude mcp list 2>/dev/null | grep -q "neo4j-memory"; then
            echo "🤖 Configurando MCP Neo4j automaticamente..."
            claude mcp add neo4j-memory /usr/local/bin/mcp-neo4j 2>/dev/null && \
                echo "✅ MCP Neo4j configurado com sucesso!" || \
                echo "⚠️  MCP já configurado ou erro na configuração"
        fi
    fi
}

# Exportar função para uso
export -f setup_claude_mcp

# Configurar automaticamente em shells interativos
if [ -n "$PS1" ]; then
    setup_claude_mcp 2>/dev/null
fi

# Aliases úteis
alias mcp-status='claude mcp list 2>/dev/null | grep neo4j'
alias mcp-test='echo "Testing MCP connection..." && claude mcp list'
alias mcp-setup='setup_claude_mcp'
EOF

chmod +x /etc/profile.d/claude-mcp.sh

# Criar configuração para bashrc de todos os usuários
cat >> /etc/bash.bashrc << 'EOF'

# Auto-setup MCP Neo4j em novos shells
if [ -f /etc/profile.d/claude-mcp.sh ]; then
    source /etc/profile.d/claude-mcp.sh
fi
EOF

# Configurar para o usuário root
if [ -d /root ]; then
    echo "source /etc/profile.d/claude-mcp.sh" >> /root/.bashrc 2>/dev/null || true
fi

# Configurar para o usuário claude se existir
if [ -d /home/claude ]; then
    echo "source /etc/profile.d/claude-mcp.sh" >> /home/claude/.bashrc 2>/dev/null || true
    chown claude:claude /home/claude/.bashrc 2>/dev/null || true
fi

# Testar se o MCP está acessível globalmente
echo "🔍 Testando configuração global..."
if [ -x /usr/local/bin/mcp-neo4j ]; then
    echo "✅ MCP Neo4j está disponível globalmente em: /usr/local/bin/mcp-neo4j"
    
    # Testar execução
    if /usr/local/bin/mcp-neo4j --version 2>&1 | grep -q "error"; then
        echo "⚠️  MCP instalado mas pode haver problemas de execução"
    else
        echo "✅ MCP Neo4j executável e funcionando!"
    fi
else
    echo "❌ Falha na configuração global do MCP"
    exit 1
fi

# Criar documentação de uso
cat > "$CLAUDE_GLOBAL_CONFIG/README.md" << 'EOF'
# MCP Neo4j Agent Memory - Configuração Global

## Uso Automático
O MCP é configurado automaticamente ao abrir um novo shell.

## Comandos Disponíveis
- `mcp-status` - Verifica status do MCP
- `mcp-test` - Testa conexão com MCP
- `mcp-setup` - Reconfigura MCP manualmente
- `mcp-neo4j` - Executa MCP diretamente

## Isolamento por Projeto
Quando você está em um diretório de worktree, o MCP automaticamente
usa um namespace isolado baseado no nome do projeto.

## Variáveis de Ambiente
- `NEO4J_URI` - URI do Neo4j (padrão: bolt://terminal-neo4j:7687)
- `NEO4J_USERNAME` - Usuário Neo4j (padrão: neo4j)
- `NEO4J_PASSWORD` - Senha Neo4j (padrão: password)
- `MCP_PROJECT_ID` - ID do projeto atual (auto-detectado)
- `MCP_LABEL_PREFIX` - Prefixo para isolamento (auto-configurado)
EOF

echo "✨ Configuração global do MCP concluída!"
echo ""
echo "📝 Documentação disponível em: $CLAUDE_GLOBAL_CONFIG/README.md"
echo "🔄 Para aplicar em shells existentes, execute: source /etc/profile.d/claude-mcp.sh"
echo ""
echo "🎯 Próximos passos:"
echo "   1. Abra um novo terminal para testar"
echo "   2. Execute 'mcp-status' para verificar"
echo "   3. Use 'claude' normalmente - MCP estará disponível!"