#!/usr/bin/env bash

# Script pour mettre à jour CURSOR_API_TOKEN dans .env de manière sécurisée
# Usage: ./scripts/update-cursor-token.sh

set -e

echo "🔑 Configuration de CURSOR_API_TOKEN pour Docker"
echo "================================================"
echo ""
echo "Ce token est nécessaire pour que cursor-agent puisse"
echo "s'authentifier auprès des services Cursor."
echo ""
echo "⚠️  IMPORTANT:"
echo "   - Ce token est DIFFÉRENT de API_KEY (qui protège votre proxy)"
echo "   - Ne partagez JAMAIS ce token publiquement"
echo "   - Ne le commitez JAMAIS dans git"
echo ""

# Vérifier que le fichier .env existe
if [ ! -f .env ]; then
    echo "❌ Erreur: Fichier .env introuvable"
    echo "   Copiez .env.example vers .env d'abord:"
    echo "   cp .env.example .env"
    exit 1
fi

# Vérifier si CURSOR_API_TOKEN existe déjà
if grep -q "^CURSOR_API_TOKEN=" .env; then
    current_token=$(grep "^CURSOR_API_TOKEN=" .env | cut -d= -f2)
    if [ "$current_token" != "VOTRE_TOKEN_CURSOR_ICI" ] && [ -n "$current_token" ]; then
        echo "⚠️  Un token est déjà configuré dans .env"
        echo "   Token actuel: ${current_token:0:20}..."
        echo ""
        read -p "Voulez-vous le remplacer? (o/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[OoYy]$ ]]; then
            echo "❌ Opération annulée"
            exit 0
        fi
    fi
fi

# Demander le nouveau token
echo ""
echo "📝 Entrez votre CURSOR_API_TOKEN:"
echo "   (Disponible dans: Cursor → Settings → API Keys)"
echo ""
read -p "Token: " -r new_token

# Valider le token
if [ -z "$new_token" ]; then
    echo "❌ Erreur: Token vide"
    exit 1
fi

if [ "$new_token" = "VOTRE_TOKEN_CURSOR_ICI" ]; then
    echo "❌ Erreur: Veuillez entrer un vrai token, pas le placeholder"
    exit 1
fi

# Mettre à jour le fichier .env
if grep -q "^CURSOR_API_TOKEN=" .env; then
    # Remplacer la ligne existante (compatible macOS et Linux)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|^CURSOR_API_TOKEN=.*|CURSOR_API_TOKEN=$new_token|" .env
    else
        sed -i "s|^CURSOR_API_TOKEN=.*|CURSOR_API_TOKEN=$new_token|" .env
    fi
    echo "✅ Token mis à jour dans .env"
else
    # Ajouter la ligne
    echo "" >> .env
    echo "CURSOR_API_TOKEN=$new_token" >> .env
    echo "✅ Token ajouté dans .env"
fi

echo ""
echo "🎉 Configuration terminée !"
echo ""
echo "Prochaines étapes:"
echo "  1. Pour tester localement: just dev"
echo "  2. Pour Docker: docker-compose up --build"
echo "  3. Le token sera automatiquement chargé depuis .env"
echo ""
echo "⚠️  Rappel de sécurité:"
echo "   - Ne commitez JAMAIS le fichier .env"
echo "   - .env est déjà dans .gitignore"
echo "   - Vérifiez: git status (ne doit PAS montrer .env)"

