"""Terminal mínimo"""
import os, pty, subprocess, fcntl

class InteractiveTerminal:
    def __init__(self, _):
        self.master_fd = None
        
    async def start_session(self, _=None):
        self.master_fd, slave_fd = pty.openpty()
        fcntl.fcntl(self.master_fd, fcntl.F_SETFL, os.O_NONBLOCK)
        subprocess.Popen("claude --dangerously-skip-permissions || bash", 
                        stdin=slave_fd, stdout=slave_fd, stderr=slave_fd, shell=True)
        os.close(slave_fd)
        return {'success': True}
    
    async def send_input(self, data):
        if self.master_fd: os.write(self.master_fd, data.encode())
        return {'success': True}
    
    async def read_output(self):
        try: return os.read(self.master_fd, 4096).decode('utf-8', errors='replace')
        except: return None
    
    async def close(self):
        if self.master_fd: os.close(self.master_fd)