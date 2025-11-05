#!/bin/bash
# Script de test d'int?gration pour v?rifier que l'API fonctionne correctement

set -e

API_URL="${API_URL:-http://localhost:8000}"

echo "?? Tests d'int?gration de l'API cursor-agent"
echo "=============================================="
echo ""

# Test 1: Health check
echo "1. Test du health check..."
HEALTH_RESPONSE=$(curl -s "${API_URL}/health")
if echo "$HEALTH_RESPONSE" | grep -q "ok"; then
    echo "? Health check r?ussi"
else
    echo "? Health check ?chou?"
    exit 1
fi
echo ""

# Test 2: Liste des mod?les
echo "2. Test de la liste des mod?les..."
MODELS_RESPONSE=$(curl -s "${API_URL}/v1/models")
if echo "$MODELS_RESPONSE" | grep -q "cursor-agent"; then
    echo "? Liste des mod?les OK"
else
    echo "? Liste des mod?les ?chou?e"
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
    echo "? Chat completion r?ussi"
    echo "R?ponse: $(echo "$CHAT_RESPONSE" | grep -o '"content":"[^"]*"')"
else
    echo "? Chat completion ?chou?"
    echo "R?ponse: $CHAT_RESPONSE"
    exit 1
fi
echo ""

# Test 4: V?rification du format de r?ponse OpenAI
echo "4. V?rification du format OpenAI..."
if echo "$CHAT_RESPONSE" | grep -q '"object":"chat.completion"'; then
    echo "? Format OpenAI compatible"
else
    echo "??  Format peut ne pas ?tre compatible OpenAI"
fi
echo ""

echo "=============================================="
echo "? Tous les tests d'int?gration sont pass?s!"
