'use client';

import { useEffect, useRef } from 'react';
import { Terminal } from '@xterm/xterm';
import { FitAddon } from '@xterm/addon-fit';
import '@xterm/xterm/css/xterm.css';

export default function ClaudableTerminalInteractive() {
  const terminalRef = useRef<HTMLDivElement>(null);
  const terminalInstance = useRef<Terminal | null>(null);

  useEffect(() => {
    if (!terminalRef.current || terminalInstance.current) return;

    // Criar terminal
    const terminal = new Terminal({
      cursorBlink: true,
      fontSize: 14,
      fontFamily: 'monospace',
      theme: {
        background: '#1e1e1e',
        foreground: '#d4d4d4'
      }
    });
    
    const fitAddon = new FitAddon();
    terminal.loadAddon(fitAddon);
    terminal.open(terminalRef.current);
    
    // Ajustar tamanho
    setTimeout(() => fitAddon.fit(), 100);
    
    // Mensagem inicial
    terminal.writeln('🚀 Terminal System - Simples e Funcional');
    terminal.writeln('Conectando...\n');

    // WebSocket com detecção de protocolo
    const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsHost = window.location.protocol === 'https:' 
      ? window.location.host 
      : `${window.location.hostname}:8000`;
    const wsUrl = `${wsProtocol}//${wsHost}/ws/terminal/default`;

    console.log('Conectando WebSocket:', wsUrl);
    const ws = new WebSocket(wsUrl);

    ws.onopen = () => {
      console.log('WebSocket conectado');
      terminal.writeln('✅ Conectado!');
      terminal.write('$ ');
      
      // Buffer para comandos
      let commandBuffer = '';
      
      terminal.onData((data) => {
        // Enter - enviar comando
        if (data === '\r' || data === '\n') {
          if (commandBuffer.trim()) {
            terminal.write('\r\n');
            ws.send(JSON.stringify({ 
              type: 'command', 
              command: commandBuffer.trim()
            }));
            commandBuffer = '';
          } else {
            terminal.write('\r\n$ ');
          }
        }
        // Backspace
        else if (data === '\u007F' || data === '\b') {
          if (commandBuffer.length > 0) {
            commandBuffer = commandBuffer.slice(0, -1);
            terminal.write('\b \b');
          }
        }
        // Caractere normal
        else if (data.charCodeAt(0) >= 32) {
          commandBuffer += data;
          terminal.write(data);
        }
      });
    };

    ws.onmessage = (event) => {
      try {
        const msg = JSON.parse(event.data);
        
        switch(msg.type) {
          case 'init':
            console.log('Terminal inicializado');
            break;
            
          case 'output':
            if (msg.output) {
              terminal.write(msg.output);
              if (!msg.output.endsWith('\n')) {
                terminal.write('\r\n');
              }
            }
            terminal.write('$ ');
            break;
            
          case 'error':
            terminal.writeln(`\r\n❌ Erro: ${msg.message}`);
            terminal.write('$ ');
            break;
        }
      } catch {
        terminal.write(event.data);
      }
    };

    ws.onerror = (error) => {
      console.error('WebSocket erro:', error);
      terminal.writeln('\r\n❌ Erro de conexão');
    };

    ws.onclose = () => {
      terminal.writeln('\r\n⚠️ Desconectado');
    };

    // Redimensionar
    const handleResize = () => fitAddon.fit();
    window.addEventListener('resize', handleResize);

    terminalInstance.current = terminal;

    return () => {
      window.removeEventListener('resize', handleResize);
      ws.close();
      terminal.dispose();
      terminalInstance.current = null;
    };
  }, []);

  return (
    <div className="w-full h-full bg-black p-2">
      <div ref={terminalRef} className="w-full h-full" />
    </div>
  );
}