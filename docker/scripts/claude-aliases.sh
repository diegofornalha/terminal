#!/bin/bash
# Claude Code aliases for easy access

# Basic safe command (new conversation)
alias claude-safe="su - claude-user -c 'cd /app/global-settings && claude --dangerously-skip-permissions'"

# Continue last conversation
alias claude-safe-c="su - claude-user -c 'cd /app/global-settings && claude --dangerously-skip-permissions --continue'"

# Resume from conversation list
alias claude-safe-r="su - claude-user -c 'cd /app/global-settings && claude --dangerously-skip-permissions --resume'"

# With specific model
alias claude-safe-opus="su - claude-user -c 'cd /app/global-settings && claude --dangerously-skip-permissions --model opus'"
alias claude-safe-sonnet="su - claude-user -c 'cd /app/global-settings && claude --dangerously-skip-permissions --model sonnet'"

# Help command
alias claude-help="echo 'Available Claude commands:
  claude-safe       - Start new conversation (skip permissions)
  claude-safe-c     - Continue last conversation
  claude-safe-r     - Resume from conversation list
  claude-safe-opus  - Use Opus model
  claude-safe-sonnet - Use Sonnet model
'"

echo "Claude aliases loaded! Type 'claude-help' for available commands."