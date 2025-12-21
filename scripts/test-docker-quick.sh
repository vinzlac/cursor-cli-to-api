#!/usr/bin/env bash
# Script de test rapide pour vérifier que le conteneur Docker fonctionne

set -e

API_URL="http://localhost:8001"

# Charger API_KEY depuis .env si disponible
if [ -f .env ]; then
    export $(grep "^API_KEY=" .env | xargs 2>/dev/null || true)
fi

# Vérifier si l'authentification est activée
if [ -n "$API_KEY" ]; then
    echo "🔐 Authentification activée"
    AUTH_HEADER="-H 'Authorization: Bearer $API_KEY'"
else
    echo "⚠️  Authentification désactivée"
    AUTH_HEADER=""
fi

echo "🧪 Tests rapides de l'API Docker"
echo "================================="
echo ""

# Test 1: Health check
echo "1️⃣  Health check..."
if curl -s "${API_URL}/health" | grep -q "ok"; then
    echo "   ✅ Serveur accessible"
    curl -s "${API_URL}/health" | jq . 2>/dev/null || curl -s "${API_URL}/health"
else
    echo "   ❌ Serveur non accessible"
    exit 1
fi
echo ""

# Test 2: Liste des modèles
echo "2️⃣  Liste des modèles..."
if [ -n "$API_KEY" ]; then
    curl -s -H "Authorization: Bearer $API_KEY" "${API_URL}/v1/models" | jq '.data | length' 2>/dev/null && echo "   ✅ Modèles disponibles" || echo "   ⚠️  Impossible de récupérer les modèles"
else
    curl -s "${API_URL}/v1/models" | jq '.data | length' 2>/dev/null && echo "   ✅ Modèles disponibles" || echo "   ⚠️  Impossible de récupérer les modèles"
fi
echo ""

# Test 3: Chat completion
echo "3️⃣  Test de chat completion..."
if [ -n "$API_KEY" ]; then
    RESPONSE=$(curl -s -X POST "${API_URL}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        -d '{
            "model": "auto",
            "messages": [
                {"role": "user", "content": "Dis juste OK"}
            ]
        }')
else
    RESPONSE=$(curl -s -X POST "${API_URL}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "auto",
            "messages": [
                {"role": "user", "content": "Dis juste OK"}
            ]
        }')
fi

if echo "$RESPONSE" | grep -q "choices"; then
    CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content' 2>/dev/null || echo "Réponse reçue")
    echo "   ✅ Chat completion fonctionne"
    echo "   Réponse: $CONTENT"
else
    echo "   ❌ Chat completion échoué"
    echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
    exit 1
fi
echo ""

echo "================================="
echo "✅ Tous les tests sont passés !"
echo ""
echo "💡 Commandes utiles:"
echo "   - Voir les logs: docker logs <container_id>"
echo "   - Arrêter: docker stop <container_id>"
echo "   - Documentation: http://localhost:8001/docs"

