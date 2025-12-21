#!/usr/bin/env bash
# Script pour tester cursor-agent en CLI direct et comparer avec l'API

set -e

echo "⚡ Test de performance - cursor-agent CLI direct"
echo "================================================"
echo ""

# Charger CURSOR_API_KEY depuis .env si disponible
if [ -f .env ]; then
    export $(grep "^CURSOR_API_KEY=" .env | xargs 2>/dev/null || true)
fi

if [ -z "$CURSOR_API_KEY" ]; then
    echo "⚠️  CURSOR_API_KEY non définie dans .env"
    echo "   Le test peut échouer si cursor-agent nécessite une authentification"
    echo ""
fi

# Test 1: Prompt simple
echo "Test 1: Prompt simple"
echo "---------------------"
PROMPT1="user: Explique-moi ce qu'est FastAPI en 2 phrases."
echo "Prompt: $PROMPT1"
echo ""

START1=$(date +%s.%N)
RESPONSE1=$(echo "$PROMPT1" | cursor-agent --print --model gpt-5.2 2>&1)
END1=$(date +%s.%N)
DURATION1=$(echo "$END1 - $START1" | bc)
DURATION1_MS=$(echo "$DURATION1 * 1000" | bc | cut -d. -f1)

echo "Réponse: $(echo "$RESPONSE1" | head -2 | tr '\n' ' ')"
echo "Temps: ${DURATION1_MS}ms (${DURATION1}s)"
echo ""

# Test 2: Prompt encore plus simple
echo "Test 2: Prompt très simple"
echo "--------------------------"
PROMPT2="user: Bonjour"
echo "Prompt: $PROMPT2"
echo ""

START2=$(date +%s.%N)
RESPONSE2=$(echo "$PROMPT2" | cursor-agent --print --model gpt-5.2 2>&1)
END2=$(date +%s.%N)
DURATION2=$(echo "$END2 - $START2" | bc)
DURATION2_MS=$(echo "$DURATION2 * 1000" | bc | cut -d. -f1)

echo "Réponse: $(echo "$RESPONSE2" | head -2 | tr '\n' ' ')"
echo "Temps: ${DURATION2_MS}ms (${DURATION2}s)"
echo ""

# Test 3: Avec system message
echo "Test 3: Avec system message"
echo "---------------------------"
PROMPT3="system: Tu es un assistant Python expert.
user: Qu'est-ce que Python?"
echo "Prompt: system + user"
echo ""

START3=$(date +%s.%N)
RESPONSE3=$(echo -e "$PROMPT3" | cursor-agent --print --model gpt-5.2 2>&1)
END3=$(date +%s.%N)
DURATION3=$(echo "$END3 - $START3" | bc)
DURATION3_MS=$(echo "$DURATION3 * 1000" | bc | cut -d. -f1)

echo "Réponse: $(echo "$RESPONSE3" | head -2 | tr '\n' ' ')"
echo "Temps: ${DURATION3_MS}ms (${DURATION3}s)"
echo ""

# Calculer la moyenne
AVG=$(echo "scale=2; ($DURATION1 + $DURATION2 + $DURATION3) / 3" | bc)
AVG_MS=$(echo "$AVG * 1000" | bc | cut -d. -f1)

echo "================================================"
echo "📊 Résultats:"
echo "   Test 1: ${DURATION1_MS}ms"
echo "   Test 2: ${DURATION2_MS}ms"
echo "   Test 3: ${DURATION3_MS}ms"
echo "   Moyenne: ${AVG_MS}ms (${AVG}s)"
echo ""
echo "💡 Comparaison avec l'API:"
echo "   - CLI direct: ~${AVG_MS}ms"
echo "   - Via API (subprocess): ~5000-7000ms"
echo "   - Différence (overhead): ~$(echo "7000 - $AVG_MS" | bc)ms"
echo ""
echo "📝 Conclusion:"
if (( $(echo "$AVG_MS > 5000" | bc -l) )); then
    echo "   Le temps est principalement passé dans cursor-agent lui-même"
    echo "   L'overhead du subprocess est minimal"
else
    echo "   Il y a un overhead significatif du subprocess"
    echo "   Le temps cursor-agent seul: ~${AVG_MS}ms"
    echo "   L'overhead subprocess: ~$(echo "7000 - $AVG_MS" | bc)ms"
fi

