"""
Health check endpoints para monitoramento do sistema
"""
from fastapi import APIRouter, HTTPException
from typing import Dict, Any
import subprocess
import os
from datetime import datetime
from neo4j import GraphDatabase
from ..services.mcp_manager import MCPManager

router = APIRouter()

@router.get("/health")
async def health_check() -> Dict[str, Any]:
    """Health check geral do sistema"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0",
        "services": {
            "api": "running",
            "mcp": await check_mcp_status(),
            "neo4j": await check_neo4j_status()
        }
    }

@router.get("/health/mcp")
async def mcp_health_check() -> Dict[str, Any]:
    """Health check específico do MCP"""
    try:
        # Verificar se Claude Code está instalado
        claude_installed = subprocess.run(
            ["claude", "--version"],
            capture_output=True,
            text=True,
            timeout=5
        ).returncode == 0
        
        # Listar servidores MCP
        mcp_list_result = subprocess.run(
            ["claude", "mcp", "list"],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        mcp_servers = []
        if mcp_list_result.returncode == 0:
            for line in mcp_list_result.stdout.split('\n'):
                if 'neo4j' in line.lower():
                    status = "connected" if "Connected" in line else "disconnected"
                    server_name = line.split(':')[0].strip() if ':' in line else "unknown"
                    mcp_servers.append({
                        "name": server_name,
                        "status": status
                    })
        
        # Verificar se MCP está buildado
        mcp_built = os.path.exists("/app/mcp-neo4j-agent-memory/build/index.js")
        
        return {
            "status": "healthy" if claude_installed and mcp_built else "unhealthy",
            "claude_installed": claude_installed,
            "mcp_built": mcp_built,
            "mcp_servers": mcp_servers,
            "mcp_path": "/app/mcp-neo4j-agent-memory",
            "auto_register": os.getenv("MCP_AUTO_REGISTER", "false") == "true",
            "worktree_isolation": os.getenv("MCP_WORKTREE_ISOLATION", "false") == "true"
        }
        
    except Exception as e:
        return {
            "status": "error",
            "error": str(e)
        }

@router.get("/health/neo4j")
async def neo4j_health_check() -> Dict[str, Any]:
    """Health check do Neo4j"""
    try:
        uri = os.getenv("NEO4J_URI", "bolt://terminal-neo4j:7687")
        user = os.getenv("NEO4J_USERNAME", "neo4j")
        password = os.getenv("NEO4J_PASSWORD")
        if not password:
            return {"status": "unhealthy", "error": "NEO4J_PASSWORD not configured"}
        database = os.getenv("NEO4J_DATABASE", "neo4j")
        
        driver = GraphDatabase.driver(uri, auth=(user, password))
        
        with driver.session(database=database) as session:
            result = session.run("RETURN 1 as test")
            test_value = result.single()["test"]
            
            # Contar nós no grafo
            count_result = session.run("MATCH (n) RETURN count(n) as count")
            node_count = count_result.single()["count"]
            
            # Verificar namespaces de projetos
            namespace_result = session.run(
                "MATCH (n) WHERE any(label in labels(n) WHERE label STARTS WITH 'Project_') "
                "RETURN DISTINCT labels(n) as namespaces"
            )
            namespaces = [record["namespaces"] for record in namespace_result]
        
        driver.close()
        
        return {
            "status": "healthy",
            "uri": uri,
            "database": database,
            "node_count": node_count,
            "project_namespaces": namespaces,
            "connection": "successful"
        }
        
    except Exception as e:
        return {
            "status": "unhealthy",
            "error": str(e),
            "connection": "failed"
        }

@router.get("/health/worktrees")
async def worktrees_health_check() -> Dict[str, Any]:
    """Health check do sistema de worktrees"""
    try:
        from ..services.worktree_manager import WorktreeManager
        
        wm = WorktreeManager()
        worktrees = wm.list_worktrees()
        
        # Verificar MCP para cada worktree
        mcp_manager = MCPManager()
        worktree_mcp_status = []
        
        for wt in worktrees:
            if 'project_id' in wt:
                mcp_status = mcp_manager.get_server_status(wt['project_id'])
                worktree_mcp_status.append({
                    "project_id": wt['project_id'],
                    "branch": wt.get('branch', 'unknown'),
                    "mcp": mcp_status
                })
        
        return {
            "status": "healthy",
            "base_path": WorktreeManager.BASE_PATH,
            "worktree_count": len(worktrees),
            "worktrees": worktree_mcp_status
        }
        
    except Exception as e:
        return {
            "status": "error",
            "error": str(e)
        }

async def check_mcp_status() -> str:
    """Verifica status básico do MCP"""
    try:
        result = subprocess.run(
            ["claude", "mcp", "list"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            if "neo4j" in result.stdout.lower():
                return "configured"
            return "not_configured"
        return "error"
    except:
        return "unavailable"

async def check_neo4j_status() -> str:
    """Verifica status básico do Neo4j"""
    try:
        uri = os.getenv("NEO4J_URI", "bolt://terminal-neo4j:7687")
        user = os.getenv("NEO4J_USERNAME", "neo4j")
        password = os.getenv("NEO4J_PASSWORD")
        if not password:
            return "not configured"
        
        driver = GraphDatabase.driver(uri, auth=(user, password))
        driver.verify_connectivity()
        driver.close()
        return "connected"
    except:
        return "disconnected"