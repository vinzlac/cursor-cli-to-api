#!/usr/bin/env bash
# Script pour construire l'image Docker avec un tag basé sur la version de cursor-agent et le hash git

set -e

IMAGE_NAME="cursor-openai-proxy"
BASE_TAG="latest"

echo "🐳 Construction de l'image Docker avec tag personnalisé..."
echo ""

# Vérifier que git est disponible
if ! command -v git &> /dev/null; then
    echo "❌ Erreur: git n'est pas installé"
    exit 1
fi

# Récupérer le hash git (7 premiers caractères)
GIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
if [ "$GIT_HASH" = "unknown" ]; then
    echo "⚠️  Avertissement: Impossible de récupérer le hash git, utilisation de 'unknown'"
fi

echo "📦 Hash git: $GIT_HASH"

# Construire l'image avec le tag de base
# ⚠️ IMPORTANT: Ne pas passer de variables d'environnement sensibles au build
# Les variables d'environnement doivent être passées au runtime (docker run, docker-compose)
# 
# NOTE: Docker Desktop sur Mac peut automatiquement passer les variables d'environnement
# du système au build. Si vous voyez des variables sensibles dans l'image (docker inspect),
# reconstruisez l'image depuis un terminal propre ou utilisez docker-compose qui gère
# correctement les variables d'environnement au runtime.
echo ""
echo "🔨 Construction de l'image Docker..."
echo "   ⚠️  SÉCURITÉ: Les variables d'environnement sensibles ne doivent PAS être dans l'image"
echo "   Elles doivent être passées au runtime via --env-file ou docker-compose"
docker build -t "${IMAGE_NAME}:${BASE_TAG}" .

# Extraire la version de cursor-agent depuis l'image construite
echo ""
echo "🔍 Extraction de la version de cursor-agent..."
CURSOR_VERSION=$(docker run --rm "${IMAGE_NAME}:${BASE_TAG}" cursor-agent --version 2>/dev/null | head -n 1 | tr -d '\r\n' || echo "unknown")

if [ "$CURSOR_VERSION" = "unknown" ] || [ -z "$CURSOR_VERSION" ]; then
    echo "⚠️  Avertissement: Impossible d'extraire la version de cursor-agent"
    echo "   Utilisation de 'unknown' comme version"
    CURSOR_VERSION="unknown"
else
    # Nettoyer la version (enlever les espaces et caractères spéciaux, garder seulement alphanumériques, points et tirets)
    CURSOR_VERSION=$(echo "$CURSOR_VERSION" | tr -d '[:space:]' | sed 's/[^a-zA-Z0-9.-]//g')
fi

echo "📌 Version cursor-agent: $CURSOR_VERSION"

# Créer le tag final: version-cursor-agent-hash-git
FINAL_TAG="${CURSOR_VERSION}-${GIT_HASH}"

echo ""
echo "🏷️  Création du tag: ${IMAGE_NAME}:${FINAL_TAG}"
docker tag "${IMAGE_NAME}:${BASE_TAG}" "${IMAGE_NAME}:${FINAL_TAG}"

echo ""
echo "✅ Image Docker construite et taggée avec succès!"
echo ""
echo "📋 Tags disponibles:"
echo "   - ${IMAGE_NAME}:${BASE_TAG}"
echo "   - ${IMAGE_NAME}:${FINAL_TAG}"
echo ""
echo "💡 Pour utiliser l'image taggée:"
echo "   docker run -p 8001:8001 --env-file .env ${IMAGE_NAME}:${FINAL_TAG}"

