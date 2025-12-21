#!/usr/bin/env bash
# Script pour tester et comparer les performances entre mode CLI et HTTP

set -e

API_URL="http://localhost:8001"

# Charger API_KEY depuis .env si disponible
if [ -f .env ]; then
    export $(grep "^API_KEY=" .env | xargs 2>/dev/null || true)
fi

echo "⚡ Test de performance - Comparaison CLI vs HTTP"
echo "================================================"
echo ""

# Vérifier que le serveur est accessible
if ! curl -s "${API_URL}/health" > /dev/null; then
    echo "❌ Erreur: Le serveur n'est pas accessible sur ${API_URL}"
    echo "   Démarrez le serveur avec: just dev"
    exit 1
fi

echo "✅ Serveur accessible"
echo ""

# Préparer la requête de test
REQUEST_DATA='{
  "model": "gpt-5.2",
  "messages": [
    {
      "role": "system",
      "content": "Tu es un assistant Python expert."
    },
    {
      "role": "user",
      "content": "Explique-moi ce qu'\''est FastAPI en 2 phrases."
    }
  ],
  "temperature": 0.7,
  "max_tokens": 200
}'

# Préparer les headers
HEADERS=(-H "Content-Type: application/json")
if [ -n "$API_KEY" ]; then
    HEADERS+=(-H "Authorization: Bearer $API_KEY")
fi

echo "🧪 Test de performance avec 3 requêtes..."
echo ""

# Faire 3 requêtes et mesurer le temps
TOTAL_TIME=0
for i in {1..3}; do
    echo "Requête $i/3..."
    START_TIME=$(date +%s.%N)
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/v1/chat/completions" \
        "${HEADERS[@]}" \
        -d "$REQUEST_DATA")
    
    END_TIME=$(date +%s.%N)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" = "200" ]; then
        DURATION=$(echo "$END_TIME - $START_TIME" | bc)
        DURATION_MS=$(echo "$DURATION * 1000" | bc | cut -d. -f1)
        TOTAL_TIME=$(echo "$TOTAL_TIME + $DURATION" | bc)
        echo "   ✅ Réussi en ${DURATION_MS}ms"
    else
        echo "   ❌ Échec (HTTP $HTTP_CODE)"
        echo "$BODY" | head -5
    fi
    echo ""
done

# Calculer la moyenne
AVG_TIME=$(echo "scale=2; $TOTAL_TIME / 3" | bc)
AVG_TIME_MS=$(echo "$AVG_TIME * 1000" | bc | cut -d. -f1)

echo "================================================"
echo "📊 Résultats:"
echo "   Temps moyen: ${AVG_TIME_MS}ms (${AVG_TIME}s)"
echo ""
echo "💡 Pour comparer avec le mode HTTP:"
echo "   1. Configurez CURSOR_AGENT_MODE=http dans .env"
echo "   2. Configurez CURSOR_AGENT_HTTP_URL avec l'URL de l'API cursor-agent"
echo "   3. Redémarrez le serveur"
echo "   4. Relancez ce script"
echo ""
echo "📖 Voir doc/PERFORMANCE.md pour plus de détails"

