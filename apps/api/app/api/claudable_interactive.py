"""WebSocket endpoint para terminal interativo com Claude Code"""
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from app.claudable_terminal.terminal_interactive import InteractiveTerminal
import asyncio
import json
from typing import Dict
from datetime import datetime, timedelta

router = APIRouter()

# Armazena sessões ativas com timestamp
active_sessions: Dict[str, Dict] = {}

# Limpa sessões inativas após 1 hora
SESSION_TIMEOUT_HOURS = 1

async def cleanup_inactive_sessions():
    """Remove sessões inativas"""
    current_time = datetime.now()
    to_remove = []
    
    for session_id, session_data in active_sessions.items():
        if current_time - session_data['last_activity'] > timedelta(hours=SESSION_TIMEOUT_HOURS):
            terminal = session_data['terminal']
            if terminal.is_alive():
                await terminal.close_session()
            to_remove.append(session_id)
    
    for session_id in to_remove:
        active_sessions.pop(session_id, None)

@router.websocket("/ws/terminal/interactive/{session_id}")
async def terminal_interactive_websocket(websocket: WebSocket, session_id: str):
    """WebSocket para terminal interativo com PTY persistente"""
    await websocket.accept()
    
    # Cria ou recupera a sessão
    if session_id not in active_sessions:
        active_sessions[session_id] = {
            'terminal': InteractiveTerminal(session_id),
            'last_activity': datetime.now(),
            'created_at': datetime.now()
        }
        is_new_session = True
    else:
        is_new_session = False
        active_sessions[session_id]['last_activity'] = datetime.now()
    
    terminal = active_sessions[session_id]['terminal']
    
    # Task para ler output continuamente
    async def read_output_task():
        """Lê output do terminal e envia ao cliente"""
        while True:
            try:
                result = await terminal.read_output(timeout=0.1)
                if result['success'] and result.get('output'):
                    await websocket.send_json({
                        'type': 'output',
                        'data': result['output']
                    })
                await asyncio.sleep(0.01)  # Pequeno delay para não sobrecarregar
            except Exception:
                break
    
    # Inicia a task de leitura
    output_task = asyncio.create_task(read_output_task())
    
    try:
        while True:
            # Recebe mensagem do cliente
            data = await websocket.receive_json()
            
            if data['type'] == 'start':
                # Se é uma nova sessão, inicia o terminal
                # Se é reconexão, apenas confirma
                if is_new_session or not terminal.is_alive():
                    command = data.get('command')
                    result = await terminal.start_session(command)
                    await websocket.send_json({
                        'type': 'session_started',
                        'success': result['success'],
                        'message': result.get('message', ''),
                        'reconnected': False
                    })
                else:
                    # Sessão já existe e está ativa - reconexão
                    await websocket.send_json({
                        'type': 'session_started',
                        'success': True,
                        'message': 'Reconectado à sessão existente',
                        'reconnected': True
                    })
                
                # Atualiza atividade
                active_sessions[session_id]['last_activity'] = datetime.now()
                
            elif data['type'] == 'input':
                # Envia input para o terminal
                input_data = data.get('data', '')
                await terminal.send_input(input_data)
                
            elif data['type'] == 'resize':
                # Redimensiona terminal
                rows = data.get('rows', 24)
                cols = data.get('cols', 80)
                await terminal.resize_terminal(rows, cols)
                
            elif data['type'] == 'close':
                # Fecha a sessão
                await terminal.close_session()
                break
                
    except WebSocketDisconnect:
        pass
    except Exception as e:
        await websocket.send_json({
            'type': 'error',
            'message': str(e)
        })
    finally:
        # Cancela a task de output
        output_task.cancel()
        
        # NÃO remove a sessão ao desconectar - mantém para reconexão
        # Apenas atualiza timestamp
        if session_id in active_sessions:
            active_sessions[session_id]['last_activity'] = datetime.now()
        
        # Agenda limpeza de sessões inativas
        asyncio.create_task(cleanup_inactive_sessions())