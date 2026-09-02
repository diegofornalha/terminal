"""Terminal API — módulo isolado: um PTY real exposto via WebSocket."""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.terminal import router as terminal_router
from app.core.logging import configure_logging
from app.core.terminal_ui import ui

configure_logging()

app = FastAPI(title="Terminal API")

# CORS liberado para desenvolvimento local
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(terminal_router)


@app.get("/health")
def health():
    return {"ok": True}


@app.on_event("startup")
def on_startup() -> None:
    ui.info("Terminal API pronta")
    ui.panel(
        "WebSocket: /ws/terminal/interactive/{session_id}\nREST: /health",
        title="Endpoints",
        style="green",
    )
