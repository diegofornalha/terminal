"""Terminal interativo com PTY real."""
import os
import pty
import fcntl
import struct
import termios
import signal
import select
import subprocess


class InteractiveTerminal:
    """PTY persistente que abre `claude` interativo (fallback para bash)."""

    def __init__(self, session_id):
        self.session_id = session_id
        self.master_fd = None
        self.process = None

    async def start_session(self, command=None):
        # Se já existe um processo vivo, não recria
        if self.is_alive():
            return {'success': True, 'message': 'Sessão já ativa'}

        self.master_fd, slave_fd = pty.openpty()

        # master em modo não-bloqueante
        flags = fcntl.fcntl(self.master_fd, fcntl.F_GETFL)
        fcntl.fcntl(self.master_fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)

        shell_cmd = command or "claude --dangerously-skip-permissions || bash"
        self.process = subprocess.Popen(
            shell_cmd,
            stdin=slave_fd, stdout=slave_fd, stderr=slave_fd,
            shell=True,
            preexec_fn=os.setsid,  # grupo próprio p/ matar a árvore depois
            env={**os.environ, 'TERM': 'xterm-256color'},
        )
        os.close(slave_fd)
        return {'success': True, 'message': 'Sessão iniciada'}

    async def send_input(self, data):
        if self.master_fd is not None:
            try:
                os.write(self.master_fd, data.encode())
            except OSError:
                return {'success': False}
        return {'success': True}

    async def read_output(self, timeout=0.1):
        if self.master_fd is None:
            return {'success': False, 'output': ''}
        try:
            r, _, _ = select.select([self.master_fd], [], [], timeout)
            if r:
                data = os.read(self.master_fd, 65536)
                return {'success': True, 'output': data.decode('utf-8', errors='replace')}
            return {'success': True, 'output': ''}
        except (OSError, ValueError):
            return {'success': False, 'output': ''}

    def is_alive(self):
        if self.process is None:
            return False
        return self.process.poll() is None

    async def resize_terminal(self, rows, cols):
        if self.master_fd is not None:
            try:
                winsize = struct.pack('HHHH', int(rows), int(cols), 0, 0)
                fcntl.ioctl(self.master_fd, termios.TIOCSWINSZ, winsize)
            except OSError:
                return {'success': False}
        return {'success': True}

    async def close_session(self):
        if self.process is not None and self.is_alive():
            try:
                os.killpg(os.getpgid(self.process.pid), signal.SIGTERM)
            except OSError:
                pass
        if self.master_fd is not None:
            try:
                os.close(self.master_fd)
            except OSError:
                pass
        self.master_fd = None
        self.process = None
        return {'success': True}

    # Alias por compatibilidade
    async def close(self):
        return await self.close_session()
