#!/usr/bin/env bash
# Script pour tester cursor-agent avec un processus persistant

set -e

echo "🧪 Test de cursor-agent avec processus persistant"
echo "=================================================="
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

# Test 1: Vérifier si cursor-agent peut lire depuis stdin de manière continue
echo "Test 1: cursor-agent avec stdin continu"
echo "----------------------------------------"
echo ""

# Essayer de lancer cursor-agent et lui envoyer plusieurs prompts
echo "Lancement de cursor-agent en arrière-plan..."
echo ""

# Créer un fichier temporaire pour les prompts
PROMPTS_FILE=$(mktemp)
cat > "$PROMPTS_FILE" << 'EOF'
user: Bonjour
user: Qu'est-ce que Python?
user: Explique FastAPI en 2 phrases
EOF

# Test avec --print et stdin
echo "Test avec --print et stdin:"
START=$(date +%s.%N)
cat "$PROMPTS_FILE" | while IFS= read -r prompt; do
    echo "Envoi: $prompt"
    echo "$prompt" | cursor-agent --print --model gpt-5.2 2>&1 | head -3
    echo ""
done
END=$(date +%s.%N)
DURATION=$(echo "$END - $START" | bc)
echo "Temps total: ${DURATION}s"
echo ""

# Nettoyer
rm -f "$PROMPTS_FILE"

# Test 2: Essayer de garder cursor-agent en vie avec un pipe nommé
echo "Test 2: Processus persistant avec pipe nommé"
echo "---------------------------------------------"
echo ""

# Créer un pipe nommé
PIPE=$(mktemp -u)
mkfifo "$PIPE"

# Lancer cursor-agent en arrière-plan qui lit depuis le pipe
echo "Lancement de cursor-agent qui lit depuis le pipe..."
cursor-agent --print --model gpt-5.2 < "$PIPE" > /tmp/cursor-output.log 2>&1 &
CURSOR_PID=$!

echo "PID de cursor-agent: $CURSOR_PID"
echo "Attente de 2 secondes pour l'initialisation..."
sleep 2

# Vérifier si le processus est toujours en vie
if ! kill -0 $CURSOR_PID 2>/dev/null; then
    echo "❌ cursor-agent s'est arrêté immédiatement"
    echo "Logs:"
    cat /tmp/cursor-output.log
    rm -f "$PIPE" /tmp/cursor-output.log
    exit 1
fi

echo "✅ cursor-agent est toujours en vie"
echo ""

# Envoyer plusieurs prompts
echo "Envoi de prompts via le pipe..."
START=$(date +%s.%N)

for i in {1..3}; do
    echo "Prompt $i:"
    case $i in
        1) echo "user: Bonjour" > "$PIPE" ;;
        2) echo "user: Qu'est-ce que Python?" > "$PIPE" ;;
        3) echo "user: Explique FastAPI en 2 phrases" > "$PIPE" ;;
    esac
    sleep 1
    echo "Réponse (dernières lignes):"
    tail -5 /tmp/cursor-output.log 2>/dev/null || echo "Pas encore de réponse"
    echo ""
done

END=$(date +%s.%N)
DURATION=$(echo "$END - $START" | bc)

# Nettoyer
kill $CURSOR_PID 2>/dev/null || true
wait $CURSOR_PID 2>/dev/null || true
rm -f "$PIPE" /tmp/cursor-output.log

echo "Temps total: ${DURATION}s"
echo ""

# Test 3: Utiliser expect ou un script interactif
echo "Test 3: Mode interactif avec expect (si disponible)"
echo "----------------------------------------------------"
echo ""

if command -v expect &> /dev/null; then
    echo "expect est disponible, testons..."
    # Créer un script expect temporaire
    EXPECT_SCRIPT=$(mktemp)
    cat > "$EXPECT_SCRIPT" << 'EXPECTEOF'
#!/usr/bin/expect -f
set timeout 30
spawn cursor-agent --model gpt-5.2
expect {
    ">" { send "user: Bonjour\r" }
    timeout { puts "Timeout"; exit 1 }
}
expect {
    ">" { send "user: Qu'est-ce que Python?\r" }
    timeout { puts "Timeout"; exit 1 }
}
expect {
    ">" { send "exit\r" }
    timeout { puts "Timeout"; exit 1 }
}
expect eof
EXPECTEOF
    
    chmod +x "$EXPECT_SCRIPT"
    START=$(date +%s.%N)
    "$EXPECT_SCRIPT" 2>&1 | head -20
    END=$(date +%s.%N)
    DURATION=$(echo "$END - $START" | bc)
    echo "Temps total: ${DURATION}s"
    rm -f "$EXPECT_SCRIPT"
else
    echo "expect n'est pas disponible, test ignoré"
fi

echo ""
echo "=================================================="
echo "📝 Conclusion:"
echo "   Si cursor-agent peut rester en vie et accepter"
echo "   plusieurs prompts, on peut implémenter un"
echo "   processus persistant dans Python."
echo ""

