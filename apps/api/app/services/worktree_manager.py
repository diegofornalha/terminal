"""
Gerenciador de Worktrees Git para isolamento de projetos
"""
import subprocess
import os
import json
from typing import Optional, Dict, List
from datetime import datetime
from pathlib import Path
from .mcp_manager import MCPManager

class WorktreeManager:
    """Gerencia worktrees Git para projetos isolados"""
    
    BASE_PATH = "/home/codable/Claudable"
    WORKTREE_DIR = "worktrees"
    
    def __init__(self):
        self.worktree_path = os.path.join(self.BASE_PATH, self.WORKTREE_DIR)
        self._ensure_base_structure()
        self.mcp_manager = MCPManager()
    
    def _ensure_base_structure(self):
        """Garante que a estrutura base existe"""
        os.makedirs(self.worktree_path, exist_ok=True)
        
        # Verificar se é um repositório git
        if not os.path.exists(os.path.join(self.BASE_PATH, ".git")):
            raise Exception(f"Diretório {self.BASE_PATH} não é um repositório Git")
    
    def create_worktree(self, project_id: str, branch_prefix: str = "chat") -> Dict[str, str]:
        """
        Cria um novo worktree para o projeto
        
        Args:
            project_id: ID único do projeto
            branch_prefix: Prefixo para o nome da branch
            
        Returns:
            Dict com informações do worktree criado
        """
        branch_name = f"{branch_prefix}-{project_id}"
        worktree_full_path = os.path.join(self.worktree_path, branch_name)
        
        # Verificar se já existe
        if os.path.exists(worktree_full_path):
            return {
                "project_id": project_id,
                "branch": branch_name,
                "path": worktree_full_path,
                "status": "existing"
            }
        
        try:
            # Criar worktree com nova branch
            result = subprocess.run(
                ["git", "worktree", "add", "-b", branch_name, worktree_full_path],
                cwd=self.BASE_PATH,
                capture_output=True,
                text=True,
                check=True
            )
            
            # Criar arquivo inicial no worktree
            readme_path = os.path.join(worktree_full_path, "README.md")
            with open(readme_path, "w") as f:
                f.write(f"# Projeto {project_id}\n\n")
                f.write(f"Branch: {branch_name}\n")
                f.write(f"Criado em: {datetime.now().isoformat()}\n")
            
            # Fazer commit inicial
            subprocess.run(
                ["git", "add", "."],
                cwd=worktree_full_path,
                check=True
            )
            
            subprocess.run(
                ["git", "commit", "-m", f"Initial commit for {branch_name}"],
                cwd=worktree_full_path,
                check=True
            )
            
            # Configurar MCP para o worktree
            mcp_result = self.mcp_manager.setup_for_worktree(project_id, branch_name)
            
            # Criar namespace no Neo4j
            self.mcp_manager.create_memory_namespace(project_id)
            
            return {
                "project_id": project_id,
                "branch": branch_name,
                "path": worktree_full_path,
                "status": "created",
                "mcp": mcp_result
            }
            
        except subprocess.CalledProcessError as e:
            raise Exception(f"Erro ao criar worktree: {e.stderr}")
    
    def remove_worktree(self, project_id: str, branch_prefix: str = "chat") -> bool:
        """
        Remove worktree quando projeto é deletado
        
        Args:
            project_id: ID do projeto
            branch_prefix: Prefixo da branch
            
        Returns:
            True se removido com sucesso
        """
        branch_name = f"{branch_prefix}-{project_id}"
        worktree_full_path = os.path.join(self.worktree_path, branch_name)
        
        try:
            # Remover configuração MCP
            self.mcp_manager.remove_for_worktree(project_id)
            
            # Limpar namespace no Neo4j
            self.mcp_manager.cleanup_memory_namespace(project_id)
            
            # Remover worktree
            subprocess.run(
                ["git", "worktree", "remove", worktree_full_path, "--force"],
                cwd=self.BASE_PATH,
                capture_output=True,
                check=True
            )
            
            # Deletar branch
            subprocess.run(
                ["git", "branch", "-D", branch_name],
                cwd=self.BASE_PATH,
                capture_output=True,
                check=True
            )
            
            return True
            
        except subprocess.CalledProcessError:
            return False
    
    def list_worktrees(self) -> List[Dict[str, str]]:
        """
        Lista todos os worktrees ativos
        
        Returns:
            Lista de dicionários com informações dos worktrees
        """
        try:
            result = subprocess.run(
                ["git", "worktree", "list", "--porcelain"],
                cwd=self.BASE_PATH,
                capture_output=True,
                text=True,
                check=True
            )
            
            worktrees = []
            current_worktree = {}
            
            for line in result.stdout.strip().split('\n'):
                if not line:
                    if current_worktree:
                        worktrees.append(current_worktree)
                        current_worktree = {}
                elif line.startswith('worktree '):
                    current_worktree['path'] = line.replace('worktree ', '')
                elif line.startswith('HEAD '):
                    current_worktree['head'] = line.replace('HEAD ', '')
                elif line.startswith('branch '):
                    current_worktree['branch'] = line.replace('branch refs/heads/', '')
            
            # Adicionar último worktree
            if current_worktree:
                worktrees.append(current_worktree)
            
            # Extrair project_id de cada worktree
            for wt in worktrees:
                if 'branch' in wt and '-' in wt['branch']:
                    parts = wt['branch'].split('-', 1)
                    if len(parts) == 2:
                        wt['project_id'] = parts[1]
            
            return worktrees
            
        except subprocess.CalledProcessError as e:
            raise Exception(f"Erro ao listar worktrees: {e.stderr}")
    
    def get_worktree_info(self, project_id: str, branch_prefix: str = "chat") -> Optional[Dict[str, str]]:
        """
        Obtém informações de um worktree específico
        
        Args:
            project_id: ID do projeto
            branch_prefix: Prefixo da branch
            
        Returns:
            Dict com informações ou None se não existir
        """
        branch_name = f"{branch_prefix}-{project_id}"
        worktree_full_path = os.path.join(self.worktree_path, branch_name)
        
        if not os.path.exists(worktree_full_path):
            return None
        
        try:
            # Obter status do worktree
            result = subprocess.run(
                ["git", "status", "--porcelain"],
                cwd=worktree_full_path,
                capture_output=True,
                text=True,
                check=True
            )
            
            # Obter último commit
            log_result = subprocess.run(
                ["git", "log", "-1", "--oneline"],
                cwd=worktree_full_path,
                capture_output=True,
                text=True,
                check=True
            )
            
            return {
                "project_id": project_id,
                "branch": branch_name,
                "path": worktree_full_path,
                "has_changes": bool(result.stdout.strip()),
                "last_commit": log_result.stdout.strip()
            }
            
        except subprocess.CalledProcessError:
            return None
    
    def cleanup_old_worktrees(self, days: int = 30) -> List[str]:
        """
        Remove worktrees inativos há mais de X dias
        
        Args:
            days: Número de dias de inatividade
            
        Returns:
            Lista de worktrees removidos
        """
        removed = []
        worktrees = self.list_worktrees()
        
        for wt in worktrees:
            if 'path' not in wt or wt['path'] == self.BASE_PATH:
                continue  # Pular worktree principal
            
            path = wt['path']
            
            # Verificar última modificação
            if os.path.exists(path):
                last_modified = datetime.fromtimestamp(os.path.getmtime(path))
                age_days = (datetime.now() - last_modified).days
                
                if age_days > days:
                    # Extrair project_id
                    if 'project_id' in wt:
                        if self.remove_worktree(wt['project_id']):
                            removed.append(wt['project_id'])
        
        return removed
    
    def prune_worktrees(self) -> bool:
        """
        Remove referências a worktrees órfãos
        
        Returns:
            True se limpeza foi executada
        """
        try:
            subprocess.run(
                ["git", "worktree", "prune"],
                cwd=self.BASE_PATH,
                check=True
            )
            return True
        except subprocess.CalledProcessError:
            return False