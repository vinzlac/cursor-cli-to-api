# Cursor Agent API Proxy

Proxy FastAPI pour cursor-agent compatible avec l'API OpenAI/ChatGPT.

## ?? Objectif

Ce projet permet d'exposer cursor-agent via une API REST compatible avec l'API OpenAI, permettant ainsi d'utiliser cursor-agent avec n'importe quel client compatible OpenAI (comme les bibliothèques `openai` en Python, JavaScript, etc.).

## ?? Pr?requis

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

## ?? Installation

**M?thode recommandée (avec uv sync):**

```bash
# Cr?e automatiquement le venv et installe toutes les dépendances
uv sync
# ou
just install
```

**M?thode alternative:**

```bash
# Cr?er l'environnement virtuel
uv venv

# Activer l'environnement virtuel
source .venv/bin/activate  # Sur macOS/Linux
# ou
.venv\Scripts\activate  # Sur Windows

# Installer les dépendances
uv pip install -e .
```

## ?? Utilisation

### D?marrer le serveur

**Avec just (recommandé pour les commandes):**

```bash
just dev   # Mode d?veloppement avec reload
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

**Ou directement avec Python apr?s activation du venv:**

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

Une fois le serveur démarré, accédez ?:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

Ou utilisez:
```bash
just docs  # Ouvre automatiquement la documentation dans le navigateur
```

## ?? API Endpoints

### POST `/v1/chat/completions`

Endpoint principal compatible avec l'API OpenAI.

**Requ?te:**
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

**R?ponse:**
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
        "content": "R?ponse de cursor-agent..."
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

Liste les mod?les disponibles.

### GET `/health`

V?rification de sant? du service.

## ?? Configuration

### Configuration du fichier .env

**M?thode rapide (interactive):**

```bash
just setup-env
# ou
./scripts/setup-env.sh
```

**M?thode manuelle:**

```bash
# Copier le fichier d'exemple
cp .env.example .env

# éditer avec votre ?diteur préféré
nano .env
# ou
code .env
```

**Variables essentielles ? configurer:**

1. **Mode cursor-agent** (`CURSOR_AGENT_MODE`):
   - `cli` : Utilise cursor-agent en ligne de commande
   - `http` : Appelle une API HTTP cursor-agent
   - `library` : Utilise cursor-agent comme biblioth?que Python

2. **Selon le mode choisi:**
   - **CLI**: `CURSOR_AGENT_CLI_PATH` (chemin vers l'exécutable)
   - **HTTP**: `CURSOR_AGENT_HTTP_URL` (URL de l'API)

3. **S?curit? (production):**
   - `API_KEY` : Cl? API pour prot?ger VOTRE API proxy (générée par vous, pas li?e ? cursor-agent)
   
   ? **Important:** `API_KEY` prot?ge votre API proxy, pas cursor-agent. Si cursor-agent nécessite une authentification, voir `SECURITY.md`.

Voir [CONFIGURATION.md](CONFIGURATION.md) pour le guide complet de configuration et [INTEGRATION.md](INTEGRATION.md) pour les détails sur l'intégration avec cursor-agent.

### Adapter l'appel ? cursor-agent

Dans le fichier `main.py`, les fonctions d'intégration peuvent ?tre adaptées:
- `_call_cursor_agent_cli()` - pour le mode CLI
- `_call_cursor_agent_http()` - pour le mode HTTP  
- `_call_cursor_agent_library()` - pour le mode Library

Voir `INTEGRATION.md` pour les détails.

## ?? Exemple d'utilisation avec le client OpenAI Python

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

Ex?cuter l'exemple:

```bash
just example
# ou
uv run python example_usage.py
```

## ?? S?curit?

Pour la production, ajoutez:
- Authentification (API keys) - configuré via `API_KEY` dans `.env`
- Rate limiting - middleware disponible (d?commenter dans `main.py`)
- Validation suppl?mentaire des entr?es
- Logging et monitoring
- HTTPS/TLS

Voir `DEPLOYMENT.md` pour les détails sur le déploiement s?curis?.

## ?? Notes

- Le comptage de tokens est approximatif (1 token ? 4 caract?res)
- Pour un comptage pr?cis, int?grez `tiktoken` ou une biblioth?que similaire
- Le streaming est simul? - adaptez selon les capacit?s r?elles de cursor-agent

## ??? Commandes utiles (avec just)

```bash
# Voir toutes les commandes disponibles
just

# Installation et d?veloppement
just install          # Installer les dépendances
just dev              # Mode d?veloppement avec reload
just run              # Mode production

# Tests
just test             # Lancer les tests
just test-cov         # Tests avec couverture
just test-integration # Tests d'intégration complets

# Qualit? de code
just format           # Formater le code
just lint             # V?rifier le code
just check            # Format + lint

# Docker
just docker-build     # Construire l'image Docker
just docker-up        # D?marrer avec Docker Compose
just docker-down      # Arr?ter Docker Compose
just docker-logs      # Voir les logs

# Utilitaires
just clean            # Nettoyer les fichiers g?n?r?s
just info             # Informations sur l'environnement
just example          # Ex?cuter l'exemple
just health           # V?rifier la sant? du serveur
just docs             # Ouvrir la documentation
```

## ?? Documentation compl?mentaire

- [Guide de démarrage rapide](QUICK_START.md) - D?marrage en 5 minutes
- [Guide de configuration](CONFIGURATION.md) - Configuration détaillée du .env
- [Guide d'intégration](INTEGRATION.md) - Comment int?grer avec cursor-agent
- [Guide de sécurité](SECURITY.md) - Authentification et sécurité
- [Guide de déploiement](DEPLOYMENT.md) - D?ploiement en production
- [Prochaines étapes](NEXT_STEPS.md) - Checklist et améliorations

## ?? Contribution

Les contributions sont les bienvenues! N'h?sitez pas ? ouvrir une issue ou une pull request.

## ?? Licence

MIT
