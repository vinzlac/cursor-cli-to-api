#!/bin/bash
# Script de test d'intégration pour vérifier que l'API fonctionne correctement

set -e

API_URL="${API_URL:-http://localhost:8000}"

echo "🧪 Tests d'intégration de l'API cursor-agent"
echo "=============================================="
echo ""

# Test 1: Health check
echo "1. Test du health check..."
HEALTH_RESPONSE=$(curl -s "${API_URL}/health")
if echo "$HEALTH_RESPONSE" | grep -q "ok"; then
    echo "✅ Health check réussi"
else
    echo "❌ Health check échoué"
    exit 1
fi
echo ""

# Test 2: Liste des modèles
echo "2. Test de la liste des modèles..."
MODELS_RESPONSE=$(curl -s "${API_URL}/v1/models")
if echo "$MODELS_RESPONSE" | grep -q "cursor-agent"; then
    echo "✅ Liste des modèles OK"
else
    echo "❌ Liste des modèles échouée"
    exit 1
fi
echo ""

# Test 3: Chat completion
echo "3. Test de chat completion..."
CHAT_RESPONSE=$(curl -s -X POST "${API_URL}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "cursor-agent",
        "messages": [
            {"role": "user", "content": "Bonjour"}
        ]
    }')

if echo "$CHAT_RESPONSE" | grep -q "choices"; then
    echo "✅ Chat completion réussi"
    echo "Réponse: $(echo "$CHAT_RESPONSE" | grep -o '"content":"[^"]*"')"
else
    echo "❌ Chat completion échoué"
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

echo "=============================================="
echo "✅ Tous les tests d'intégration sont passés!"
