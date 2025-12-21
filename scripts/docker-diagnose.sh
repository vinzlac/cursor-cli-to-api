#!/usr/bin/env bash
# Script de diagnostic pour Docker

set -e

echo "🔍 Diagnostic Docker - cursor-agent"
echo "===================================="
echo ""

# Vérifier si un conteneur est en cours d'exécution
CONTAINER_NAME=""
if docker ps --format '{{.Names}}' | grep -q "cursor"; then
    CONTAINER_NAME=$(docker ps --format '{{.Names}}' | grep "cursor" | head -1)
    echo "✅ Conteneur trouvé: $CONTAINER_NAME"
else
    echo "❌ Aucun conteneur cursor en cours d'exécution"
    echo ""
    echo "💡 Lancez d'abord un conteneur:"
    echo "   just docker-up"
    echo "   ou"
    echo "   just docker-run-secure"
    exit 1
fi

echo ""

# Test 1: Vérifier que cursor-agent est installé
echo "Test 1: Vérification de cursor-agent"
echo "-------------------------------------"
if docker exec "$CONTAINER_NAME" which cursor-agent > /dev/null 2>&1; then
    CURSOR_PATH=$(docker exec "$CONTAINER_NAME" which cursor-agent)
    echo "✅ cursor-agent trouvé: $CURSOR_PATH"
    
    # Vérifier la version
    VERSION=$(docker exec "$CONTAINER_NAME" cursor-agent --version 2>&1 || echo "Erreur")
    echo "   Version: $VERSION"
else
    echo "❌ cursor-agent n'est pas trouvé dans le conteneur"
    echo "   Vérifiez le Dockerfile et reconstruisez l'image"
    exit 1
fi
echo ""

# Test 2: Vérifier CURSOR_API_KEY
echo "Test 2: Vérification de CURSOR_API_KEY"
echo "--------------------------------------"
API_KEY=$(docker exec "$CONTAINER_NAME" printenv CURSOR_API_KEY 2>/dev/null || echo "")
if [ -z "$API_KEY" ]; then
    echo "❌ CURSOR_API_KEY n'est pas définie dans le conteneur"
    echo "   Vérifiez votre configuration Docker Compose ou .env"
else
    echo "✅ CURSOR_API_KEY est définie"
    echo "   Longueur: ${#API_KEY} caractères"
    echo "   Préfixe: ${API_KEY:0:10}..."
fi
echo ""

# Test 3: Test simple de cursor-agent
echo "Test 3: Test simple de cursor-agent"
echo "------------------------------------"
echo "Exécution: cursor-agent --print --model auto 'user: test'"
echo ""

START=$(date +%s)
TIMEOUT=30
docker exec "$CONTAINER_NAME" timeout $TIMEOUT cursor-agent --print --model auto "user: test" 2>&1 | head -10 || {
    END=$(date +%s)
    DURATION=$((END - START))
    if [ $DURATION -ge $TIMEOUT ]; then
        echo "❌ Timeout après ${TIMEOUT}s"
        echo "   cursor-agent ne répond pas dans le conteneur"
    else
        echo "❌ Erreur lors de l'exécution"
    fi
}
END=$(date +%s)
DURATION=$((END - START))
echo ""
echo "Temps d'exécution: ${DURATION}s"
echo ""

# Test 4: Vérifier la connectivité réseau
echo "Test 4: Vérification de la connectivité réseau"
echo "-----------------------------------------------"
if docker exec "$CONTAINER_NAME" curl -s --max-time 5 https://cursor.com > /dev/null 2>&1; then
    echo "✅ Connectivité réseau OK (cursor.com accessible)"
else
    echo "⚠️  Problème de connectivité réseau"
    echo "   Le conteneur ne peut peut-être pas accéder à cursor.com"
fi
echo ""

# Test 5: Vérifier les logs du conteneur
echo "Test 5: Dernières lignes des logs"
echo "----------------------------------"
echo "Dernières 20 lignes des logs:"
docker logs --tail 20 "$CONTAINER_NAME" 2>&1 | tail -20
echo ""

# Résumé
echo "===================================="
echo "📝 Résumé:"
echo "   Conteneur: $CONTAINER_NAME"
echo "   cursor-agent: $(docker exec "$CONTAINER_NAME" which cursor-agent 2>/dev/null || echo "NON TROUVÉ")"
echo "   CURSOR_API_KEY: $([ -n "$API_KEY" ] && echo "DÉFINIE" || echo "NON DÉFINIE")"
echo ""
echo "💡 Si cursor-agent ne fonctionne pas:"
echo "   1. Vérifiez que CURSOR_API_KEY est correcte"
echo "   2. Vérifiez la connectivité réseau du conteneur"
echo "   3. Reconstruisez l'image: just docker-build"
echo "   4. Vérifiez les logs: docker logs -f $CONTAINER_NAME"

