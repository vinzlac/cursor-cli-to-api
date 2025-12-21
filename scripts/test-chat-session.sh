#!/usr/bin/env bash
# Test avec les sessions de chat de cursor-agent

set -e

echo "🧪 Test avec les sessions de chat cursor-agent"
echo "==============================================="
echo ""

# Charger CURSOR_API_KEY
if [ -f .env ]; then
    export $(grep "^CURSOR_API_KEY=" .env | xargs 2>/dev/null || true)
fi

# Test 1: Créer un chat et obtenir son ID
echo "Test 1: Créer un chat et obtenir son ID"
echo "----------------------------------------"
CHAT_ID=$(cursor-agent create-chat 2>&1 | grep -oE '[a-f0-9-]{36}' | head -1 || echo "")
if [ -z "$CHAT_ID" ]; then
    echo "❌ Impossible de créer un chat ou d'obtenir l'ID"
    cursor-agent create-chat 2>&1 | head -10
else
    echo "✅ Chat créé avec ID: $CHAT_ID"
fi
echo ""

# Test 2: Utiliser --resume avec un chatId
if [ -n "$CHAT_ID" ]; then
    echo "Test 2: Envoyer un prompt à la session avec --resume"
    echo "----------------------------------------------------"
    echo "user: Bonjour" | cursor-agent --print --model gpt-5.2 --resume "$CHAT_ID" 2>&1 | head -5
    echo ""
    
    echo "Test 3: Envoyer un deuxième prompt à la même session"
    echo "----------------------------------------------------"
    echo "user: Qu'est-ce que Python?" | cursor-agent --print --model gpt-5.2 --resume "$CHAT_ID" 2>&1 | head -5
    echo ""
fi

# Test 4: Vérifier si on peut garder une session en vie
echo "Test 4: Mode interactif (sans --print) pour voir le comportement"
echo "----------------------------------------------------------------"
echo "Note: cursor-agent en mode interactif nécessite une interface TUI"
echo "Mais on peut tester si le processus reste en vie"
echo ""

# Test avec un processus en arrière-plan sans --print
echo "Lancement de cursor-agent sans --print (mode interactif)..."
cursor-agent --model gpt-5.2 > /tmp/cursor-interactive.log 2>&1 &
CURSOR_PID=$!

echo "PID: $CURSOR_PID"
sleep 2

if kill -0 $CURSOR_PID 2>/dev/null; then
    echo "✅ Processus toujours en vie (mode interactif)"
    echo "Logs:"
    cat /tmp/cursor-interactive.log 2>/dev/null | head -10 || echo "Pas de logs"
    
    # Essayer d'envoyer un prompt via stdin
    echo ""
    echo "Essai d'envoi de prompt via stdin..."
    echo "user: Bonjour" > /proc/$CURSOR_PID/fd/0 2>/dev/null || echo "Impossible d'écrire dans stdin"
    
    sleep 2
    echo "Logs après envoi:"
    cat /tmp/cursor-interactive.log 2>/dev/null | tail -10 || echo "Pas de nouveaux logs"
    
    kill $CURSOR_PID 2>/dev/null || true
    wait $CURSOR_PID 2>/dev/null || true
else
    echo "❌ Processus terminé"
    cat /tmp/cursor-interactive.log 2>/dev/null || echo "Pas de logs"
fi

rm -f /tmp/cursor-interactive.log

echo ""
echo "=================================================="
echo "📝 Conclusion:"
echo "   Si --resume fonctionne avec un chatId, on peut"
echo "   créer une session une fois et réutiliser le"
echo "   chatId pour tous les appels suivants."
echo ""

