#!/bin/bash
# Script de déploiement basique

set -e

ENV="${1:-production}"
DOCKER_BUILD="${DOCKER_BUILD:-true}"

echo "🚀 Déploiement de cursor-openai-proxy"
echo "Environnement: $ENV"
echo ""

# Vérifier que .env existe
if [ ! -f .env ]; then
    echo "⚠️  Fichier .env non trouvé. Copiez .env.example vers .env et configurez-le."
    exit 1
fi

# Build Docker si demandé
if [ "$DOCKER_BUILD" = "true" ]; then
    echo "🔨 Construction de l'image Docker..."
    docker build -t cursor-openai-proxy:latest .
    echo "✅ Image Docker construite"
fi

# Arrêter les conteneurs existants
echo "🛑 Arrêt des conteneurs existants..."
docker-compose down || true

# Démarrer les nouveaux conteneurs
echo "🚀  Démarrage des conteneurs..."
docker-compose up -d

# Attendre que le service soit prêt
echo "⏳ Attente du démarrage du service..."
sleep 5

# Vérifier la santé
echo "🔍 Vérification de la santé du service..."
if curl -f http://localhost:8000/health > /dev/null 2>&1; then
    echo "✅ Service démarré avec succès!"
else
    echo "❌ Le service ne répond pas correctement"
    docker-compose logs
    exit 1
fi

echo ""
echo "✅ Déploiement terminé!"
echo "API disponible sur: http://localhost:8000"
echo "Documentation: http://localhost:8000/docs"
