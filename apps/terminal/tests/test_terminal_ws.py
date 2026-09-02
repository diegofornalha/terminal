"""Testes do terminal PTY via WebSocket (roda sem servidor externo)."""
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"ok": True}


def test_pty_executa_comando():
    """Abre uma sessão PTY com bash, executa um comando e valida a saída."""
    with client.websocket_connect("/ws/terminal/interactive/pytest-session") as ws:
        ws.send_json({"type": "start", "command": "bash"})
        msg = ws.receive_json()
        assert msg["type"] == "session_started"
        assert msg["success"] is True

        ws.send_json({"type": "input", "data": "echo pty_ok_$((40+2))\n"})

        output = ""
        deadline = time.time() + 10
        while "pty_ok_42" not in output and time.time() < deadline:
            msg = ws.receive_json()
            if msg["type"] == "output":
                output += msg["data"]

        assert "pty_ok_42" in output

        ws.send_json({"type": "close"})


def _aguarda_session_started(ws):
    """Ignora mensagens de output pendentes até chegar o session_started."""
    deadline = time.time() + 10
    while time.time() < deadline:
        msg = ws.receive_json()
        if msg["type"] == "session_started":
            return msg
    raise AssertionError("session_started não chegou")


def test_reconexao_mantem_sessao():
    """Desconectar e reconectar com o mesmo session_id volta à mesma sessão."""
    session_id = "pytest-reconnect"

    with client.websocket_connect(f"/ws/terminal/interactive/{session_id}") as ws:
        ws.send_json({"type": "start", "command": "bash"})
        msg = _aguarda_session_started(ws)
        assert msg["success"] is True
        assert msg["reconnected"] is False

    with client.websocket_connect(f"/ws/terminal/interactive/{session_id}") as ws:
        ws.send_json({"type": "start", "command": "bash"})
        msg = _aguarda_session_started(ws)
        assert msg["success"] is True
        assert msg["reconnected"] is True
        ws.send_json({"type": "close"})
