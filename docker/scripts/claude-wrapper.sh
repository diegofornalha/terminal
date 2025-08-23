#!/bin/bash
# Wrapper script to run Claude Code with auto-permissions

# Export environment variables
export CLAUDE_DANGEROUSLY_SKIP_PERMISSIONS=true
export CLAUDE_AUTO_APPROVE_MCP=true
export CLAUDE_TRUST_ALL_DIRECTORIES=true

# Change to global-settings directory
cd /app/global-settings

# Run Claude Code with flags to skip permissions
exec claude "$@" --dangerously-skip-permissions --trust-workspace