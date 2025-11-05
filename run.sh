#!/bin/bash
# Script de démarrage avec uv et just

set -e

echo "🚀 Démarrage du proxy cursor-agent..."

# Vérifier si uv est installé
if ! command -v uv &> /dev/null; then
    echo "❌ uv n'est pas installé. Installez-le avec:"
    echo "   curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# Vérifier si just est installé
if ! command -v just &> /dev/null; then
    echo "⚠️  just n'est pas installé. Utilisation directe de uv..."
    # Synchroniser les dépendances (crée le venv si nécessaire)
    echo "📦 Installation des dépendances..."
    uv sync
    # Démarrer le serveur
    echo "🚀 Démarrage du serveur sur http://localhost:8001"
    uv run uvicorn main:app --host 0.0.0.0 --port 8001 --reload
else
    # Utiliser just si disponible
    echo "📦 Installation des dépendances..."
    just install
    echo "🚀 Démarrage du serveur sur http://localhost:8001"
    just dev
fi
