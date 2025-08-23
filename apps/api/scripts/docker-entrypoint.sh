#!/bin/bash
# Docker entrypoint with Claude Safe and MCP configuration

# Create non-root user for Claude if needed
if [ "$CLAUDE_SAFE_MODE" = "true" ]; then
    echo "🔒 Configurando Claude Safe para Docker..."
    
    # Create claude user
    if ! id -u claude >/dev/null 2>&1; then
        useradd -m -s /bin/bash claude
        echo "✅ Usuário 'claude' criado para execução segura"
    fi
    
    # Set permissions for claude user
    chown -R claude:claude /app/data 2>/dev/null || true
    
    # Make wrapper executable
    chmod +x /app/scripts/claude-wrapper.sh 2>/dev/null || true
    
    # Source aliases for all users
    echo "source /app/scripts/claude-aliases.sh" >> /etc/bash.bashrc
fi

# Setup MCP Neo4j if enabled
if [ "$MCP_AUTO_REGISTER" = "true" ]; then
    echo "🤖 Configurando MCP Neo4j Agent Memory..."
    
    # Run setup script in background to not block startup
    if [ -f /app/scripts/setup-mcp.sh ]; then
        /app/scripts/setup-mcp.sh &
        echo "   Setup do MCP iniciado em background"
    else
        echo "   ⚠️ Script setup-mcp.sh não encontrado"
    fi
fi

# Execute the main application
exec "$@"