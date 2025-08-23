"""
API endpoints para gerenciamento de worktrees
"""
from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
from typing import Optional, List, Dict
from datetime import datetime
import asyncio
import json

from app.services.worktree_manager import WorktreeManager
from app.services.session_manager import SessionManager
from app.core.logging import logger

router = APIRouter(prefix="/api/worktrees", tags=["worktrees"])

# Inicializar gerenciadores
worktree_manager = WorktreeManager()
session_manager = SessionManager()

# Modelos Pydantic
class WorktreeCreate(BaseModel):
    project_id: str
    name: str
    description: Optional[str] = ""
    branch_prefix: Optional[str] = "chat"

class WorktreeResponse(BaseModel):
    project_id: str
    branch: str
    path: str
    status: str
    created_at: Optional[datetime] = None

class WorktreeInfo(BaseModel):
    project_id: str
    branch: str
    path: str
    has_changes: bool
    last_commit: str

@router.post("/", response_model=WorktreeResponse)
async def create_worktree(worktree_data: WorktreeCreate):
    """
    Cria novo worktree para um projeto
    """
    try:
        result = worktree_manager.create_worktree(
            project_id=worktree_data.project_id,
            branch_prefix=worktree_data.branch_prefix
        )
        
        # Adicionar timestamp
        result['created_at'] = datetime.now()
        
        logger.info(f"Worktree criado: {result['branch']}")
        
        return WorktreeResponse(**result)
        
    except Exception as e:
        logger.error(f"Erro ao criar worktree: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/", response_model=List[Dict])
async def list_worktrees():
    """
    Lista todos os worktrees ativos
    """
    try:
        worktrees = worktree_manager.list_worktrees()
        return worktrees
        
    except Exception as e:
        logger.error(f"Erro ao listar worktrees: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/{project_id}", response_model=Optional[WorktreeInfo])
async def get_worktree_info(project_id: str, branch_prefix: str = "chat"):
    """
    Obtém informações de um worktree específico
    """
    try:
        info = worktree_manager.get_worktree_info(project_id, branch_prefix)
        
        if not info:
            raise HTTPException(status_code=404, detail="Worktree não encontrado")
        
        return WorktreeInfo(**info)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao obter info do worktree: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.delete("/{project_id}")
async def delete_worktree(project_id: str, branch_prefix: str = "chat"):
    """
    Remove worktree de um projeto
    """
    try:
        success = worktree_manager.remove_worktree(project_id, branch_prefix)
        
        if not success:
            raise HTTPException(status_code=404, detail="Worktree não encontrado ou erro ao remover")
        
        logger.info(f"Worktree removido: {branch_prefix}-{project_id}")
        
        return {"status": "deleted", "project_id": project_id}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao remover worktree: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/cleanup")
async def cleanup_old_worktrees(days: int = 30):
    """
    Remove worktrees inativos há mais de X dias
    """
    try:
        removed = worktree_manager.cleanup_old_worktrees(days)
        
        return {
            "status": "cleaned",
            "removed_count": len(removed),
            "removed": removed
        }
        
    except Exception as e:
        logger.error(f"Erro ao limpar worktrees: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/prune")
async def prune_worktrees():
    """
    Remove referências a worktrees órfãos
    """
    try:
        success = worktree_manager.prune_worktrees()
        
        if not success:
            raise HTTPException(status_code=500, detail="Erro ao executar prune")
        
        return {"status": "pruned"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Erro ao executar prune: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.websocket("/ws/{project_id}")
async def worktree_terminal_websocket(websocket: WebSocket, project_id: str):
    """
    WebSocket para terminal isolado no worktree
    """
    await websocket.accept()
    
    try:
        # Obter informações do worktree
        info = worktree_manager.get_worktree_info(project_id)
        
        if not info:
            await websocket.send_json({
                "type": "error",
                "message": f"Worktree não encontrado para projeto {project_id}"
            })
            await websocket.close()
            return
        
        # Criar sessão de terminal no worktree
        session_id = f"worktree-{project_id}"
        terminal_session = await session_manager.create_session(
            session_id=session_id,
            working_dir=info['path']
        )
        
        # Enviar confirmação
        await websocket.send_json({
            "type": "connected",
            "worktree": info,
            "session_id": session_id
        })
        
        # Loop de comunicação
        try:
            while True:
                # Receber comando do cliente
                data = await websocket.receive_text()
                command = json.loads(data)
                
                if command.get("type") == "command":
                    # Executar comando no worktree
                    result = await terminal_session.execute(
                        command.get("cmd"),
                        cwd=info['path']
                    )
                    
                    # Enviar resultado
                    await websocket.send_json({
                        "type": "output",
                        "data": result
                    })
                    
                elif command.get("type") == "resize":
                    # Redimensionar terminal
                    await terminal_session.resize(
                        command.get("cols", 80),
                        command.get("rows", 24)
                    )
                    
        except WebSocketDisconnect:
            logger.info(f"WebSocket desconectado para worktree {project_id}")
            
        finally:
            # Limpar sessão
            await session_manager.close_session(session_id)
            
    except Exception as e:
        logger.error(f"Erro no WebSocket do worktree: {str(e)}")
        await websocket.send_json({
            "type": "error",
            "message": str(e)
        })
        await websocket.close()