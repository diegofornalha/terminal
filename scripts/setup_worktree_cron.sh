#!/bin/bash
# Script para configurar cron job de limpeza de worktrees

# Criar diretório de logs se não existir
mkdir -p /var/log/claudable

# Adicionar entrada no crontab para executar diariamente às 2:00 AM
(crontab -l 2>/dev/null; echo "0 2 * * * /home/codable/terminal/scripts/cleanup_worktrees.py >> /var/log/claudable/cleanup_worktrees.log 2>&1") | crontab -

echo "✅ Cron job configurado para limpeza diária de worktrees às 2:00 AM"
echo "📁 Logs serão salvos em: /var/log/claudable/cleanup_worktrees.log"

# Verificar se foi adicionado
echo ""
echo "📋 Crontab atual:"
crontab -l | grep cleanup_worktrees