"""
Gerenciador de MCP Neo4j Agent Memory integrado com Worktrees
"""
import subprocess
import json
import os
from typing import Optional, Dict, List
from pathlib import Path

class MCPManager:
    """Gerencia configuração do MCP por projeto/worktree"""
    
    def __init__(self):
        self.mcp_path = "/app/mcp-neo4j-agent-memory"
        self.neo4j_uri = os.getenv("NEO4J_URI", "bolt://terminal-neo4j:7687")
        self.neo4j_user = os.getenv("NEO4J_USERNAME", "neo4j")
        self.neo4j_password = os.getenv("NEO4J_PASSWORD", "password")
        self.neo4j_database = os.getenv("NEO4J_DATABASE", "neo4j")
    
    def setup_for_worktree(self, project_id: str, branch_name: str) -> Dict[str, str]:
        """
        Configura MCP para um worktree específico
        
        Args:
            project_id: ID do projeto
            branch_name: Nome da branch do worktree
            
        Returns:
            Dict com status da configuração
        """
        try:
            # Criar configuração específica para o projeto
            config = {
                "command": "node",
                "args": [f"{self.mcp_path}/build/index.js"],
                "env": {
                    "NEO4J_URI": self.neo4j_uri,
                    "NEO4J_USERNAME": self.neo4j_user,
                    "NEO4J_PASSWORD": self.neo4j_password,
                    "NEO4J_DATABASE": self.neo4j_database,
                    "MCP_PROJECT_ID": project_id,
                    "MCP_BRANCH": branch_name,
                    "MCP_LABEL_PREFIX": f"{project_id}_"
                }
            }
            
            # Nome único para o servidor MCP
            server_name = f"neo4j-{project_id}"
            
            # Verificar se já existe
            existing = self.list_mcp_servers()
            if server_name in existing:
                return {
                    "status": "existing",
                    "server_name": server_name,
                    "project_id": project_id
                }
            
            # Registrar no Claude
            config_json = json.dumps(config)
            result = subprocess.run(
                ["claude", "mcp", "add-json", server_name, config_json],
                capture_output=True,
                text=True,
                check=True
            )
            
            return {
                "status": "created",
                "server_name": server_name,
                "project_id": project_id,
                "output": result.stdout
            }
            
        except subprocess.CalledProcessError as e:
            return {
                "status": "error",
                "error": e.stderr,
                "project_id": project_id
            }
    
    def remove_for_worktree(self, project_id: str) -> bool:
        """
        Remove configuração MCP quando worktree é deletado
        
        Args:
            project_id: ID do projeto
            
        Returns:
            True se removido com sucesso
        """
        server_name = f"neo4j-{project_id}"
        
        try:
            subprocess.run(
                ["claude", "mcp", "remove", server_name],
                capture_output=True,
                check=True
            )
            return True
        except subprocess.CalledProcessError:
            return False
    
    def list_mcp_servers(self) -> List[str]:
        """
        Lista todos os servidores MCP registrados
        
        Returns:
            Lista de nomes dos servidores
        """
        try:
            result = subprocess.run(
                ["claude", "mcp", "list"],
                capture_output=True,
                text=True,
                check=True
            )
            
            # Parsear output para extrair nomes
            servers = []
            for line in result.stdout.split('\n'):
                if ':' in line and 'neo4j' in line.lower():
                    server_name = line.split(':')[0].strip()
                    servers.append(server_name)
            
            return servers
            
        except subprocess.CalledProcessError:
            return []
    
    def get_server_status(self, project_id: str) -> Optional[Dict[str, str]]:
        """
        Verifica status do servidor MCP para um projeto
        
        Args:
            project_id: ID do projeto
            
        Returns:
            Dict com status ou None
        """
        server_name = f"neo4j-{project_id}"
        
        try:
            result = subprocess.run(
                ["claude", "mcp", "list"],
                capture_output=True,
                text=True,
                check=True
            )
            
            for line in result.stdout.split('\n'):
                if server_name in line:
                    status = "connected" if "Connected" in line else "disconnected"
                    return {
                        "server_name": server_name,
                        "status": status,
                        "project_id": project_id
                    }
            
            return None
            
        except subprocess.CalledProcessError:
            return None
    
    def setup_global_mcp(self) -> Dict[str, str]:
        """
        Configura MCP global (não isolado por projeto)
        
        Returns:
            Dict com status da configuração
        """
        return self.setup_for_worktree("global", "main")
    
    def create_memory_namespace(self, project_id: str) -> bool:
        """
        Cria namespace no Neo4j para isolar memórias do projeto
        
        Args:
            project_id: ID do projeto
            
        Returns:
            True se criado com sucesso
        """
        try:
            # Usar driver Neo4j diretamente para criar label único
            from neo4j import GraphDatabase
            
            driver = GraphDatabase.driver(
                self.neo4j_uri,
                auth=(self.neo4j_user, self.neo4j_password)
            )
            
            with driver.session(database=self.neo4j_database) as session:
                # Criar nó marcador para o projeto
                session.run(
                    f"CREATE (p:Project_{project_id} {{id: $id, created_at: datetime()}})",
                    id=project_id
                )
            
            driver.close()
            return True
            
        except Exception:
            return False
    
    def cleanup_memory_namespace(self, project_id: str) -> bool:
        """
        Remove namespace do Neo4j quando projeto é deletado
        
        Args:
            project_id: ID do projeto
            
        Returns:
            True se removido com sucesso
        """
        try:
            from neo4j import GraphDatabase
            
            driver = GraphDatabase.driver(
                self.neo4j_uri,
                auth=(self.neo4j_user, self.neo4j_password)
            )
            
            with driver.session(database=self.neo4j_database) as session:
                # Remover todos os nós com label do projeto
                session.run(
                    f"MATCH (n:Project_{project_id}) DETACH DELETE n"
                )
                
                # Remover nós com prefixo do projeto
                session.run(
                    f"MATCH (n) WHERE any(label in labels(n) WHERE label STARTS WITH '{project_id}_') DETACH DELETE n"
                )
            
            driver.close()
            return True
            
        except Exception:
            return False