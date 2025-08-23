#!/bin/bash
# Custom entrypoint for terminal API with MCP setup

echo "Starting terminal API..."

# Initialize Claude permissions and trust
if [ -f "/app/scripts/claude-init-config.sh" ]; then
    echo "Initializing Claude Code permissions..."
    /app/scripts/claude-init-config.sh
fi

# Function to setup MCP in Claude Code
setup_mcp_in_claude() {
    if [ -f "/app/global-settings/mcp-config.json" ]; then
        cd /app/global-settings
        
        # Add MCP configuration directly to Claude config
        echo "Configuring neo4j-memory MCP server..."
        claude mcp add-json neo4j-memory "$(cat mcp-config.json)" 2>/dev/null || true
        
        echo "MCP Neo4j Agent Memory configured successfully!"
    fi
}

# Setup MCP on first run
setup_mcp_in_claude &

# Start the application
exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --log-level info