# Dockerfile pour cursor-cli-to-api
FROM python:3.11-slim

# Installer uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# D?finir le r?pertoire de travail
WORKDIR /app

# Copier les fichiers de configuration
COPY pyproject.toml ./
COPY .python-version ./

# Installer les d?pendances avec uv
RUN uv sync --frozen --no-dev

# Copier le code source
COPY . .

# Exposer le port
EXPOSE 8000

# Variable d'environnement pour le mode production
ENV PYTHONUNBUFFERED=1
ENV RELOAD=false

# Commande par d?faut
CMD ["uv", "run", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
