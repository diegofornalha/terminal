#!/bin/bash
# Claude wrapper script for safe Docker execution

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "⚠️  Claude Code não deve ser executado como root no Docker"
    echo "🔒 Criando usuário seguro para Claude..."
    
    # Create claude user if it doesn't exist
    if ! id -u claude >/dev/null 2>&1; then
        useradd -m -s /bin/bash claude
    fi
    
    # Switch to claude user
    exec su -c "claude $*" claude
else
    # Not root, execute normally
    exec claude "$@"
fi