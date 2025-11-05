# Cursor Agent API Proxy

Proxy FastAPI pour cursor-agent compatible avec l'API OpenAI/ChatGPT.

## 🎯 Objectif

Ce projet permet d'exposer cursor-agent via une API REST compatible avec l'API OpenAI, permettant ainsi d'utiliser cursor-agent avec n'importe quel client compatible OpenAI (comme les bibliothèques `openai` en Python, JavaScript, etc.).

## 📋 Prérequis

- Python 3.8+
- [uv](https://github.com/astral-sh/uv) (gestionnaire de paquets moderne)
- [just](https://github.com/casey/just) (command runner moderne)
- cursor-agent installé et accessible

### Installer uv

```bash
# Sur macOS/Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# Ou avec Homebrew
brew install uv

# Ou avec pip
pip install uv
```

### Installer just

```bash
# Sur macOS/Linux
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s '--to ~/.local/bin'

# Ou avec Homebrew
brew install just

# Ou avec cargo
cargo install just
```

## 🚀 Installation

**Méthode recommandée (avec uv sync):**

```bash
# Crée automatiquement le venv et installe toutes les dépendances
uv sync
# ou
just install
```

**Méthode alternative:**

```bash
# Créer l'environnement virtuel
uv venv

# Activer l'environnement virtuel
source .venv/bin/activate  # Sur macOS/Linux
# ou
.venv\Scripts\activate  # Sur Windows

# Installer les dépendances
uv pip install -e .
```

## 💻 Utilisation

### Démarrer le serveur

**Avec just (recommandé pour les commandes):**

```bash
just dev   # Mode développement avec reload
just run    # Mode production
just        # Voir toutes les commandes disponibles
```

**Avec uv (recommandé - pas besoin d'activer le venv):**

```bash
uv run python main.py
```

**Ou avec le script de démarrage:**

```bash
./run.sh
```

**Ou avec Docker:**

```bash
just docker-build
just docker-up
# ou
docker-compose up -d
```

**Ou directement avec Python après activation du venv:**

```bash
source .venv/bin/activate
python main.py
```

**Ou avec uvicorn directement:**

```bash
uv run uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Le serveur sera accessible sur `http://localhost:8000`

### Documentation API

Une fois le serveur démarré, accédez à:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

Ou utilisez:
```bash
just docs  # Ouvre automatiquement la documentation dans le navigateur
```

## 📡 API Endpoints

### POST `/v1/chat/completions`

Endpoint principal compatible avec l'API OpenAI.

**Requête:**
```json
{
  "model": "cursor-agent",
  "messages": [
    {"role": "system", "content": "Tu es un assistant utile."},
    {"role": "user", "content": "Bonjour, comment ça va?"}
  ],
  "temperature": 0.7,
  "max_tokens": 1000
}
```

**Réponse:**
```json
{
  "id": "chatcmpl-abc123",
  "object": "chat.completion",
  "created": 1234567890,
  "model": "cursor-agent",
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Réponse de cursor-agent..."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 10,
    "completion_tokens": 20,
    "total_tokens": 30
  }
}
```

### POST `/v1/chat/completions-stream`

Endpoint pour le streaming (Server-Sent Events).

### GET `/v1/models`

Liste les modèles disponibles.

### GET `/health`

Vérification de santé du service.

## ⚙️ Configuration

### Configuration du fichier .env

**Méthode rapide (interactive):**

```bash
just setup-env
# ou
./scripts/setup-env.sh
```

**Méthode manuelle:**

```bash
# Copier le fichier d'exemple
cp .env.example .env

# Éditer avec votre éditeur préféré
nano .env
# ou
code .env
```

**Variables essentielles à configurer:**

1. **Mode cursor-agent** (`CURSOR_AGENT_MODE`):
   - `cli` : Utilise cursor-agent en ligne de commande
   - `http` : Appelle une API HTTP cursor-agent
   - `library` : Utilise cursor-agent comme bibliothèque Python

2. **Selon le mode choisi:**
   - **CLI**: `CURSOR_AGENT_CLI_PATH` (chemin vers l'exécutable)
   - **HTTP**: `CURSOR_AGENT_HTTP_URL` (URL de l'API)

3. **Sécurité (production):**
   - `API_KEY` : Clé API pour protéger VOTRE API proxy (générée par vous, pas liée à cursor-agent)
   
   ⚠️ **Important:** `API_KEY` protège votre API proxy, pas cursor-agent. Si cursor-agent nécessite une authentification, voir `SECURITY.md`.

Voir [CONFIGURATION.md](CONFIGURATION.md) pour le guide complet de configuration et [INTEGRATION.md](INTEGRATION.md) pour les détails sur l'intégration avec cursor-agent.

### Adapter l'appel à cursor-agent

Dans le fichier `main.py`, les fonctions d'intégration peuvent être adaptées:
- `_call_cursor_agent_cli()` - pour le mode CLI
- `_call_cursor_agent_http()` - pour le mode HTTP  
- `_call_cursor_agent_library()` - pour le mode Library

Voir `INTEGRATION.md` pour les détails.

## 🔧 Exemple d'utilisation avec le client OpenAI Python

Installer le client OpenAI pour les exemples:

```bash
uv sync --extra examples
# ou
uv pip install openai
```

Puis utiliser:

```python
from openai import OpenAI

# Configurer le client pour pointer vers votre proxy
client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="not-needed"  # Non utilisé mais requis par la lib
)

# Utiliser comme avec OpenAI
response = client.chat.completions.create(
    model="cursor-agent",
    messages=[
        {"role": "user", "content": "Bonjour!"}
    ]
)

print(response.choices[0].message.content)
```

Exécuter l'exemple:

```bash
just example
# ou
uv run python example_usage.py
```

## 🔒 Sécurité

Pour la production, ajoutez:
- Authentification (API keys) - configuré via `API_KEY` dans `.env`
- Rate limiting - middleware disponible (décommenter dans `main.py`)
- Validation supplémentaire des entrées
- Logging et monitoring
- HTTPS/TLS

Voir `DEPLOYMENT.md` pour les détails sur le déploiement sécurisé.

## 📝 Notes

- Le comptage de tokens est approximatif (1 token ≈ 4 caractères)
- Pour un comptage précis, intégrez `tiktoken` ou une bibliothèque similaire
- Le streaming est simulé - adaptez selon les capacités réelles de cursor-agent

## 🛠️ Commandes utiles (avec just)

```bash
# Voir toutes les commandes disponibles
just

# Installation et développement
just install          # Installer les dépendances
just dev              # Mode développement avec reload
just run              # Mode production

# Tests
just test             # Lancer les tests
just test-cov         # Tests avec couverture
just test-integration # Tests d'intégration complets

# Qualité de code
just format           # Formater le code
just lint             # Vérifier le code
just check            # Format + lint

# Docker
just docker-build     # Construire l'image Docker
just docker-up        # Démarrer avec Docker Compose
just docker-down      # Arrêter Docker Compose
just docker-logs      # Voir les logs

# Utilitaires
just clean            # Nettoyer les fichiers générés
just info             # Informations sur l'environnement
just example          # Exécuter l'exemple
just health           # Vérifier la santé du serveur
just docs             # Ouvrir la documentation
```

## 📚 Documentation complémentaire

- [Guide de démarrage rapide](QUICK_START.md) - Démarrage en 5 minutes
- [Guide de configuration](CONFIGURATION.md) - Configuration détaillée du .env
- [Guide d'intégration](INTEGRATION.md) - Comment intégrer avec cursor-agent
- [Guide de sécurité](SECURITY.md) - Authentification et sécurité
- [Guide de déploiement](DEPLOYMENT.md) - Déploiement en production
- [Prochaines étapes](NEXT_STEPS.md) - Checklist et améliorations

## 🤝 Contribution

Les contributions sont les bienvenues! N'hésitez pas à ouvrir une issue ou une pull request.

## 📄 Licence

MIT
