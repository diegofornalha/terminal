# Terminal API

Módulo isolado do terminal web: um PTY real (o mesmo mecanismo do SSH) exposto
via WebSocket, que abre `claude` interativo — ou `bash` como fallback.

É a versão enxuta do antigo `apps/api` (fork do Claudable): só o que o
frontend usa, nada mais.

## Estrutura

```
app/
├── main.py                  # FastAPI + CORS + /health
├── api/terminal.py          # WebSocket /ws/terminal/interactive/{session_id}
├── terminal/pty_session.py  # InteractiveTerminal: PTY, process group, resize
└── core/                    # logging + UI de console (Rich)
```

## Rodar

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Verificar: `curl http://localhost:8000/health` → `{"ok":true}`

O frontend (`apps/web`, porta 3005) conecta em
`ws://<host>:8000/ws/terminal/interactive/{sessionId}`.

## Protocolo WebSocket

Cliente → servidor:

| type     | payload            | efeito                                   |
|----------|--------------------|------------------------------------------|
| `start`  | `command?`         | inicia o PTY (ou reconecta à sessão viva) |
| `input`  | `data`             | escreve no stdin do PTY                   |
| `resize` | `rows`, `cols`     | redimensiona o terminal                   |
| `close`  | —                  | encerra a sessão                          |

Servidor → cliente: `session_started` (com `reconnected`), `output` (`data`),
`error`. Sessões sobrevivem à desconexão por até 1 hora (reconexão pelo mesmo
`session_id`).

## Testes

```bash
.venv/bin/python -m pytest tests/ -v
```

## ⚠️ Segurança

O PTY roda `claude --dangerously-skip-permissions || bash` **sem autenticação**:
quem alcança a porta ganha shell na máquina. Não exponha 8000/3005 direto na
internet — use rede local, VPN ou túnel autenticado.
