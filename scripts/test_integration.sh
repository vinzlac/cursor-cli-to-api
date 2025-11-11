#!/bin/bash
# Script de test d'intégration pour vérifier que l'API fonctionne correctement

set -e

API_URL="${API_URL:-http://localhost:8001}"

# Charger API_KEY depuis .env si disponible
if [ -f .env ]; then
    export $(grep "^API_KEY=" .env | xargs)
fi

# Vérifier si l'authentification est activée
if [ -n "$API_KEY" ]; then
    echo "🔐 Authentification activée (API_KEY configurée)"
    AUTH_HEADER="Authorization: Bearer $API_KEY"
else
    echo "⚠️  Authentification désactivée (pas d'API_KEY)"
    AUTH_HEADER=""
fi

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
if [ -n "$AUTH_HEADER" ]; then
    HTTP_CODE=$(curl -s -o /tmp/models_response.json -w "%{http_code}" -H "$AUTH_HEADER" "${API_URL}/v1/models")
else
    HTTP_CODE=$(curl -s -o /tmp/models_response.json -w "%{http_code}" "${API_URL}/v1/models")
fi
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
if [ -n "$AUTH_HEADER" ]; then
    HTTP_CODE=$(curl -s -o /tmp/chat_response.json -w "%{http_code}" -X POST "${API_URL}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -H "$AUTH_HEADER" \
        -d '{
            "model": "cursor-agent",
            "messages": [
                {"role": "user", "content": "Bonjour"}
            ]
        }')
else
    HTTP_CODE=$(curl -s -o /tmp/chat_response.json -w "%{http_code}" -X POST "${API_URL}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "cursor-agent",
            "messages": [
                {"role": "user", "content": "Bonjour"}
            ]
        }')
fi
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

# Test 5: Vérification de l'authentification (si activée)
if [ -n "$API_KEY" ]; then
    echo "5. Test de l'authentification..."
    HTTP_CODE=$(curl -s -o /tmp/auth_test.json -w "%{http_code}" -X POST "${API_URL}/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer wrong-key" \
        -d '{"model":"cursor-agent","messages":[{"role":"user","content":"Test"}]}')
    
    if [ "$HTTP_CODE" -eq 401 ] || [ "$HTTP_CODE" -eq 403 ]; then
        echo "✅ Authentification fonctionne (HTTP $HTTP_CODE pour mauvaise clé)"
    else
        echo "⚠️  L'authentification ne bloque pas les mauvaises clés (HTTP $HTTP_CODE)"
    fi
    echo ""
fi

# Nettoyage des fichiers temporaires
rm -f /tmp/health_response.json /tmp/models_response.json /tmp/chat_response.json /tmp/auth_test.json

echo "=============================================="
if [ -n "$API_KEY" ]; then
    echo "✅ Tous les tests d'intégration sont passés (avec authentification)!"
else
    echo "✅ Tous les tests d'intégration sont passés (sans authentification)!"
fi
