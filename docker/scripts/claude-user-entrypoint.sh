#!/bin/bash
# Entrypoint for Claude as non-root user

# Switch to claude-user for Claude commands
if [ "$EUID" -eq 0 ]; then
    echo "Switching to claude-user for Claude Code..."
    exec su - claude-user -c "cd /app/global-settings && claude --dangerously-skip-permissions"
else
    # Already non-root
    cd /app/global-settings
    exec claude --dangerously-skip-permissions
fi