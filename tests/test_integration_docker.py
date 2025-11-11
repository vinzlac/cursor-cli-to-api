"""
Tests d'intégration DOCKER (avec Docker Compose)

Ces tests lancent automatiquement Docker Compose sur le port 8002,
exécutent les tests, puis arrêtent les conteneurs proprement.

Niveau 2 : Tests avec Docker (environnement de production)

Pour exécuter:
    just test-integration-docker
    ou
    uv run pytest tests/test_integration_docker.py -v
"""
import pytest
import os
import subprocess
import time
import socket
import requests
from openai import OpenAI
from openai.types.chat import ChatCompletion


# Configuration
DOCKER_PORT = 8002
API_URL = f"http://localhost:{DOCKER_PORT}"
API_KEY = os.getenv("API_KEY", "")


def is_port_in_use(port: int) -> bool:
    """Vérifie si un port est déjà utilisé"""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('localhost', port)) == 0


def is_docker_running() -> bool:
    """Vérifie si Docker est disponible"""
    try:
        result = subprocess.run(
            ["docker", "ps"],
            capture_output=True,
            timeout=5
        )
        return result.returncode == 0
    except Exception:
        return False


def is_compose_project_running(project_name: str = "cursor-openai-proxy-test") -> bool:
    """Vérifie si un projet Docker Compose est déjà en cours"""
    try:
        result = subprocess.run(
            ["docker-compose", "-p", project_name, "ps", "-q"],
            capture_output=True,
            timeout=5
        )
        return bool(result.stdout.strip())
    except Exception:
        return False


def wait_for_server(url: str, timeout: int = 60) -> bool:
    """Attend que le serveur soit prêt (avec health check)"""
    print(f"   Attente du serveur ({timeout}s max)...", end="", flush=True)
    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            response = requests.get(f"{url}/health", timeout=2)
            if response.status_code == 200:
                print(" ✅")
                return True
        except requests.exceptions.RequestException:
            pass
        print(".", end="", flush=True)
        time.sleep(2)
    print(" ❌")
    return False


@pytest.fixture(scope="module")
def docker_compose():
    """
    Fixture qui lance et arrête automatiquement Docker Compose
    """
    # Vérifier que Docker est disponible
    if not is_docker_running():
        pytest.skip("Docker n'est pas disponible ou n'est pas démarré")
    
    # Vérifier que le port n'est pas déjà utilisé
    if is_port_in_use(DOCKER_PORT):
        pytest.skip(f"Port {DOCKER_PORT} déjà utilisé. Arrêtez le service existant.")
    
    # Vérifier qu'un projet compose n'est pas déjà en cours
    project_name = "cursor-openai-proxy-test"
    if is_compose_project_running(project_name):
        pytest.skip(f"Projet Docker Compose '{project_name}' déjà en cours. Arrêtez-le avec 'docker-compose -p {project_name} down'")
    
    # Vérifier que le fichier docker-compose.test.yml existe
    if not os.path.exists("docker-compose.test.yml"):
        pytest.skip("docker-compose.test.yml non trouvé. Créez-le d'abord.")
    
    print(f"\n🐳 Démarrage de Docker Compose sur le port {DOCKER_PORT}...")
    
    # Démarrer Docker Compose avec un nom de projet unique
    try:
        subprocess.run(
            ["docker-compose", "-f", "docker-compose.test.yml", "-p", project_name, "up", "-d", "--build"],
            check=True,
            capture_output=True,
            text=True
        )
    except subprocess.CalledProcessError as e:
        pytest.fail(f"Échec du démarrage de Docker Compose: {e.stderr}")
    
    # Attendre que le serveur soit prêt
    if not wait_for_server(API_URL, timeout=60):
        # Afficher les logs en cas d'échec
        logs = subprocess.run(
            ["docker-compose", "-f", "docker-compose.test.yml", "-p", project_name, "logs", "--tail=50"],
            capture_output=True,
            text=True
        )
        print(f"\n📋 Logs Docker:\n{logs.stdout}")
        
        # Arrêter les conteneurs
        subprocess.run(
            ["docker-compose", "-f", "docker-compose.test.yml", "-p", project_name, "down"],
            capture_output=True
        )
        pytest.fail(f"Le serveur Docker n'a pas démarré dans les temps sur le port {DOCKER_PORT}")
    
    print(f"✅ Docker Compose démarré")
    
    # Yield pour exécuter les tests
    yield API_URL
    
    # Arrêter Docker Compose proprement
    print(f"\n🛑 Arrêt de Docker Compose...")
    try:
        subprocess.run(
            ["docker-compose", "-f", "docker-compose.test.yml", "-p", project_name, "down", "-v"],
            check=True,
            capture_output=True,
            timeout=30
        )
        print("✅ Docker Compose arrêté")
    except subprocess.CalledProcessError as e:
        print(f"⚠️  Erreur lors de l'arrêt: {e.stderr}")
    except subprocess.TimeoutExpired:
        print("⚠️  Timeout lors de l'arrêt de Docker Compose")


