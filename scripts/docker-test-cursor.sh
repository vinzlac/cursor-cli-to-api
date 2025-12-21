#!/usr/bin/env bash
# Script pour tester cursor-agent dans le conteneur Docker

set -e

echo "🧪 Test cursor-agent dans Docker"
echo "================================="
echo ""

# Trouver le conteneur
CONTAINER_NAME=""
if docker ps --format '{{.Names}}' | grep -q "cursor"; then
    CONTAINER_NAME=$(docker ps --format '{{.Names}}' | grep "cursor" | head -1)
    echo "✅ Conteneur trouvé: $CONTAINER_NAME"
else
    echo "❌ Aucun conteneur cursor en cours d'exécution"
    echo ""
    echo "💡 Lancez d'abord un conteneur:"
    echo "   just docker-up"
    exit 1
fi

echo ""

# Test 1: Vérifier cursor-agent
echo "Test 1: Vérification cursor-agent"
echo "----------------------------------"
if docker exec "$CONTAINER_NAME" which cursor-agent > /dev/null 2>&1; then
    CURSOR_PATH=$(docker exec "$CONTAINER_NAME" which cursor-agent)
    echo "✅ cursor-agent trouvé: $CURSOR_PATH"
    
    VERSION=$(docker exec "$CONTAINER_NAME" cursor-agent --version 2>&1 || echo "Erreur")
    echo "   Version: $VERSION"
else
    echo "❌ cursor-agent n'est pas trouvé"
    echo "   Reconstruisez l'image: just docker-build"
    exit 1
fi
echo ""

# Test 2: Vérifier CURSOR_API_KEY
echo "Test 2: Vérification CURSOR_API_KEY"
echo "------------------------------------"
API_KEY=$(docker exec "$CONTAINER_NAME" printenv CURSOR_API_KEY 2>/dev/null || echo "")
if [ -z "$API_KEY" ]; then
    echo "❌ CURSOR_API_KEY n'est pas définie"
    echo "   Vérifiez votre configuration Docker"
else
    echo "✅ CURSOR_API_KEY est définie (${#API_KEY} caractères)"
fi
echo ""

# Test 3: Test simple avec timeout court
echo "Test 3: Test simple cursor-agent (timeout 30s)"
echo "-----------------------------------------------"
echo "Note: Le modèle 'auto' peut être plus lent avec des prompts très courts."
echo "      Avec un prompt réaliste, 'auto' prend ~4-5s (comme via l'API)."
echo "      Pour des tests plus rapides, utilisez un modèle spécifique (ex: gpt-5.2)."
echo ""
echo "Commande: cursor-agent --print --model auto 'user: Bonjour, comment ça va ?'"
echo ""

# Récupérer CURSOR_API_KEY depuis le conteneur pour la passer explicitement
CONTAINER_API_KEY=$(docker exec "$CONTAINER_NAME" printenv CURSOR_API_KEY 2>/dev/null || echo "")

START=$(date +%s)
TIMEOUT=30

# Utiliser un prompt plus réaliste (comme dans l'API) pour avoir des temps comparables
# Les prompts très courts peuvent déclencher un comportement différent avec 'auto'
TEST_PROMPT="user: Bonjour, comment ça va ?"

# Passer CURSOR_API_KEY explicitement dans l'environnement
# docker exec n'hérite pas automatiquement des variables d'environnement du conteneur
if [ -n "$CONTAINER_API_KEY" ]; then
    echo "   Utilisation de CURSOR_API_KEY du conteneur..."
    OUTPUT=$(docker exec -e CURSOR_API_KEY="$CONTAINER_API_KEY" "$CONTAINER_NAME" timeout $TIMEOUT cursor-agent --print --model auto "$TEST_PROMPT" 2>&1)
else
    echo "   ⚠️  CURSOR_API_KEY non trouvée, test sans authentification..."
    OUTPUT=$(docker exec "$CONTAINER_NAME" timeout $TIMEOUT cursor-agent --print --model auto "$TEST_PROMPT" 2>&1)
fi

EXIT_CODE=$?
END=$(date +%s)
DURATION=$((END - START))

if [ $EXIT_CODE -eq 124 ]; then
    echo "❌ TIMEOUT après ${TIMEOUT}s"
    echo "   Temps écoulé: ${DURATION}s"
    echo "   cursor-agent ne répond pas dans le conteneur"
    echo ""
    echo "💡 Solutions possibles:"
    echo "   1. Vérifiez CURSOR_API_KEY: docker exec $CONTAINER_NAME printenv CURSOR_API_KEY"
    echo "   2. Vérifiez la connectivité: docker exec $CONTAINER_NAME curl -v https://cursor.com"
    echo "   3. Reconstruisez l'image: just docker-build"
    echo "   4. Vérifiez les logs: docker logs $CONTAINER_NAME"
    exit 1
elif [ $EXIT_CODE -ne 0 ]; then
    echo "❌ ERREUR (code: $EXIT_CODE)"
    echo "   Temps écoulé: ${DURATION}s"
    echo "   Sortie:"
    echo "$OUTPUT" | head -20
    echo ""
    echo "💡 Solutions possibles:"
    echo "   1. Vérifiez CURSOR_API_KEY: docker exec $CONTAINER_NAME printenv CURSOR_API_KEY"
    echo "   2. Vérifiez la connectivité: docker exec $CONTAINER_NAME curl -v https://cursor.com"
    echo "   3. Reconstruisez l'image: just docker-build"
    echo "   4. Vérifiez les logs: docker logs $CONTAINER_NAME"
    exit 1
elif [ -z "$OUTPUT" ]; then
    echo "⚠️  cursor-agent a réussi (code: 0) mais aucune sortie"
    echo "   Temps écoulé: ${DURATION}s"
    echo "   Cela peut indiquer un problème de configuration"
    echo ""
    echo "💡 Testez manuellement:"
    echo "   docker exec -it $CONTAINER_NAME cursor-agent --print --model auto 'user: test'"
    exit 1
fi

echo "✅ SUCCÈS !"
echo "   Temps d'exécution: ${DURATION}s"
echo "   Réponse:"
echo "$OUTPUT" | head -5
echo ""

echo "================================="
echo "✅ cursor-agent fonctionne dans Docker"
echo ""
echo "📊 Résultats du test:"
echo "   - Modèle testé: auto (sélection automatique)"
echo "   - Temps d'exécution: ${DURATION}s"
if (( $(echo "$DURATION < 10" | bc -l) )); then
    echo "   - Performance: ✅ Excellente (< 10s)"
elif (( $(echo "$DURATION < 20" | bc -l) )); then
    echo "   - Performance: ✅ Bonne (< 20s)"
else
    echo "   - Performance: ⚠️  Lente (> 20s) - Normal pour 'auto'"
fi
echo ""
echo "💡 Note importante:"
echo "   - Le modèle 'auto' avec un prompt réaliste prend ~4-5s (identique à l'API)"
echo "   - Avec des prompts très courts, 'auto' peut être plus lent (~20-25s)"
echo "   - Les modèles spécifiques (gpt-5.2, gpt-5.1, etc.) sont généralement plus rapides (~4-5s)"
echo "   - La performance dépend du prompt : prompts réalistes = meilleure performance avec 'auto'"
echo ""
echo "💡 Si l'API timeout, vérifiez:"
echo "   - Les logs: docker logs -f $CONTAINER_NAME"
echo "   - Le timeout: CURSOR_AGENT_TIMEOUT dans .env"

