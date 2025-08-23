"""WebSocket melhorado com reconexão automática e heartbeat"""
from fastapi import WebSocket, WebSocketDisconnect
from typing import Dict, Optional, Set
import json
import asyncio
from datetime import datetime, timedelta
from app.core.terminal_ui import ui
from .terminal_simple import terminalTerminal


class ConnectionStatus:
    """Status de conexão do terminal"""
    CONNECTED = 'CONNECTED'
    DISCONNECTED = 'DISCONNECTED'
    RECONNECTING = 'RECONNECTING'
    EXECUTING = 'EXECUTING'
    ERROR = 'ERROR'
    AUTHENTICATED = 'AUTHENTICATED'
    AUTHENTICATING = 'AUTHENTICATING'


STATUS_MESSAGES = {
    ConnectionStatus.CONNECTED: {'icon': '🟢', 'message': 'Conectado'},
    ConnectionStatus.DISCONNECTED: {'icon': '🔴', 'message': 'Desconectado'},
    ConnectionStatus.RECONNECTING: {'icon': '🟡', 'message': 'Reconectando...'},
    ConnectionStatus.EXECUTING: {'icon': '⚡', 'message': 'Executando comando'},
    ConnectionStatus.ERROR: {'icon': '❌', 'message': 'Erro'},
    ConnectionStatus.AUTHENTICATED: {'icon': '🔐', 'message': 'Autenticado'},
    ConnectionStatus.AUTHENTICATING: {'icon': '🔑', 'message': 'Autenticando...'}
}


