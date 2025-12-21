#!/usr/bin/env bash
# Test de performance avec --resume vs nouveau chat à chaque fois

set -e

echo "⚡ Test de performance: --resume vs nouveau chat"
echo "================================================="
echo ""

# Charger CURSOR_API_KEY
if [ -f .env ]; then
    export $(grep "^CURSOR_API_KEY=" .env | xargs 2>/dev/null || true)
fi

# Créer un chat une fois
echo "Création d'un chat pour les tests..."
CHAT_ID=$(cursor-agent create-chat 2>&1 | grep -oE '[a-f0-9-]{36}' | head -1)
if [ -z "$CHAT_ID" ]; then
    echo "❌ Impossible de créer un chat"
    exit 1
fi
echo "✅ Chat créé: $CHAT_ID"
echo ""

# Test 1: Utiliser --resume avec le même chatId (3 prompts)
echo "Test 1: --resume avec le même chatId (3 prompts)"
echo "--------------------------------------------------"
START1=$(date +%s.%N)
for i in {1..3}; do
    case $i in
        1) PROMPT="user: Bonjour" ;;
        2) PROMPT="user: Qu'est-ce que Python?" ;;
        3) PROMPT="user: Explique FastAPI en 2 phrases" ;;
    esac
    echo "$PROMPT" | cursor-agent --print --model gpt-5.2 --resume "$CHAT_ID" > /dev/null 2>&1
done
END1=$(date +%s.%N)
DURATION1=$(echo "$END1 - $START1" | bc)
DURATION1_MS=$(echo "$DURATION1 * 1000" | bc | cut -d. -f1)
echo "Temps total: ${DURATION1_MS}ms (${DURATION1}s)"
echo "Temps moyen par prompt: $(echo "scale=0; $DURATION1_MS / 3" | bc)ms"
echo ""

# Test 2: Créer un nouveau chat à chaque fois (3 prompts)
echo "Test 2: Nouveau chat à chaque fois (3 prompts)"
echo "-----------------------------------------------"
START2=$(date +%s.%N)
for i in {1..3}; do
    case $i in
        1) PROMPT="user: Bonjour" ;;
        2) PROMPT="user: Qu'est-ce que Python?" ;;
        3) PROMPT="user: Explique FastAPI en 2 phrases" ;;
    esac
    # Créer un nouveau chat à chaque fois
    NEW_CHAT_ID=$(cursor-agent create-chat 2>&1 | grep -oE '[a-f0-9-]{36}' | head -1)
    echo "$PROMPT" | cursor-agent --print --model gpt-5.2 --resume "$NEW_CHAT_ID" > /dev/null 2>&1
done
END2=$(date +%s.%N)
DURATION2=$(echo "$END2 - $START2" | bc)
DURATION2_MS=$(echo "$DURATION2 * 1000" | bc | cut -d. -f1)
echo "Temps total: ${DURATION2_MS}ms (${DURATION2}s)"
echo "Temps moyen par prompt: $(echo "scale=0; $DURATION2_MS / 3" | bc)ms"
echo ""

# Test 3: Sans --resume (nouveau chat implicite à chaque fois)
echo "Test 3: Sans --resume (nouveau chat implicite)"
echo "-----------------------------------------------"
START3=$(date +%s.%N)
for i in {1..3}; do
    case $i in
        1) PROMPT="user: Bonjour" ;;
        2) PROMPT="user: Qu'est-ce que Python?" ;;
        3) PROMPT="user: Explique FastAPI en 2 phrases" ;;
    esac
    echo "$PROMPT" | cursor-agent --print --model gpt-5.2 > /dev/null 2>&1
done
END3=$(date +%s.%N)
DURATION3=$(echo "$END3 - $START3" | bc)
DURATION3_MS=$(echo "$DURATION3 * 1000" | bc | cut -d. -f1)
echo "Temps total: ${DURATION3_MS}ms (${DURATION3}s)"
echo "Temps moyen par prompt: $(echo "scale=0; $DURATION3_MS / 3" | bc)ms"
echo ""

# Comparaison
echo "=================================================="
echo "📊 Comparaison:"
echo "   Test 1 (--resume même chatId): ${DURATION1_MS}ms"
echo "   Test 2 (nouveau chatId à chaque fois): ${DURATION2_MS}ms"
echo "   Test 3 (sans --resume): ${DURATION3_MS}ms"
echo ""

if (( $(echo "$DURATION1_MS < $DURATION2_MS" | bc -l) )); then
    GAIN=$(echo "scale=1; ($DURATION2_MS - $DURATION1_MS) * 100 / $DURATION2_MS" | bc)
    echo "✅ --resume avec même chatId est ${GAIN}% plus rapide"
else
    echo "⚠️  --resume avec même chatId n'est pas plus rapide"
fi

echo ""
echo "💡 Conclusion:"
echo "   Si --resume avec le même chatId est plus rapide,"
echo "   on peut créer un chat au démarrage et le réutiliser"
echo "   pour tous les appels suivants."
echo ""

