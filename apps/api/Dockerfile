FROM python:3.11-slim

WORKDIR /app

# Install system dependencies, Claude Code, GitHub CLI and MCP
RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    sudo \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g @anthropic-ai/claude-code \
    && claude -v || echo "Claude Code installed" \
    && gh --version || echo "GitHub CLI installed"

# Install MCP Neo4j Agent Memory
COPY mcp-neo4j-agent-memory /app/mcp-neo4j-agent-memory/
WORKDIR /app/mcp-neo4j-agent-memory
RUN npm ci --production=false \
    && npm run build \
    && npm link \
    && echo "MCP Neo4j Agent Memory installed" \
    && ls -la /app/mcp-neo4j-agent-memory/build/

# Configure MCP for Claude
ENV MCP_CONFIG_PATH=/app/mcp-neo4j-agent-memory/claude_mcp_config.json
ENV NEO4J_URI=bolt://terminal-neo4j:7687
ENV NEO4J_USERNAME=neo4j
ENV NEO4J_PASSWORD=password
ENV NEO4J_DATABASE=neo4j
ENV MCP_AUTO_REGISTER=true
ENV MCP_WORKTREE_ISOLATION=true

# Copy requirements first for better cache
COPY apps/api/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY apps/api/ .

# Copy Claude Safe scripts and MCP setup scripts
COPY apps/api/scripts/*.sh /app/scripts/
RUN chmod +x /app/scripts/*.sh

# Restore workdir
WORKDIR /app

# Setup MCP globally for all users
RUN if [ -f /app/scripts/setup-mcp-global.sh ]; then \
        /app/scripts/setup-mcp-global.sh || echo "MCP global setup attempted"; \
    fi

# Create data directory and claude user
RUN mkdir -p /app/data \
    && useradd -m -s /bin/bash claude \
    && echo "claude ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Set environment for Claude Safe
ENV CLAUDE_SAFE_MODE=true
ENV CLAUDE_DOCKER=true

# Configure bash to load Claude Safe aliases
RUN echo "source /app/scripts/claude-aliases.sh" >> /etc/bash.bashrc

# Expose port
EXPOSE 8000

# Use entrypoint for Claude Safe setup
ENTRYPOINT ["/app/scripts/docker-entrypoint.sh"]

# Run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]