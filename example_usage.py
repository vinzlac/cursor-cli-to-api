"""
Exemple d'utilisation du proxy cursor-agent avec le client OpenAI

Pour installer les dépendances:
    uv pip install openai

Pour exécuter:
    uv run python example_usage.py
"""
from openai import OpenAI
import os

# Configuration du client pour pointer vers votre proxy local
client = OpenAI(
    base_url="http://localhost:8001/v1",  # URL de votre proxy
    api_key="not-needed"  # Clé non utilisée mais requise par la bibliothèque
)


def example_basic_chat():
    """Exemple basique de chat"""
    print("=== Exemple 1: Chat basique ===\n")
    
    response = client.chat.completions.create(
        model="cursor-agent",
        messages=[
            {"role": "system", "content": "Tu es un assistant Python expert."},
            {"role": "user", "content": "Explique-moi ce qu'est FastAPI en 2 phrases."}
        ],
        temperature=0.7,
        max_tokens=200
    )
    
    print(f"Réponse: {response.choices[0].message.content}\n")
    print(f"Tokens utilisés: {response.usage.total_tokens}\n")


def example_streaming():
    """Exemple avec streaming"""
    print("=== Exemple 2: Chat avec streaming ===\n")
    
    stream = client.chat.completions.create(
        model="cursor-agent",
        messages=[
            {"role": "user", "content": "Raconte-moi une courte histoire sur Python."}
        ],
        stream=True
    )
    
    print("Réponse (streaming): ", end="", flush=True)
    for chunk in stream:
        if chunk.choices[0].delta.content is not None:
            print(chunk.choices[0].delta.content, end="", flush=True)
    print("\n")


def example_multiple_turns():
    """Exemple de conversation multi-tours"""
    print("=== Exemple 3: Conversation multi-tours ===\n")
    
    messages = [
        {"role": "system", "content": "Tu es un assistant de code."},
        {"role": "user", "content": "Comment créer une fonction Python?"}
    ]
    
    # Premier tour
    response1 = client.chat.completions.create(
        model="cursor-agent",
        messages=messages
    )
    print(f"User: {messages[-1]['content']}")
    print(f"Assistant: {response1.choices[0].message.content}\n")
    
    # Ajouter la réponse à l'historique
    messages.append({
        "role": "assistant",
        "content": response1.choices[0].message.content
    })
    
    # Deuxième tour
    messages.append({"role": "user", "content": "Peux-tu donner un exemple?"})
    response2 = client.chat.completions.create(
        model="cursor-agent",
        messages=messages
    )
    print(f"User: {messages[-1]['content']}")
    print(f"Assistant: {response2.choices[0].message.content}\n")


def example_list_models():
    """Exemple pour lister les modèles disponibles"""
    print("=== Exemple 4: Liste des modèles ===\n")
    
    models = client.models.list()
    print("Modèles disponibles:")
    for model in models.data:
        print(f"  - {model.id} (créé: {model.created})")


if __name__ == "__main__":
    print("📘 Exemples d'utilisation du proxy cursor-agent\n")
    print("Assurez-vous que le serveur est démarré sur http://localhost:8001\n")
    
    try:
        # Décommenter les exemples que vous voulez tester
        example_basic_chat()
        # example_streaming()
        # example_multiple_turns()
        example_list_models()
        
        print("\n✅ Exemples terminés avec succès!")
        
    except Exception as e:
        print(f"❌ Erreur: {e}")
        print("\nVérifiez que:")
        print("1. Le serveur proxy est démarré (python main.py)")
        print("2. cursor-agent est correctement configuré dans main.py")
