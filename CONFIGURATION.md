# Guide de configuration du fichier .env

Ce guide explique comment configurer le fichier `.env` pour votre environnement.

## ?? ?tapes de configuration

### 1. Cr?er le fichier .env

```bash
# Copier le fichier d'exemple
cp .env.example .env

# Ou cr?er manuellement
touch .env
```

### 2. ?diter le fichier .env

Ouvrez `.env` avec votre ?diteur pr?f?r? et configurez les variables selon vos besoins.

## ?? Variables de configuration

### Variables de serveur

```env
# Adresse d'?coute du serveur (0.0.0.0 pour toutes les interfaces)
HOST=0.0.0.0

# Port d'?coute
PORT=8000

# Mode rechargement automatique (true pour d?veloppement, false pour production)
RELOAD=false
```

### Variables d'int?gration cursor-agent

**Mode CLI (recommand? pour commencer):**

```env
# Mode d'int?gration: "cli", "http", ou "library"
CURSOR_AGENT_MODE=cli

# Chemin vers l'ex?cutable cursor-agent (optionnel, utilise "cursor-agent" par d?faut)
CURSOR_AGENT_CLI_PATH=cursor-agent

# Timeout en secondes pour les appels ? cursor-agent
CURSOR_AGENT_TIMEOUT=60
```

**Mode HTTP:**

```env
CURSOR_AGENT_MODE=http

# URL compl?te de l'API HTTP cursor-agent
CURSOR_AGENT_HTTP_URL=http://localhost:3000/api/chat

CURSOR_AGENT_TIMEOUT=60
```

**Mode Library:**

```env
CURSOR_AGENT_MODE=library

CURSOR_AGENT_TIMEOUT=60
```

### Variables de s?curit?

```env
# Cl? API pour l'authentification (optionnel mais recommand? en production)
# Si d?fini, toutes les requ?tes devront inclure: Authorization: Bearer <API_KEY>
API_KEY=

# Exemple avec une cl?:
# API_KEY=sk-1234567890abcdefghijklmnopqrstuvwxyz
```

### Variables de logging

```env
# Niveau de log: DEBUG, INFO, WARNING, ERROR, CRITICAL
LOG_LEVEL=INFO
```

### Variables de l'API (optionnel - pour personnaliser)

```env
# Titre de l'API (affich? dans la documentation)
API_TITLE=Cursor Agent API Proxy

# Version de l'API
API_VERSION=1.0.0

# Description de l'API
API_DESCRIPTION=Proxy FastAPI pour cursor-agent compatible avec l'API OpenAI
```

## ?? Exemples de configuration compl?te

### Exemple 1: D?veloppement local avec CLI

```env
# Serveur
HOST=0.0.0.0
PORT=8000
RELOAD=true

# Cursor Agent - Mode CLI
CURSOR_AGENT_MODE=cli
CURSOR_AGENT_CLI_PATH=cursor-agent
CURSOR_AGENT_TIMEOUT=60

# S?curit? (d?sactiv?e en d?veloppement)
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

# S?curit?
API_KEY=sk-prod-1234567890abcdefghijklmnopqrstuvwxyz

# Logging
LOG_LEVEL=INFO
```

### Exemple 3: CLI avec chemin personnalis?

```env
# Serveur
HOST=0.0.0.0
PORT=8000
RELOAD=false

# Cursor Agent - Mode CLI avec chemin complet
CURSOR_AGENT_MODE=cli
CURSOR_AGENT_CLI_PATH=/usr/local/bin/cursor-agent
CURSOR_AGENT_TIMEOUT=90

# S?curit?
API_KEY=sk-your-secret-key-here

# Logging
LOG_LEVEL=WARNING
```

## ?? G?n?ration d'une cl? API s?curis?e

Pour g?n?rer une cl? API s?curis?e:

```bash
# Avec Python
python -c "import secrets; print('sk-' + secrets.token_urlsafe(32))"

# Avec OpenSSL
openssl rand -hex 32 | sed 's/^/sk-/'

# Avec uuidgen (macOS/Linux)
echo "sk-$(uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]')"
```

## ? V?rification de la configuration

Apr?s avoir configur? `.env`, v?rifiez que tout fonctionne:

```bash
# V?rifier que le fichier existe
ls -la .env

# Tester le chargement de la configuration
just info

# D?marrer le serveur en mode d?veloppement
just dev

# Dans un autre terminal, tester
curl http://localhost:8000/health
```

## ?? D?pannage

### Le fichier .env n'est pas lu

1. V?rifiez que le fichier s'appelle exactement `.env` (avec le point au d?but)
2. V?rifiez qu'il est dans le r?pertoire racine du projet
3. V?rifiez qu'il n'y a pas d'espaces autour du `=` dans les variables
4. Red?marrez le serveur apr?s modification

### Variables non prises en compte

- Les variables doivent ?tre en MAJUSCULES
- Pas d'espaces autour du `=`
- Utilisez des guillemets si la valeur contient des espaces:
  ```env
  API_KEY="sk-1234567890"
  ```

### Erreur de syntaxe

Le fichier `.env` utilise un format simple `KEY=VALUE`. ?vitez:
- Les commentaires inline (utilisez des lignes s?par?es avec `#`)
- Les caract?res sp?ciaux non ?chapp?s
- Les lignes vides au milieu (sauf pour la lisibilit?)

## ?? R?f?rences

- Voir `INTEGRATION.md` pour les d?tails sur l'int?gration avec cursor-agent
- Voir `DEPLOYMENT.md` pour la configuration en production
- Voir `config.py` pour la liste compl?te des variables disponibles
