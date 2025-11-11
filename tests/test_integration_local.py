"""
Tests d'intégration LOCAUX (Python uniquement, sans Docker)

Ces tests lancent automatiquement l'application FastAPI en local sur le port 8001,
exécutent les tests, puis arrêtent le serveur proprement.

Niveau 1 : Tests avec Python uniquement (plus rapides)

Pour exécuter:
    just test-integration-local
    ou
    uv run pytest tests/test_integration_local.py -v
"""
import pytest
import os
import subprocess
import time
import socket
import signal
import requests
from openai import OpenAI
from openai.types.chat import ChatCompletion


# Configuration
LOCAL_PORT = 8001
API_URL = f"http://localhost:{LOCAL_PORT}"
API_KEY = os.getenv("API_KEY", "")


def is_port_in_use(port: int) -> bool:
    """Vérifie si un port est déjà utilisé"""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('localhost', port)) == 0


def wait_for_server(url: str, timeout: int = 30) -> bool:
    """Attend que le serveur soit prêt"""
    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            response = requests.get(f"{url}/health", timeout=2)
            if response.status_code == 200:
                return True
        except requests.exceptions.RequestException:
            pass
        time.sleep(0.5)
    return False


@pytest.fixture(scope="module")
def fastapi_server():
    """
    Fixture qui démarre et arrête automatiquement le serveur FastAPI local
    """
    # Vérifier que le port n'est pas déjà utilisé
    if is_port_in_use(LOCAL_PORT):
        pytest.skip(f"Port {LOCAL_PORT} déjà utilisé. Arrêtez le serveur existant avec 'just stop'")
    
    # Charger l'API_KEY depuis .env si disponible
    env = os.environ.copy()
    if os.path.exists(".env"):
        with open(".env") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, value = line.split("=", 1)
                    env[key] = value
    
    # Vérifier que CURSOR_API_KEY est disponible
    if "CURSOR_API_KEY" not in env:
        pytest.skip("CURSOR_API_KEY non configurée. Les tests seront ignorés.")
    
    print(f"\n🚀 Démarrage du serveur FastAPI local sur le port {LOCAL_PORT}...")
    
    # Démarrer le serveur
    process = subprocess.Popen(
        ["uv", "run", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", str(LOCAL_PORT)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        preexec_fn=os.setsid  # Créer un nouveau groupe de processus
    )
    
    # Attendre que le serveur soit prêt
    if not wait_for_server(API_URL):
        process.kill()
        pytest.fail(f"Le serveur n'a pas démarré dans les temps sur le port {LOCAL_PORT}")
    
    print(f"✅ Serveur FastAPI démarré (PID: {process.pid})")
    
    # Yield pour exécuter les tests
    yield API_URL
    
    # Arrêter le serveur proprement
    print(f"\n🛑 Arrêt du serveur FastAPI (PID: {process.pid})...")
    try:
        # Tuer tout le groupe de processus
        os.killpg(os.getpgid(process.pid), signal.SIGTERM)
        process.wait(timeout=5)
    except Exception as e:
        print(f"⚠️  Erreur lors de l'arrêt: {e}")
        process.kill()
    
    print("✅ Serveur arrêté")


@pytest.fixture(scope="module")
def client(fastapi_server):
    """Client OpenAI configuré pour le serveur local"""
    if not API_KEY:
        pytest.skip("API_KEY non configurée")
    
    return OpenAI(
        base_url=f"{fastapi_server}/v1",
        api_key=API_KEY
    )


class TestLocalHealth:
    """Tests de santé du serveur local"""
    
    def test_health_endpoint(self, fastapi_server):
        """Vérifier que le endpoint /health répond"""
        response = requests.get(f"{fastapi_server}/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
        print(f"\n✅ Health check: {data}")


class TestLocalAuthentication:
    """Tests d'authentification sur serveur local"""
    
    def test_authentication_required(self, fastapi_server):
        """Vérifier que l'authentification est requise"""
        # Sans authentification
        response = requests.post(
            f"{fastapi_server}/v1/chat/completions",
            json={"model": "cursor-agent", "messages": [{"role": "user", "content": "Test"}]}
        )
        
        # Devrait retourner 401
        assert response.status_code == 401
        print(f"\n✅ Authentification requise (HTTP {response.status_code})")
    
    def test_invalid_api_key(self, fastapi_server):
        """Vérifier que les mauvaises clés sont rejetées"""
        response = requests.post(
            f"{fastapi_server}/v1/chat/completions",
            headers={"Authorization": "Bearer invalid-key"},
            json={"model": "cursor-agent", "messages": [{"role": "user", "content": "Test"}]}
        )
        
        # Devrait retourner 403
        assert response.status_code == 403
        print(f"\n✅ Mauvaise clé rejetée (HTTP {response.status_code})")


class TestLocalModels:
    """Tests de l'endpoint /v1/models sur serveur local"""
    
    def test_list_models(self, client):
        """Vérifier que l'endpoint /v1/models fonctionne"""
        models = client.models.list()
        
        assert hasattr(models, 'data')
        assert len(models.data) > 0
        
        model_ids = [model.id for model in models.data]
        assert "cursor-agent" in model_ids
        
        print(f"\n✅ Modèles disponibles: {model_ids}")


class TestLocalChatCompletions:
    """Tests de chat completions sur serveur local"""
    
    def test_basic_chat(self, client):
        """Test d'un chat basique"""
        response = client.chat.completions.create(
            model="cursor-agent",
            messages=[
                {"role": "user", "content": "Réponds juste: OK"}
            ]
        )
        
        assert isinstance(response, ChatCompletion)
        assert len(response.choices) > 0
        assert response.choices[0].message.content
        
        print(f"\n✅ Chat basique: {response.choices[0].message.content[:50]}...")
    
    def test_chat_with_system_message(self, client):
        """Test avec message system"""
        response = client.chat.completions.create(
            model="cursor-agent",
            messages=[
                {"role": "system", "content": "Tu es un assistant Python."},
                {"role": "user", "content": "Quel langage tu connais?"}
            ]
        )
        
        assert isinstance(response, ChatCompletion)
        assert "python" in response.choices[0].message.content.lower()
        
        print(f"\n✅ Avec system: {response.choices[0].message.content[:50]}...")
    
    def test_multi_turn_conversation(self, client):
        """Test de conversation multi-tours"""
        messages = [
            {"role": "user", "content": "Quel est 2+2?"}
        ]
        
        # Premier tour
        response1 = client.chat.completions.create(
            model="cursor-agent",
            messages=messages
        )
        
        # Ajouter la réponse
        messages.append({
            "role": "assistant",
            "content": response1.choices[0].message.content
        })
        
        # Deuxième tour
        messages.append({"role": "user", "content": "Et 3+3?"})
        response2 = client.chat.completions.create(
            model="cursor-agent",
            messages=messages
        )
        
        assert isinstance(response2, ChatCompletion)
        print(f"\n✅ Multi-tours OK: Tour 1 et Tour 2 réussis")


class TestLocalErrorHandling:
    """Tests de gestion d'erreurs sur serveur local"""
    
    def test_empty_messages(self, client):
        """Vérifier que les messages vides sont rejetés"""
        with pytest.raises(Exception) as exc_info:
            client.chat.completions.create(
                model="cursor-agent",
                messages=[]
            )
        
        assert "400" in str(exc_info.value) or "422" in str(exc_info.value)
        print(f"\n✅ Messages vides rejetés: {str(exc_info.value)[:50]}...")


if __name__ == "__main__":
    print("🧪 Tests d'intégration LOCAL (Python uniquement, port 8001)")
    print("=" * 80)
    print(f"API URL: {API_URL}")
    print(f"API_KEY: {'✅ Configurée' if API_KEY else '❌ Non configurée'}")
    print("=" * 80)
    print("\nPour exécuter les tests:")
    print("  just test-integration-local")
    print("  ou")
    print("  uv run pytest tests/test_integration_local.py -v")

