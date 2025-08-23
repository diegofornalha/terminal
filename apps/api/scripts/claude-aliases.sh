#!/bin/bash
# Claude aliases for safe Docker execution

# Create safe claude alias
alias claude-safe='/app/scripts/claude-wrapper.sh'

# Default claude to safe version
alias claude='claude-safe'

# Claude with Docker support
alias claude-docker='claude --docker-safe'

# Export for subshells
export -f claude-safe 2>/dev/null || true

echo "🔒 Claude Safe aliases loaded for Docker"