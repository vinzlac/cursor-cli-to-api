# 🐳 Guide d'utilisation Docker

Ce guide explique comment utiliser cursor-openai-proxy avec Docker et Docker Compose.

## 📋 Prérequis

- Docker et Docker Compose installés
- Votre token `CURSOR_API_KEY` (depuis Cursor → Settings → API Keys)

## ℹ️ Note importante sur cursor-agent

**cursor-agent est automatiquement installé dans le conteneur Docker** lors du build. Vous n'avez **pas besoin** de l'installer sur votre machine hôte pour utiliser Docker.

Le `Dockerfile` exécute automatiquement :
```dockerfile
RUN curl -fsSL https://cursor.com/install | bash
```

Cela signifie que :
- ✅ Le conteneur Docker inclut cursor-agent et toutes ses dépendances (Node.js, etc.)
- ✅ Fonctionne de manière autonome, sans dépendances externes
- ✅ Identique à votre environnement local si vous avez installé cursor-agent
- ⚠️ Le premier build peut prendre quelques minutes (téléchargement + installation)

## 🚀 Démarrage rapide

### 1️⃣ Configuration du token

**Option A - Script interactif (recommandé):**
```bash
just update-cursor-token
```

**Option B - Manuel:**
```bash
# Éditer .env et remplacer le placeholder
nano .env

# Remplacer:
# CURSOR_API_KEY=VOTRE_TOKEN_CURSOR_ICI
# Par:
# CURSOR_API_KEY=votre_vraie_clé_cursor
```

### 2️⃣ Lancer avec Docker Compose

```bash
# Build et démarrage
docker-compose up --build

# Ou en arrière-plan
docker-compose up -d --build
```

### 3️⃣ Tester l'API

```bash
# Health check
curl http://localhost:8001/health

# Lister les modèles
curl http://localhost:8001/v1/models

# Chat completion
curl -X POST http://localhost:8001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "cursor-agent",
    "messages": [
      {"role": "user", "content": "Bonjour !"}
    ]
  }'
```

## 🔧 Configuration avancée

### Variables d'environnement Docker

Le fichier `docker-compose.yml` charge automatiquement:

```yaml
environment:
  - CURSOR_AGENT_MODE=${CURSOR_AGENT_MODE:-cli}
  - CURSOR_AGENT_CLI_PATH=${CURSOR_AGENT_CLI_PATH:-cursor-agent}
  - CURSOR_AGENT_HTTP_URL=${CURSOR_AGENT_HTTP_URL:-}
  - CURSOR_AGENT_TIMEOUT=${CURSOR_AGENT_TIMEOUT:-60}
  - CURSOR_API_KEY=${CURSOR_API_KEY}  # ← Token d'authentification
  - LOG_LEVEL=${LOG_LEVEL:-INFO}
  - HOST=0.0.0.0
  - PORT=8001
  - RELOAD=false
```

### Modifier le port

Dans `.env`:
```bash
PORT=9000
```

Dans `docker-compose.yml`:
```yaml
ports:
  - "9000:9000"  # host:container
```

### Mode HTTP au lieu de CLI

Dans `.env`:
```bash
CURSOR_AGENT_MODE=http
CURSOR_AGENT_HTTP_URL=http://localhost:3000/api/chat
CURSOR_API_KEY=votre_token
```

## 📊 Gestion du conteneur

### Commandes Docker Compose

```bash
# Démarrer
docker-compose up -d

# Voir les logs
docker-compose logs -f

# Arrêter
docker-compose down

# Rebuild
docker-compose up --build

# Voir le statut
docker-compose ps

# Redémarrer
docker-compose restart
```

### Commandes just (alias pratiques)

```bash
just docker-build     # Build l'image
just docker-up        # Démarrer
just docker-logs      # Voir les logs
just docker-down      # Arrêter
```

## 🔍 Debugging

### Vérifier que le token est bien passé

