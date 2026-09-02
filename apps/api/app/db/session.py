# Stub database layer: the terminal app does not use a real database.
# These stubs keep the routers that expect a SQLAlchemy session importable.

from typing import Generator
from app.core.config import settings

# Stub engine for compatibility
class StubEngine:
    """Stub engine to prevent SQLAlchemy errors"""
    pass

engine = StubEngine()

# Stub session for compatibility
class StubSession:
    """Stub session to prevent SQLAlchemy errors"""
    def __init__(self):
        pass
    
    def close(self):
        pass

SessionLocal = StubSession

def get_db() -> Generator[StubSession, None, None]:
    """Database session dependency - returns a no-op stub session"""
    db = StubSession()
    try:
        yield db
    finally:
        db.close()
