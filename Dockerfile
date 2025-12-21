# Dockerfile pour cursor-openai-proxy
FROM python:3.11-slim

# Installer les dépendances système (curl, ca-certificates pour cursor-agent)
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Installer cursor-agent (CLI officiel de Cursor)
# Note: cursor-agent inclut Node.js et tous les dépendances nécessaires
RUN curl -fsSL https://cursor.com/install | bash || (echo "Erreur lors de l'installation de cursor-agent" && exit 1)

# Ajouter cursor-agent au PATH
ENV PATH="/root/.local/bin:${PATH}"

# Vérifier que cursor-agent est bien installé et accessible
RUN cursor-agent --version || (echo "ERREUR: cursor-agent n'est pas accessible après installation" && exit 1)

# Vérifier que cursor-agent peut être exécuté
RUN cursor-agent --help > /dev/null 2>&1 || (echo "ERREUR: cursor-agent ne peut pas être exécuté" && exit 1)

# Installer uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Définir le répertoire de travail
WORKDIR /app

# Copier les fichiers de configuration
COPY pyproject.toml ./
COPY .python-version ./
COPY README.md ./

# Copier uv.lock s'il existe (recommandé pour la reproductibilité)
# Note: Le fichier doit être commité dans git pour être disponible lors du build
COPY uv.lock ./

# Installer les dépendances avec uv
# --frozen garantit l'utilisation exacte des versions spécifiées dans uv.lock
RUN uv sync --frozen --no-dev

# Copier le code source
COPY . .

# Exposer le port
EXPOSE 8001

# Variables d'environnement pour le mode production
ENV PYTHONUNBUFFERED=1
ENV RELOAD=false

# Note: CURSOR_API_KEY doit être fourni via docker-compose.yml ou --env-file
# Ne jamais coder en dur des clés API dans le Dockerfile !

# Commande par défaut
CMD ["uv", "run", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]
