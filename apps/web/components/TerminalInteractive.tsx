'use client';

import { useEffect, useRef } from 'react';
import { Terminal } from '@xterm/xterm';
import { FitAddon } from '@xterm/addon-fit';
import '@xterm/xterm/css/xterm.css';

interface Props {
  projectId?: string;
}

export default function ClaudableTerminalInteractive({ projectId }: Props) {
  const terminalRef = useRef<HTMLDivElement>(null);
  const terminalInstance = useRef<Terminal | null>(null);

  useEffect(() => {
    if (!terminalRef.current || terminalInstance.current) return;

    const terminal = new Terminal({
      cursorBlink: true,
      fontSize: 14,
      fontFamily: 'Menlo, Monaco, "Courier New", monospace',
      theme: { background: '#1e1e1e', foreground: '#d4d4d4' },
      scrollback: 5000,
    });

    const fitAddon = new FitAddon();
    terminal.loadAddon(fitAddon);
    terminal.open(terminalRef.current);
    setTimeout(() => fitAddon.fit(), 50);

    terminal.writeln('\x1b[38;5;208m🚀 Terminal interativo (PTY) — abrindo Claude...\x1b[0m');

    // Sessão estável por aba (permite reconexão)
    let sessionId = sessionStorage.getItem('term_session');
    if (!sessionId) {
      sessionId = (projectId || 'sess') + '-' + Math.random().toString(36).slice(2, 10);
      sessionStorage.setItem('term_session', sessionId);
    }

    const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsHost =
      window.location.protocol === 'https:'
        ? window.location.host
        : `${window.location.hostname}:8000`;
    const wsUrl = `${wsProtocol}//${wsHost}/ws/terminal/interactive/${sessionId}`;

    const ws = new WebSocket(wsUrl);

    const sendResize = () => {
      try {
        fitAddon.fit();
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: 'resize', rows: terminal.rows, cols: terminal.cols }));
        }
      } catch {
        /* noop */
      }
    };

    ws.onopen = () => {
      // Inicia (ou reconecta) a sessão PTY
      ws.send(JSON.stringify({ type: 'start' }));
      setTimeout(sendResize, 100);

      // Cada tecla vai direto pro PTY
      terminal.onData((data) => {
        if (ws.readyState === WebSocket.OPEN) {
          ws.send(JSON.stringify({ type: 'input', data }));
        }
      });
    };

    ws.onmessage = (event) => {
      let msg: any;
      try {
        msg = JSON.parse(event.data);
      } catch {
        terminal.write(event.data);
        return;
      }
      switch (msg.type) {
        case 'output':
          terminal.write(msg.data);
          break;
        case 'session_started':
          if (msg.reconnected) {
            terminal.writeln('\x1b[32m↺ Reconectado à sessão\x1b[0m');
          }
          break;
        case 'error':
          terminal.writeln(`\r\n\x1b[31m❌ ${msg.message}\x1b[0m`);
          break;
      }
    };

    ws.onerror = () => terminal.writeln('\r\n\x1b[31m❌ Erro de conexão\x1b[0m');
    ws.onclose = () => terminal.writeln('\r\n\x1b[33m⚠️ Desconectado\x1b[0m');

    window.addEventListener('resize', sendResize);
    terminalInstance.current = terminal;

    return () => {
      window.removeEventListener('resize', sendResize);
      try {
        ws.close();
      } catch {
        /* noop */
      }
      terminal.dispose();
      terminalInstance.current = null;
    };
  }, [projectId]);

  return (
    <div className="w-full h-screen bg-black p-2">
      <div ref={terminalRef} className="w-full h-full" />
    </div>
  );
}
