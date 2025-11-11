"""
Tests pour l'API du proxy default
"""
import pytest
from fastapi.testclient import TestClient
from main import app
from config import settings

# Désactiver l'authentification pour les tests unitaires
settings.api_key = None

client = TestClient(app)


def test_health_endpoint():
    """Test de l'endpoint de santé"""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["service"] == "cursor-agent-proxy"


def test_list_models():
    """Test de l'endpoint de liste des modèles"""
    response = client.get("/v1/models")
    assert response.status_code == 200
    data = response.json()
    assert data["object"] == "list"
    assert len(data["data"]) > 0
    
    # Vérifier que les modèles principaux sont présents
    model_ids = [model["id"] for model in data["data"]]
    assert "default" in model_ids
    assert "gpt-5" in model_ids
    assert "sonnet-4" in model_ids
    assert "gpt-4o" in model_ids  # Alias OpenAI


def test_chat_completions():
    """Test de l'endpoint de chat completions"""
    response = client.post(
        "/v1/chat/completions",
        json={
            "model": "default",
            "messages": [
                {"role": "user", "content": "Bonjour"}
            ]
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert "id" in data
    assert data["object"] == "chat.completion"
    assert "choices" in data
    assert len(data["choices"]) > 0
    assert "usage" in data


def test_chat_completions_with_system_message():
    """Test avec un message système"""
    response = client.post(
        "/v1/chat/completions",
        json={
            "model": "default",
            "messages": [
                {"role": "system", "content": "Tu es un assistant utile."},
                {"role": "user", "content": "Dis bonjour"}
            ]
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert data["choices"][0]["message"]["role"] == "assistant"


def test_chat_completions_stream():
    """Test de l'endpoint de streaming"""
    response = client.post(
        "/v1/chat/completions-stream",
        json={
            "model": "default",
            "messages": [
                {"role": "user", "content": "Test"}
            ]
        }
    )
    assert response.status_code == 200
    assert response.headers["content-type"] == "text/event-stream; charset=utf-8"


def test_chat_completions_empty_messages():
    """Test avec une liste de messages vide"""
    response = client.post(
        "/v1/chat/completions",
        json={
            "model": "default",
            "messages": []
        }
    )
    # Devrait retourner une erreur de validation
    assert response.status_code in [400, 422]


def test_chat_completions_invalid_model():
    """Test avec un modèle invalide"""
    response = client.post(
        "/v1/chat/completions",
        json={
            "model": "invalid-model",
            "messages": [
                {"role": "user", "content": "Test"}
            ]
        }
    )
    # L'API devrait accepter n'importe quel modèle (comme OpenAI)
    assert response.status_code == 200
