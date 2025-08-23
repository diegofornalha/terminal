#!/usr/bin/env python3
"""
Script de limpeza automática de worktrees inativos
Executa diariamente via cron para remover worktrees não utilizados
"""

import os
import sys
import logging
from datetime import datetime

# Adicionar caminho do projeto ao sys.path
sys.path.insert(0, '/home/codable/terminal/apps/api')

from app.services.worktree_manager import WorktreeManager

# Configurar logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/claudable/cleanup_worktrees.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

def main():
    """
    Função principal de limpeza
    """
    try:
        logger.info("Iniciando limpeza de worktrees...")
        
        # Inicializar gerenciador
        manager = WorktreeManager()
        
        # Listar worktrees antes da limpeza
        worktrees_before = manager.list_worktrees()
        logger.info(f"Worktrees ativos antes da limpeza: {len(worktrees_before)}")
        
        # Remover worktrees inativos há mais de 30 dias
        removed = manager.cleanup_old_worktrees(days=30)
        
        if removed:
            logger.info(f"Worktrees removidos: {removed}")
            logger.info(f"Total removido: {len(removed)}")
        else:
            logger.info("Nenhum worktree inativo encontrado")
        
        # Executar prune para limpar referências órfãs
        if manager.prune_worktrees():
            logger.info("Prune executado com sucesso")
        
        # Listar worktrees depois da limpeza
        worktrees_after = manager.list_worktrees()
        logger.info(f"Worktrees ativos após a limpeza: {len(worktrees_after)}")
        
        # Relatório resumido
        logger.info("=" * 50)
        logger.info("RESUMO DA LIMPEZA")
        logger.info(f"Data/Hora: {datetime.now().isoformat()}")
        logger.info(f"Worktrees antes: {len(worktrees_before)}")
        logger.info(f"Worktrees removidos: {len(removed)}")
        logger.info(f"Worktrees restantes: {len(worktrees_after)}")
        logger.info("=" * 50)
        
    except Exception as e:
        logger.error(f"Erro durante limpeza: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()