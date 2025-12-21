# Guide de configuration du fichier .env

Ce guide explique comment configurer le fichier `.env` pour votre environnement.

## 📋 Étapes de configuration

### 1. Créer le fichier .env

```bash
# Copier le fichier d'exemple
cp .env.example .env

# Ou créer manuellement
touch .env
```

### 2. éditer le fichier .env

Ouvrez `.env` avec votre éditeur préféré et configurez les variables selon vos besoins.

## ⚙️ Variables de configuration

### Variables de serveur

```env
# Adresse d'écoute du serveur (0.0.0.0 pour toutes les interfaces)
HOST=0.0.0.0

# Port d'écoute
PORT=8000

# Mode rechargement automatique (true pour développement, false pour production)
RELOAD=false
```

### Variables d'intégration cursor-agent

**Mode CLI (recommandé pour commencer):**

```env
# Mode d'intégration: "cli", "http", ou "library"
CURSOR_AGENT_MODE=cli

# Chemin vers l'exécutable cursor-agent (optionnel, utilise "cursor-agent" par défaut)
CURSOR_AGENT_CLI_PATH=cursor-agent

# Timeout en secondes pour les appels à cursor-agent
CURSOR_AGENT_TIMEOUT=60
```

**Mode HTTP:**

```env
CURSOR_AGENT_MODE=http

# URL complète de l'API HTTP cursor-agent
CURSOR_AGENT_HTTP_URL=http://localhost:3000/api/chat

CURSOR_AGENT_TIMEOUT=60
```

**Mode Library:**

```env
CURSOR_AGENT_MODE=library

CURSOR_AGENT_TIMEOUT=60
```

### Variables de sécurité

```env
# Clé API pour l'authentification (optionnel mais recommandé en production)
# Si défini, toutes les requêtes devront inclure: Authorization: Bearer <API_KEY>
API_KEY=

# Exemple avec une clé:
# API_KEY=sk-1234567890abcdefghijklmnopqrstuvwxyz
```

### Variables de logging

```env
# Niveau de log: DEBUG, INFO, WARNING, ERROR, CRITICAL
LOG_LEVEL=INFO
```

### Variables de l'API (optionnel - pour personnaliser)

```env
# Titre de l'API (affiché dans la documentation)
API_TITLE=Cursor Agent API Proxy

# Version de l'API
API_VERSION=1.0.0

# Description de l'API
API_DESCRIPTION=Proxy FastAPI pour cursor-agent compatible avec l'API OpenAI
```

## 📝 Exemples de configuration complète

### Exemple 1: Développement local avec CLI

```env
# Serveur
HOST=0.0.0.0
PORT=8000
RELOAD=true

# Cursor Agent - Mode CLI
CURSOR_AGENT_MODE=cli
CURSOR_AGENT_CLI_PATH=cursor-agent
CURSOR_AGENT_TIMEOUT=60

# Sécurité (désactivée en développement)
API_KEY=

# Logging
LOG_LEVEL=DEBUG
```

### Exemple 2: Production avec HTTP et authentification

```env
# Serveur
HOST=0.0.0.0
PORT=8000
RELOAD=false

# Cursor Agent - Mode HTTP
CURSOR_AGENT_MODE=http
CURSOR_AGENT_HTTP_URL=https://api.cursor-agent.com/v1/chat
CURSOR_AGENT_TIMEOUT=120

# Sécurité
API_KEY=sk-prod-1234567890abcdefghijklmnopqrstuvwxyz

# Logging
LOG_LEVEL=INFO
```

### Exemple 3: CLI avec chemin personnalisé

```env
# Serveur
HOST=0.0.0.0
PORT=8000
RELOAD=false

# Cursor Agent - Mode CLI avec chemin complet
CURSOR_AGENT_MODE=cli
CURSOR_AGENT_CLI_PATH=/usr/local/bin/cursor-agent
CURSOR_AGENT_TIMEOUT=90

# Sécurité
API_KEY=sk-your-secret-key-here

# Logging
LOG_LEVEL=WARNING
```

## 🔑 Génération d'une clé API sécurisée

Pour générer une clé API sécurisée:

```bash
# Avec Python
python -c "import secrets; print('sk-' + secrets.token_urlsafe(32))"

# Avec OpenSSL
openssl rand -hex 32 | sed 's/^/sk-/'

# Avec uuidgen (macOS/Linux)
echo "sk-$(uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]')"
```

## ✅ Vérification de la configuration

Après avoir configuré `.env`, vérifiez que tout fonctionne:

```bash
# Vérifier que le fichier existe
ls -la .env

# Tester le chargement de la configuration
just info

# Démarrer le serveur en mode développement
just dev

# Dans un autre terminal, tester
curl http://localhost:8000/health
```

## 🔧 Dépannage

### Le fichier .env n'est pas lu

1. Vérifiez que le fichier s'appelle exactement `.env` (avec le point au début)
2. Vérifiez qu'il est dans le répertoire racine du projet
3. Vérifiez qu'il n'y a pas d'espaces autour du `=` dans les variables
4. Redémarrez le serveur après modification

### Variables non prises en compte

- Les variables doivent être en MAJUSCULES
- Pas d'espaces autour du `=`
- Utilisez des guillemets si la valeur contient des espaces:
  ```env
  API_KEY="sk-1234567890"
  ```

### Erreur de syntaxe

Le fichier `.env` utilise un format simple `KEY=VALUE`. Évitez:
- Les commentaires inline (utilisez des lignes séparées avec `#`)
- Les caractères spéciaux non échappés
- Les lignes vides au milieu (sauf pour la lisibilité)

## 📚 Références

- Voir [INTEGRATION.md](INTEGRATION.md) pour les détails sur l'intégration avec cursor-agent
- Voir [DEPLOYMENT.md](DEPLOYMENT.md) pour la configuration en production
- Voir `config.py` pour la liste complète des variables disponibles
