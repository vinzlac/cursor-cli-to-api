"""
Tests d'intégration avec le client OpenAI Python

Ces tests vérifient que l'API fonctionne correctement avec le client officiel OpenAI.
Ils nécessitent que l'API soit démarrée (Docker ou local).

Pour exécuter:
    uv run pytest tests/test_integration_openai.py -v
    
Pour exécuter avec Docker:
    docker-compose up -d
    uv run pytest tests/test_integration_openai.py -v
"""
import pytest
import os
from openai import OpenAI
from openai.types.chat import ChatCompletion, ChatCompletionChunk


# Configuration
API_URL = os.getenv("API_URL", "http://localhost:8001")
API_KEY = os.getenv("API_KEY", "")

# Skip tous les tests si pas d'API_KEY (pour CI/CD)
pytestmark = pytest.mark.skipif(
    not API_KEY,
    reason="API_KEY non configurée. Chargez .env ou définissez API_KEY."
)


@pytest.fixture(scope="module")
def client():
    """Client OpenAI configuré pour le proxy local"""
    return OpenAI(
        base_url=f"{API_URL}/v1",
        api_key=API_KEY
    )


@pytest.fixture(scope="module")
def client_without_auth():
    """Client OpenAI sans authentification (pour tester le rejet)"""
    return OpenAI(
        base_url=f"{API_URL}/v1",
        api_key="invalid-key"
    )


class TestAuthentication:
    """Tests d'authentification"""
    
    def test_invalid_api_key(self, client_without_auth):
        """Vérifier que les requêtes sans API_KEY valide sont rejetées"""
        with pytest.raises(Exception) as exc_info:
            client_without_auth.chat.completions.create(
                model="cursor-agent",
                messages=[{"role": "user", "content": "Test"}]
            )
        # L'erreur peut être 401 ou 403
        assert "401" in str(exc_info.value) or "403" in str(exc_info.value)


class TestModels:
    """Tests de l'endpoint /v1/models"""
    
    def test_list_models(self, client):
        """Vérifier que l'endpoint /v1/models retourne la liste des modèles"""
        models = client.models.list()
        
        # Vérifier la structure
        assert hasattr(models, 'data')
        assert len(models.data) > 0
        
        # Vérifier que les modèles principaux sont présents
        model_ids = [model.id for model in models.data]
        assert "auto" in model_ids  # Modèle par défaut
        assert "gpt-5" in model_ids
        assert "sonnet-4.5" in model_ids
        assert "gpt-4o" in model_ids  # Alias OpenAI
        
        # Vérifier les attributs de chaque modèle
        for model in models.data:
            assert hasattr(model, 'id')
            assert hasattr(model, 'created')
            assert hasattr(model, 'object')
            assert model.object == "model"