```bash
# Entrer dans le conteneur
docker-compose exec api bash

# Vérifier les variables d'environnement
echo $CURSOR_API_KEY

# Tester la config Python
python -c "from config import settings; print(settings.cursor_api_key[:10] + '...')"
```

### Voir les logs détaillés

Dans `.env`:
```bash
LOG_LEVEL=DEBUG
```

Puis rebuild:
```bash
docker-compose up --build
```

## 🛡️ Sécurité

### ⚠️ Points importants

1. **Ne jamais** commiter `.env` dans git (déjà dans `.gitignore`)
2. **Ne jamais** coder le token en dur dans `Dockerfile`
3. Le token est passé via Docker Compose depuis `.env`
4. Vérifier: `git status` ne doit PAS montrer `.env`

### Rotation des tokens

```bash
# 1. Générer un nouveau token dans Cursor
# 2. Mettre à jour .env
just update-cursor-token

# 3. Redémarrer Docker
docker-compose restart
```

## 🔗 Modes d'intégration

### Mode CLI (par défaut)

```bash
CURSOR_AGENT_MODE=cli
CURSOR_AGENT_CLI_PATH=cursor-agent
CURSOR_API_KEY=votre_token
```

Le token est passé comme variable d'environnement au processus CLI.

### Mode HTTP

```bash
CURSOR_AGENT_MODE=http
CURSOR_AGENT_HTTP_URL=http://api.cursor.com/v1/chat
CURSOR_API_KEY=votre_token
```

Le token est passé dans le header `Authorization: Bearer TOKEN`.

### Mode Library

```bash
CURSOR_AGENT_MODE=library
CURSOR_API_KEY=votre_token
```

Le token est disponible dans `settings.cursor_api_key` pour votre code.

## 📦 Build multi-stage (optimisé)

Si vous voulez un build optimisé pour production:

```dockerfile
# Dockerfile.prod
FROM python:3.11-slim as builder
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
WORKDIR /app
COPY pyproject.toml .python-version ./
RUN uv sync --frozen --no-dev

FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /app/.venv /app/.venv
COPY . .
ENV PATH="/app/.venv/bin:$PATH"
EXPOSE 8001
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]
```

Build:
```bash
docker build -f Dockerfile.prod -t cursor-api-prod .
docker run -p 8001:8001 --env-file .env cursor-api-prod
```

## 🌐 Déploiement en production

### Docker avec reverse proxy (Nginx)

```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  api:
    build: .
    restart: always
    environment:
      - CURSOR_AGENT_MODE=cli
      - CURSOR_API_KEY=${CURSOR_API_KEY}
      - LOG_LEVEL=INFO
      - HOST=0.0.0.0
      - PORT=8001
    env_file:
      - .env.prod
    networks:
      - app-network
  
  nginx:
    image: nginx:alpine
    ports:
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - api
    networks:
      - app-network

networks:
  app-network:
    driver: bridge
```

## 📚 Ressources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [FastAPI Docker Deployment](https://fastapi.tiangolo.com/deployment/docker/)
- Guide principal: [README.md](./README.md)
- Configuration: [CONFIGURATION.md](./CONFIGURATION.md)
- Déploiement: [DEPLOYMENT.md](./DEPLOYMENT.md)
- Sécurité: [SECURITY.md](./SECURITY.md)

## 💡 Trucs et astuces

### Utiliser un .env.local pour tester

```bash
# Créer .env.local avec des valeurs de test
cp .env .env.local

# Lancer avec ce fichier
docker-compose --env-file .env.local up
```

### Monitorer les ressources

```bash
# Voir l'utilisation CPU/RAM
docker stats cursor-openai-proxy-api-1

# Limiter les ressources
# Dans docker-compose.yml:
services:
  api:
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
```

### Healthcheck personnalisé

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8001/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

---

**🎉 Votre API est maintenant prête pour Docker avec authentification complète !**

