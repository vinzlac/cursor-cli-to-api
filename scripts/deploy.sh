#!/bin/bash
# Script de d?ploiement basique

set -e

ENV="${1:-production}"
DOCKER_BUILD="${DOCKER_BUILD:-true}"

echo "?? D?ploiement de cursor-cli-to-api"
echo "Environnement: $ENV"
echo ""

# V?rifier que .env existe
if [ ! -f .env ]; then
    echo "??  Fichier .env non trouv?. Copiez .env.example vers .env et configurez-le."
    exit 1
fi

# Build Docker si demand?
if [ "$DOCKER_BUILD" = "true" ]; then
    echo "?? Construction de l'image Docker..."
    docker build -t cursor-cli-to-api:latest .
    echo "? Image Docker construite"
fi

# Arr?ter les conteneurs existants
echo "?? Arr?t des conteneurs existants..."
docker-compose down || true

# D?marrer les nouveaux conteneurs
echo "??  D?marrage des conteneurs..."
docker-compose up -d

# Attendre que le service soit pr?t
echo "? Attente du d?marrage du service..."
sleep 5

# V?rifier la sant?
echo "?? V?rification de la sant? du service..."
if curl -f http://localhost:8000/health > /dev/null 2>&1; then
    echo "? Service d?marr? avec succ?s!"
else
    echo "? Le service ne r?pond pas correctement"
    docker-compose logs
    exit 1
fi

echo ""
echo "? D?ploiement termin?!"
echo "API disponible sur: http://localhost:8000"
echo "Documentation: http://localhost:8000/docs"
