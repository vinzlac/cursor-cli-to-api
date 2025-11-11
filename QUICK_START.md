# Guide de démarrage rapide

Ce guide vous permet de démarrer rapidement avec cursor-openai-proxy.

## 🚀 Démarrage en 5 minutes

### 1. Installation des dépendances

```bash
# Installer uv (si pas déjà fait)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Installer les dépendances du projet
just install
# ou
uv sync
```

### 2. Configuration du fichier .env

**Option A - Configuration interactive (recommandé):**

```bash
just setup-env
```

Le script vous guidera à travers la configuration.

**Option B - Configuration manuelle:**

```bash
# Copier le fichier d'exemple
cp .env.example .env

# éditer le fichier
nano .env
```

**Configuration minimale:**

Pour démarrer rapidement, vous n'avez besoin que de configurer le mode cursor-agent:

```env
# Mode CLI (le plus simple pour commencer)
CURSOR_AGENT_MODE=cli
CURSOR_AGENT_CLI_PATH=cursor-agent
```

Ou si vous avez une API HTTP:

```env
# Mode HTTP
CURSOR_AGENT_MODE=http
CURSOR_AGENT_HTTP_URL=http://localhost:3000/api/chat
```

### 3. Démarrer le serveur

```bash
# Mode développement (avec rechargement automatique)
just dev

# Ou mode production
just run
```

Le serveur sera accessible sur `http://localhost:8000`

### 4. Tester l'API

**Dans un nouveau terminal:**

```bash
# Vérifier la santé
curl http://localhost:8000/health

# Tester un chat completion
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "cursor-agent",
    "messages": [
      {"role": "user", "content": "Bonjour!"}
    ]
  }'
```

### 5. Accéder à la documentation

Ouvrez votre navigateur sur:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

Ou utilisez:
```bash
just docs
```

## 🔧 Exemple avec le client OpenAI Python

### Installation

```bash
uv sync --extra examples
```

### Code d'exemple

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="not-needed"  # Non utilisé mais requis
)

response = client.chat.completions.create(
    model="cursor-agent",
    messages=[
        {"role": "user", "content": "Bonjour!"}
    ]
)

print(response.choices[0].message.content)
```

### Exécuter l'exemple

```bash
just example
# ou
uv run python example_usage.py
```

## ✅ Vérification

Vérifiez que tout fonctionne:

```bash
# Tests unitaires
just test

# Tests d'intégration
just test-integration

# Vérifier la santé
just health
```

## ⚠️ Problèmes courants

### "cursor-agent not found"

**Solution:** Vérifiez que cursor-agent est dans votre PATH ou configurez `CURSOR_AGENT_CLI_PATH` dans `.env`:

```env
CURSOR_AGENT_CLI_PATH=/chemin/vers/cursor-agent
```

### "Connection refused" (mode HTTP)

**Solution:** Vérifiez que l'URL dans `CURSOR_AGENT_HTTP_URL` est correcte et que le service cursor-agent est démarré.

### Port déjà utilisé

**Solution:** Changez le port dans `.env`:

```env
PORT=8001
```

## 📚 Prochaines étapes

- Voir [CONFIGURATION.md](CONFIGURATION.md) pour la configuration détaillée
- Voir [INTEGRATION.md](INTEGRATION.md) pour adapter l'intégration avec cursor-agent
- Voir [DEPLOYMENT.md](DEPLOYMENT.md) pour le déploiement en production
- Voir [NEXT_STEPS.md](NEXT_STEPS.md) pour les améliorations possibles

## 💡 Astuces

- Utilisez `just` pour toutes les commandes courantes (tapez `just` pour voir la liste)
- Activez `RELOAD=true` en développement pour le rechargement automatique
- Utilisez `LOG_LEVEL=DEBUG` pour voir plus de détails dans les logs
- En production, configurez `API_KEY` pour l'authentification