@pytest.fixture(scope="module")
def client(docker_compose):
    """Client OpenAI configuré pour le serveur Docker"""
    if not API_KEY:
        pytest.skip("API_KEY non configurée")
    
    return OpenAI(
        base_url=f"{docker_compose}/v1",
        api_key=API_KEY
    )


class TestDockerHealth:
    """Tests de santé du serveur Docker"""
    
    def test_health_endpoint(self, docker_compose):
        """Vérifier que le endpoint /health répond"""
        response = requests.get(f"{docker_compose}/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
        print(f"\n✅ Health check Docker: {data}")


class TestDockerAuthentication:
    """Tests d'authentification sur serveur Docker"""
    
    def test_authentication_required(self, docker_compose):
        """Vérifier que l'authentification est requise"""
        response = requests.post(
            f"{docker_compose}/v1/chat/completions",
            json={"model": "cursor-agent", "messages": [{"role": "user", "content": "Test"}]}
        )
        
        assert response.status_code == 401
        print(f"\n✅ Authentification requise (HTTP {response.status_code})")
    
    def test_invalid_api_key(self, docker_compose):
        """Vérifier que les mauvaises clés sont rejetées"""
        response = requests.post(
            f"{docker_compose}/v1/chat/completions",
            headers={"Authorization": "Bearer invalid-key"},
            json={"model": "cursor-agent", "messages": [{"role": "user", "content": "Test"}]}
        )
        
        assert response.status_code == 403
        print(f"\n✅ Mauvaise clé rejetée (HTTP {response.status_code})")


class TestDockerModels:
    """Tests de l'endpoint /v1/models sur serveur Docker"""
    
    def test_list_models(self, client):
        """Vérifier que l'endpoint /v1/models fonctionne"""
        models = client.models.list()
        
        assert hasattr(models, 'data')
        assert len(models.data) > 0
        
        model_ids = [model.id for model in models.data]
        assert "cursor-agent" in model_ids
        
        print(f"\n✅ Modèles disponibles: {model_ids}")


class TestDockerChatCompletions:
    """Tests de chat completions sur serveur Docker"""
    
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
    
    def test_cursor_agent_installed(self, docker_compose):
        """Vérifier que cursor-agent est installé dans le conteneur"""
        project_name = "cursor-openai-proxy-test"
        result = subprocess.run(
            ["docker-compose", "-f", "docker-compose.test.yml", "-p", project_name, "exec", "-T", "api", "cursor-agent", "--version"],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        # cursor-agent devrait retourner quelque chose (même si c'est une erreur, il existe)
        assert result.returncode in [0, 1]  # 0 = OK, 1 = erreur mais installé
        print(f"\n✅ cursor-agent installé dans Docker")
    
    def test_environment_variables(self, docker_compose):
        """Vérifier que les variables d'environnement sont correctement passées"""
        project_name = "cursor-openai-proxy-test"
        result = subprocess.run(
            ["docker-compose", "-f", "docker-compose.test.yml", "-p", project_name, "exec", "-T", "api", "env"],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        assert "CURSOR_API_KEY" in result.stdout
        assert "API_KEY" in result.stdout
        print(f"\n✅ Variables d'environnement correctement passées")


class TestDockerProduction:
    """Tests spécifiques à l'environnement Docker/Production"""
    
    def test_multiple_requests(self, client):
        """Test de requêtes multiples pour vérifier la stabilité"""
        for i in range(3):
            response = client.chat.completions.create(
                model="cursor-agent",
                messages=[
                    {"role": "user", "content": f"Requête numéro {i+1}"}
                ]
            )
            assert isinstance(response, ChatCompletion)
        
        print(f"\n✅ 3 requêtes successives réussies")


if __name__ == "__main__":
    print("🧪 Tests d'intégration DOCKER (avec Docker Compose, port 8002)")
    print("=" * 80)
    print(f"API URL: {API_URL}")
    print(f"API_KEY: {'✅ Configurée' if API_KEY else '❌ Non configurée'}")
    print("=" * 80)
    print("\nPour exécuter les tests:")
    print("  just test-integration-docker")
    print("  ou")
    print("  uv run pytest tests/test_integration_docker.py -v")