class EnhancedTerminalWebSocket:
    """WebSocket melhorado com reconexão automática e heartbeat"""
    
    def __init__(self):
        self.terminals: Dict[str, terminalTerminal] = {}
        self.connections: Dict[str, WebSocket] = {}
        self.heartbeat_tasks: Dict[str, asyncio.Task] = {}
        self.connection_status: Dict[str, str] = {}
        self.last_activity: Dict[str, datetime] = {}
        self.authenticated_sessions: Set[str] = set()
        
        # Configurações
        self.heartbeat_interval = 30  # segundos
        self.max_reconnect_attempts = 5
        self.reconnect_delay = 2  # segundos
        self.activity_timeout = 300  # 5 minutos sem atividade
        self.command_timeout = 60  # timeout para comandos
    
    async def _send_status(self, websocket: WebSocket, status: str, extra_data: dict = None):
        """Envia atualização de status para o cliente"""
        status_info = STATUS_MESSAGES.get(status, {'icon': '❓', 'message': 'Desconhecido'})
        message = {
            'type': 'status',
            'status': status,
            'icon': status_info['icon'],
            'message': status_info['message'],
            'timestamp': datetime.utcnow().isoformat(),
            **(extra_data or {})
        }
        try:
            await websocket.send_json(message)
        except Exception as e:
            ui.error(f"Erro ao enviar status: {e}", "EnhancedTerminal")
    
    async def _heartbeat_loop(self, websocket: WebSocket, project_id: str):
        """Mantém conexão viva com heartbeat periódico"""
        ui.info(f"Iniciando heartbeat para projeto: {project_id}", "Heartbeat")
        
        while project_id in self.connections:
            try:
                await asyncio.sleep(self.heartbeat_interval)
                
                # Verifica timeout de inatividade
                if project_id in self.last_activity:
                    time_since_activity = datetime.utcnow() - self.last_activity[project_id]
                    if time_since_activity.total_seconds() > self.activity_timeout:
                        ui.warning(f"Timeout de inatividade para projeto: {project_id}", "Heartbeat")
                        await self._send_status(websocket, ConnectionStatus.DISCONNECTED, {
                            'reason': 'Timeout de inatividade'
                        })
                        break
                
                # Envia heartbeat
                await websocket.send_json({
                    'type': 'heartbeat',
                    'timestamp': datetime.utcnow().isoformat()
                })
                
                # Aguarda pong (com timeout)
                try:
                    pong_task = asyncio.create_task(self._wait_for_pong(websocket))
                    await asyncio.wait_for(pong_task, timeout=5.0)
                except asyncio.TimeoutError:
                    ui.warning(f"Pong não recebido para projeto: {project_id}", "Heartbeat")
                    self.connection_status[project_id] = ConnectionStatus.RECONNECTING
                    await self._send_status(websocket, ConnectionStatus.RECONNECTING)
                    
            except WebSocketDisconnect:
                ui.info(f"WebSocket desconectado durante heartbeat: {project_id}", "Heartbeat")
                break
            except Exception as e:
                ui.error(f"Erro no heartbeat: {e}", "Heartbeat")
                break
        
        ui.info(f"Heartbeat finalizado para projeto: {project_id}", "Heartbeat")
    
    async def _wait_for_pong(self, websocket: WebSocket):
        """Aguarda resposta pong do cliente"""
        data = await websocket.receive_text()
        message = json.loads(data)
        if message.get('type') != 'pong':
            raise ValueError(f"Esperado pong, recebido: {message.get('type')}")
    
    async def authenticate(self, websocket: WebSocket, project_id: str, token: Optional[str] = None) -> bool:
        """Autentica a conexão do terminal"""
        await self._send_status(websocket, ConnectionStatus.AUTHENTICATING)
        
        # Por enquanto, autenticação básica (melhorar depois com JWT)
        if token:
            # Validação simples do token (implementar JWT depois)
            if len(token) > 10:  # Token válido tem pelo menos 10 caracteres
                self.authenticated_sessions.add(project_id)
                await self._send_status(websocket, ConnectionStatus.AUTHENTICATED)
                return True
        
        # Sem token, permite acesso mas marca como não autenticado
        ui.warning(f"Conexão sem autenticação para projeto: {project_id}", "Auth")
        await self._send_status(websocket, ConnectionStatus.CONNECTED, {
            'warning': 'Conectado sem autenticação'
        })
        return True
    
    async def handle_reconnection(self, websocket: WebSocket, project_id: str, session_id: Optional[str] = None):
        """Gerencia reconexão de uma sessão anterior"""
        ui.info(f"Tentando reconectar sessão: {session_id} para projeto: {project_id}", "Reconnect")
        
        # Recupera terminal existente ou cria novo
        if project_id in self.terminals:
            terminal = self.terminals[project_id]
            ui.success(f"Terminal existente recuperado para projeto: {project_id}", "Reconnect")
        else:
            terminal = terminalTerminal(project_id)
            self.terminals[project_id] = terminal
            ui.info(f"Novo terminal criado para projeto: {project_id}", "Reconnect")
        
        # Atualiza conexão
        self.connections[project_id] = websocket
        
        # Envia estado atual
        await self._send_status(websocket, ConnectionStatus.CONNECTED, {
            'reconnected': True,
            'session_id': session_id
        })
        
        return terminal
    
    async def handle(self, websocket: WebSocket, project_id: str):
        """Gerencia conexão WebSocket aprimorada para um projeto"""
        await websocket.accept()
        ui.info(f"Terminal WebSocket conectado para projeto: {project_id}", "EnhancedTerminal")
        
        try:
            # Primeira mensagem deve conter autenticação
            init_data = await websocket.receive_text()
            init_msg = json.loads(init_data)
            
            token = init_msg.get('token')
            session_id = init_msg.get('session_id')
            
            # Autentica conexão
            if not await self.authenticate(websocket, project_id, token):
                await websocket.close(code=1008, reason="Falha na autenticação")
                return
            
            # Gerencia reconexão se houver session_id
            if session_id:
                terminal = await self.handle_reconnection(websocket, project_id, session_id)
            else:
                # Nova sessão
                if project_id not in self.terminals:
                    self.terminals[project_id] = terminalTerminal(project_id)
                terminal = self.terminals[project_id]
            
            self.connections[project_id] = websocket
            self.connection_status[project_id] = ConnectionStatus.CONNECTED
            self.last_activity[project_id] = datetime.utcnow()
            
            # Inicia heartbeat em background
            if project_id in self.heartbeat_tasks:
                self.heartbeat_tasks[project_id].cancel()
            self.heartbeat_tasks[project_id] = asyncio.create_task(
                self._heartbeat_loop(websocket, project_id)
            )
            
            # Envia confirmação de conexão
            await self._send_status(websocket, ConnectionStatus.CONNECTED, {
                'session_id': session_id or f"new-{project_id}-{datetime.utcnow().timestamp()}"
            })
            
            # Loop principal para receber comandos
            await self._command_loop(websocket, project_id, terminal)
            
        except WebSocketDisconnect:
            ui.info(f"Cliente desconectado: {project_id}", "EnhancedTerminal")
        except Exception as e:
            ui.error(f"Erro no WebSocket: {e}", "EnhancedTerminal")
            await self._send_status(websocket, ConnectionStatus.ERROR, {
                'error': str(e)
            })
        finally:
            await self._cleanup_connection(project_id)
    
    async def _command_loop(self, websocket: WebSocket, project_id: str, terminal: terminalTerminal):
        """Loop principal para processar comandos"""
        while True:
            try:
                data = await websocket.receive_text()
                message = json.loads(data)
                
                # Atualiza última atividade
                self.last_activity[project_id] = datetime.utcnow()
                
                msg_type = message.get('type')
                
                if msg_type == 'command':
                    await self._execute_command(websocket, project_id, terminal, message)
                
                elif msg_type == 'pong':
                    # Resposta ao heartbeat, já processada
                    continue
                
                elif msg_type == 'ping':
                    # Cliente fazendo ping
                    await websocket.send_json({'type': 'pong'})
                
                elif msg_type == 'history':
                    # Requisição de histórico (implementar depois com DB)
                    await websocket.send_json({
                        'type': 'history',
                        'commands': []  # TODO: Buscar do banco de dados
                    })
                
                elif msg_type == 'cancel':
                    # Cancelar comando em execução (implementar)
                    ui.info(f"Cancelamento requisitado para projeto: {project_id}", "Command")
                    
            except WebSocketDisconnect:
                ui.info(f"WebSocket desconectado: {project_id}", "EnhancedTerminal")
                break
            except json.JSONDecodeError as e:
                ui.error(f"Erro ao decodificar JSON: {e}", "EnhancedTerminal")
                await self._send_status(websocket, ConnectionStatus.ERROR, {
                    'error': 'Formato de mensagem inválido'
                })
            except Exception as e:
                ui.error(f"Erro no loop de comandos: {e}", "EnhancedTerminal")
                await self._send_status(websocket, ConnectionStatus.ERROR, {
                    'error': str(e)
                })
                break
    
    async def _execute_command(self, websocket: WebSocket, project_id: str, terminal: terminalTerminal, message: dict):
        """Executa comando com timeout e feedback"""
        command = message.get('command', '').strip()
        
        if not command:
            return
        
        ui.debug(f"Executando comando: {command}", "EnhancedTerminal")
        
        # Atualiza status para executando
        self.connection_status[project_id] = ConnectionStatus.EXECUTING
        await self._send_status(websocket, ConnectionStatus.EXECUTING, {
            'command': command
        })
        
        try:
            # Executa comando com timeout
            execute_task = asyncio.create_task(terminal.execute(command))
            result = await asyncio.wait_for(execute_task, timeout=self.command_timeout)
            
            # Envia resultado
            await websocket.send_json({
                'type': 'output',
                'command': command,
                'output': result['output'],
                'success': result['success'],
                'timestamp': datetime.utcnow().isoformat()
            })
            
            # Restaura status
            self.connection_status[project_id] = ConnectionStatus.CONNECTED
            await self._send_status(websocket, ConnectionStatus.CONNECTED)
            
            # Log do resultado
            if result['success']:
                ui.success(f"Comando executado: {command}", "EnhancedTerminal")
            else:
                ui.warning(f"Comando falhou: {command}", "EnhancedTerminal")
            
            # TODO: Salvar no histórico do banco de dados
            
        except asyncio.TimeoutError:
            ui.error(f"Timeout ao executar comando: {command}", "EnhancedTerminal")
            await self._send_status(websocket, ConnectionStatus.ERROR, {
                'error': f'Comando excedeu timeout de {self.command_timeout}s'
            })
            self.connection_status[project_id] = ConnectionStatus.CONNECTED
            
        except Exception as e:
            ui.error(f"Erro ao executar comando: {e}", "EnhancedTerminal")
            await self._send_status(websocket, ConnectionStatus.ERROR, {
                'error': str(e)
            })
            self.connection_status[project_id] = ConnectionStatus.CONNECTED
    
    async def _cleanup_connection(self, project_id: str):
        """Limpa recursos da conexão"""
        ui.info(f"Limpando conexão para projeto: {project_id}", "EnhancedTerminal")
        
        # Cancela heartbeat
        if project_id in self.heartbeat_tasks:
            self.heartbeat_tasks[project_id].cancel()
            del self.heartbeat_tasks[project_id]
        
        # Remove da lista de conexões
        if project_id in self.connections:
            del self.connections[project_id]
        
        # Atualiza status
        if project_id in self.connection_status:
            self.connection_status[project_id] = ConnectionStatus.DISCONNECTED
        
        # Remove autenticação
        if project_id in self.authenticated_sessions:
            self.authenticated_sessions.discard(project_id)
        
        ui.info(f"Conexão limpa para projeto: {project_id}", "EnhancedTerminal")
    
    async def broadcast_to_project(self, project_id: str, message: Dict):
        """Envia mensagem para um projeto específico"""
        if project_id in self.connections:
            try:
                await self.connections[project_id].send_json(message)
            except Exception as e:
                ui.error(f"Erro ao enviar mensagem: {e}", "EnhancedTerminal")
    
    def get_terminal(self, project_id: str) -> Optional[terminalTerminal]:
        """Retorna o terminal de um projeto"""
        return self.terminals.get(project_id)
    
    def get_status(self, project_id: str) -> str:
        """Retorna o status atual da conexão"""
        return self.connection_status.get(project_id, ConnectionStatus.DISCONNECTED)
    
    def get_all_connections(self) -> Dict[str, str]:
        """Retorna status de todas as conexões"""
        return {
            project_id: {
                'status': self.connection_status.get(project_id, ConnectionStatus.DISCONNECTED),
                'authenticated': project_id in self.authenticated_sessions,
                'last_activity': self.last_activity.get(project_id).isoformat() if project_id in self.last_activity else None
            }
            for project_id in self.terminals.keys()
        }


# Instância global melhorada
enhanced_terminal_ws = EnhancedTerminalWebSocket()