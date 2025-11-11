"""
Configuration du proxy cursor-agent
"""
import os
from typing import Optional
from pydantic_settings import BaseSettings
from pydantic import ConfigDict


class Settings(BaseSettings):
    """Configuration de l'application"""
    
    model_config = ConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False
    )
    
    # Server
    host: str = "0.0.0.0"
    port: int = 8001
    reload: bool = False
    
    # Cursor Agent Integration
    cursor_agent_mode: str = "cli"  # "cli", "http", "library"
    cursor_agent_cli_path: Optional[str] = None  # Chemin vers l'exécutable CLI
    cursor_agent_http_url: Optional[str] = None  # URL de l'API HTTP si mode=http
    cursor_agent_timeout: int = 60  # Timeout en secondes
    cursor_api_key: Optional[str] = None  # Token d'authentification pour cursor-agent (CURSOR_API_KEY)
    
    # API
    api_title: str = "Cursor Agent API Proxy"
    api_version: str = "1.0.0"
    api_description: str = "Proxy FastAPI pour cursor-agent compatible avec l'API OpenAI"
    
    # Security (à implémenter)
    api_key: Optional[str] = None  # Pour l'authentification
    
    # Logging
    log_level: str = "INFO"


# Instance globale des settings
settings = Settings()
