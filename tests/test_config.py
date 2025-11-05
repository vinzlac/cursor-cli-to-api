"""
Tests pour la configuration
"""
import pytest
from config import Settings


def test_default_settings():
    """Test des valeurs par défaut"""
    settings = Settings()
    assert settings.host == "0.0.0.0"
    assert settings.port == 8001
    assert settings.cursor_agent_mode == "cli"
    assert settings.cursor_agent_timeout == 60


def test_settings_from_env(monkeypatch):
    """Test du chargement depuis les variables d'environnement"""
    monkeypatch.setenv("CURSOR_AGENT_MODE", "http")
    monkeypatch.setenv("CURSOR_AGENT_HTTP_URL", "http://test:3000/api")
    monkeypatch.setenv("PORT", "9000")
    
    settings = Settings()
    assert settings.cursor_agent_mode == "http"
    assert settings.cursor_agent_http_url == "http://test:3000/api"
    assert settings.port == 9000
