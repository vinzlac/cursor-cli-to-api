#!/usr/bin/env bash
# Test simple pour voir si cursor-agent peut rester en vie

set -e

echo "🧪 Test simple - cursor-agent processus persistant"
echo "==================================================="
echo ""

# Charger CURSOR_API_KEY
if [ -f .env ]; then
    export $(grep "^CURSOR_API_KEY=" .env | xargs 2>/dev/null || true)
fi

# Test: Lancer cursor-agent et voir s'il peut accepter plusieurs entrées
echo "Test: Lancer cursor-agent et lui envoyer plusieurs prompts"
echo ""

# Créer un script qui envoie plusieurs prompts
cat > /tmp/test_cursor.sh << 'SCRIPT'
#!/bin/bash
echo "user: Bonjour" | cursor-agent --print --model gpt-5.2
echo "---"
echo "user: Qu'est-ce que Python?" | cursor-agent --print --model gpt-5.2
SCRIPT

chmod +x /tmp/test_cursor.sh

echo "Exécution de 2 prompts séquentiels..."
START=$(date +%s.%N)
/tmp/test_cursor.sh 2>&1 | grep -v "^Error:" | head -10
END=$(date +%s.%N)
DURATION=$(echo "$END - $START" | bc)
echo ""
echo "Temps total: ${DURATION}s"
echo ""

# Test alternatif: Utiliser un processus en arrière-plan avec communication
echo "Test alternatif: Processus en arrière-plan"
echo "-------------------------------------------"

# Créer des pipes pour communication bidirectionnelle
INPUT_PIPE=$(mktemp -u)
OUTPUT_PIPE=$(mktemp -u)
mkfifo "$INPUT_PIPE"
mkfifo "$OUTPUT_PIPE"

echo "Lancement de cursor-agent..."
# Lancer cursor-agent qui lit depuis INPUT_PIPE et écrit dans OUTPUT_PIPE
cursor-agent --print --model gpt-5.2 < "$INPUT_PIPE" > "$OUTPUT_PIPE" 2>&1 &
CURSOR_PID=$!

echo "PID: $CURSOR_PID"
sleep 1

# Vérifier si toujours en vie
if kill -0 $CURSOR_PID 2>/dev/null; then
    echo "✅ Processus en vie"
    
    # Envoyer un prompt
    echo "Envoi du prompt..."
    echo "user: Bonjour" > "$INPUT_PIPE" &
    
    # Lire la réponse (avec timeout)
    timeout 10 cat "$OUTPUT_PIPE" | head -5 || echo "Timeout ou pas de réponse"
    
    # Nettoyer
    kill $CURSOR_PID 2>/dev/null || true
    wait $CURSOR_PID 2>/dev/null || true
else
    echo "❌ Processus mort"
    cat "$OUTPUT_PIPE" 2>/dev/null || true
fi

rm -f "$INPUT_PIPE" "$OUTPUT_PIPE" /tmp/test_cursor.sh

echo ""
echo "=================================================="
echo "💡 Si cursor-agent ne supporte pas le mode"
echo "   persistant, chaque appel doit être indépendant."
echo ""