class TestChatCompletions:
    """Tests de l'endpoint /v1/chat/completions"""
    
    def test_basic_chat_completion(self, client):
        """Test d'une completion basique"""
        response = client.chat.completions.create(
            model="cursor-agent",
            messages=[
                {"role": "user", "content": "Dis bonjour en un mot"}
            ]
        )
        
        # Vérifier le type
        assert isinstance(response, ChatCompletion)
        
        # Vérifier la structure de base
        assert hasattr(response, 'id')
        assert hasattr(response, 'object')
        assert response.object == "chat.completion"
        assert hasattr(response, 'created')
        assert hasattr(response, 'model')
        assert response.model == "cursor-agent"
        
        # Vérifier les choices
        assert hasattr(response, 'choices')
        assert len(response.choices) > 0
        
        choice = response.choices[0]
        assert hasattr(choice, 'message')
        assert hasattr(choice.message, 'role')
        assert choice.message.role == "assistant"
        assert hasattr(choice.message, 'content')
        assert len(choice.message.content) > 0
        
        # Vérifier l'usage
        assert hasattr(response, 'usage')
        assert hasattr(response.usage, 'prompt_tokens')
        assert hasattr(response.usage, 'completion_tokens')
        assert hasattr(response.usage, 'total_tokens')
        assert response.usage.total_tokens > 0
        
        print(f"\n✅ Réponse: {choice.message.content}")
        print(f"✅ Tokens: {response.usage.total_tokens}")
    
    def test_chat_with_system_message(self, client):
        """Test avec un message system"""
        response = client.chat.completions.create(
            model="cursor-agent",
            messages=[
                {"role": "system", "content": "Tu es un assistant Python expert."},
                {"role": "user", "content": "Quel est le mot-clé pour définir une fonction?"}
            ]
        )
        
        assert isinstance(response, ChatCompletion)
        assert len(response.choices) > 0
        assert "def" in response.choices[0].message.content.lower()
        
        print(f"\n✅ Réponse avec system: {response.choices[0].message.content[:100]}...")
    
    def test_chat_with_temperature(self, client):
        """Test avec paramètre temperature"""
        response = client.chat.completions.create(
            model="cursor-agent",
            messages=[
                {"role": "user", "content": "Dis un nombre entre 1 et 10"}
            ],
            temperature=0.7
        )
        
        assert isinstance(response, ChatCompletion)
        assert len(response.choices) > 0
        
        print(f"\n✅ Réponse avec temperature: {response.choices[0].message.content}")
    
    def test_chat_with_max_tokens(self, client):
        """Test avec limitation de tokens (cursor-agent peut ignorer ce paramètre)"""
        response = client.chat.completions.create(
            model="cursor-agent",
            messages=[
                {"role": "user", "content": "Explique Python"}
            ],
            max_tokens=50
        )
        
        assert isinstance(response, ChatCompletion)
        assert len(response.choices) > 0
        # Note: cursor-agent peut ignorer max_tokens, on vérifie juste qu'il ne crash pas
        assert response.usage.completion_tokens > 0
        
        print(f"\n✅ Tokens de completion: {response.usage.completion_tokens}")
        print(f"   (Note: cursor-agent peut ignorer max_tokens)")
    
    def test_streaming_chat_completion(self, client):
        """Test du streaming (peut ne pas être supporté par cursor-agent)"""
        try:
            # Tester avec stream=False d'abord pour vérifier que l'API fonctionne
            response = client.chat.completions.create(
                model="cursor-agent",
                messages=[
                    {"role": "user", "content": "Compte de 1 à 3"}
                ],
                stream=False
            )
            
            assert isinstance(response, ChatCompletion)
            assert len(response.choices) > 0
            
            print(f"\n✅ Réponse non-streaming: {response.choices[0].message.content}")
            print(f"   (Note: Le streaming avec stream=True n'est pas encore implémenté)")
            
            # On teste quand même stream=True pour voir le comportement
            # mais on n'échoue pas si ça ne marche pas
            try:
                stream = client.chat.completions.create(
                    model="cursor-agent",
                    messages=[
                        {"role": "user", "content": "Compte de 1 à 3"}
                    ],
                    stream=True
                )
                
                chunks_received = 0
                for chunk in stream:
                    chunks_received += 1
                    if chunks_received > 100:  # Limite de sécurité
                        break
                
                if chunks_received > 0:
                    print(f"   ✅ Streaming fonctionne: {chunks_received} chunks reçus")
                else:
                    print(f"   ⚠️  Streaming retourne 0 chunks (non supporté)")
            except Exception as e:
                print(f"   ⚠️  Streaming non supporté: {str(e)[:100]}")
                
        except Exception as e:
            pytest.fail(f"Test de base échoué: {e}")
    
    def test_multi_turn_conversation(self, client):
        """Test d'une conversation multi-tours"""
        messages = [
            {"role": "system", "content": "Tu es un assistant concis."},
            {"role": "user", "content": "Quel est 2+2?"}
        ]
        
        # Premier tour
        response1 = client.chat.completions.create(
            model="cursor-agent",
            messages=messages
        )
        
        assert isinstance(response1, ChatCompletion)
        content1 = response1.choices[0].message.content
        
        # Ajouter la réponse à l'historique
        messages.append({
            "role": "assistant",
            "content": content1
        })
        
        # Deuxième tour
        messages.append({"role": "user", "content": "Et 3+3?"})
        response2 = client.chat.completions.create(
            model="cursor-agent",
            messages=messages
        )
        
        assert isinstance(response2, ChatCompletion)
        content2 = response2.choices[0].message.content
        
        print(f"\n✅ Tour 1: {content1}")
        print(f"✅ Tour 2: {content2}")
    
    def test_empty_messages(self, client):
        """Vérifier que les messages vides sont rejetés"""
        with pytest.raises(Exception) as exc_info:
            client.chat.completions.create(
                model="cursor-agent",
                messages=[]
            )
        # Peut être 400 ou 422
        assert "400" in str(exc_info.value) or "422" in str(exc_info.value)


class TestErrorHandling:
    """Tests de gestion des erreurs"""
    
    def test_invalid_model(self, client):
        """Vérifier que les modèles invalides sont gérés"""
        # Note: cursor-agent peut accepter n'importe quel nom de modèle
        # Ce test vérifie juste qu'il n'y a pas de crash
        response = client.chat.completions.create(
            model="invalid-model",
            messages=[{"role": "user", "content": "Test"}]
        )
        
        # L'API devrait quand même répondre (cursor-agent ignore le nom du modèle)
        assert isinstance(response, ChatCompletion)


if __name__ == "__main__":
    print("🧪 Tests d'intégration avec client OpenAI Python")
    print("=" * 80)
    print(f"API URL: {API_URL}")
    print(f"API_KEY: {'✅ Configurée' if API_KEY else '❌ Non configurée'}")
    print("=" * 80)
    print("\nPour exécuter les tests:")
    print("  uv run pytest tests/test_integration_openai.py -v")
    print("  ou")
    print("  just test-integration-python")

