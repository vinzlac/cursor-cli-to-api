#!/bin/bash
# Script de test d'intégration pour vérifier que l'API fonctionne correctement

set -e

API_URL="${API_URL:-http://localhost:8001}"

echo "🧪 Tests d'intégration de l'API cursor-agent"
echo "=============================================="
echo ""

# Test 1: Health check
echo "1. Test du health check..."
HTTP_CODE=$(curl -s -o /tmp/health_response.json -w "%{http_code}" "${API_URL}/health")
HEALTH_RESPONSE=$(cat /tmp/health_response.json)

if [ "$HTTP_CODE" -eq 200 ] && echo "$HEALTH_RESPONSE" | grep -q "ok"; then
    echo "✅ Health check réussi (HTTP $HTTP_CODE)"
else
    echo "❌ Health check échoué (HTTP $HTTP_CODE)"
    echo "Réponse: $HEALTH_RESPONSE"
    exit 1
fi
echo ""

# Test 2: Liste des modèles
echo "2. Test de la liste des modèles..."
HTTP_CODE=$(curl -s -o /tmp/models_response.json -w "%{http_code}" "${API_URL}/v1/models")
MODELS_RESPONSE=$(cat /tmp/models_response.json)

if [ "$HTTP_CODE" -eq 200 ] && echo "$MODELS_RESPONSE" | grep -q "cursor-agent"; then
    echo "✅ Liste des modèles OK (HTTP $HTTP_CODE)"
else
    echo "❌ Liste des modèles échouée (HTTP $HTTP_CODE)"
    echo "Réponse: $MODELS_RESPONSE"
    exit 1
fi
echo ""

# Test 3: Chat completion
echo "3. Test de chat completion..."
HTTP_CODE=$(curl -s -o /tmp/chat_response.json -w "%{http_code}" -X POST "${API_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "cursor-agent",
        "messages": [
            {"role": "user", "content": "Bonjour"}
        ]
    }')
CHAT_RESPONSE=$(cat /tmp/chat_response.json)

if [ "$HTTP_CODE" -eq 200 ] && echo "$CHAT_RESPONSE" | grep -q "choices"; then
    echo "✅ Chat completion réussi (HTTP $HTTP_CODE)"
    echo "Réponse: $(echo "$CHAT_RESPONSE" | grep -o '"content":"[^"]*"' | head -1)"
else
    echo "❌ Chat completion échoué (HTTP $HTTP_CODE)"
    echo "Réponse: $CHAT_RESPONSE"
    exit 1
fi
echo ""

# Test 4: Vérification du format de réponse OpenAI
echo "4. Vérification du format OpenAI..."
if echo "$CHAT_RESPONSE" | grep -q '"object":"chat.completion"'; then
    echo "✅ Format OpenAI compatible"
else
    echo "⚠️  Format peut ne pas être compatible OpenAI"
fi
echo ""

# Nettoyage des fichiers temporaires
rm -f /tmp/health_response.json /tmp/models_response.json /tmp/chat_response.json

echo "=============================================="
echo "✅ Tous les tests d'intégration sont passés!"
