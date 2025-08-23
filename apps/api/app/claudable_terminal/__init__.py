"""terminalTerminal - Terminal simples para comandos Claude CLI"""

from .terminal_simple import terminalTerminal
from .websocket_handler import TerminalWebSocket, terminal_ws

__version__ = "1.0.0"
__all__ = ['terminalTerminal', 'TerminalWebSocket', 'terminal_ws']