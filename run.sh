#!/bin/bash
# Script de d?marrage avec uv et just

set -e

echo "?? D?marrage du proxy cursor-agent..."

# V?rifier si uv est install?
if ! command -v uv &> /dev/null; then
    echo "? uv n'est pas install?. Installez-le avec:"
    echo "   curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# V?rifier si just est install?
if ! command -v just &> /dev/null; then
    echo "??  just n'est pas install?. Utilisation directe de uv..."
    # Synchroniser les d?pendances (cr?e le venv si n?cessaire)
    echo "?? Installation des d?pendances..."
    uv sync
    # D?marrer le serveur
    echo "?? D?marrage du serveur sur http://localhost:8000"
    uv run uvicorn main:app --host 0.0.0.0 --port 8000 --reload
else
    # Utiliser just si disponible
    echo "?? Installation des d?pendances..."
    just install
    echo "?? D?marrage du serveur sur http://localhost:8000"
    just dev
fi
