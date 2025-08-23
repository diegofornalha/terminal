# Neo4j is used instead of SQLite - this is a stub to prevent import errors
# The actual database operations are handled by Neo4j services

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
    """Database session dependency - returns stub for Neo4j compatibility"""
    db = StubSession()
    try:
        yield db
    finally:
        db.close()
