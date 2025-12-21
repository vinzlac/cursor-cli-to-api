#!/usr/bin/env bash
# Script pour rebuilder l'image Docker et redémarrer le conteneur (Docker simple, sans docker-compose)

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="cursor-openai-proxy"
IMAGE_TAG="latest"
CONTAINER_NAME="cursor-api-run-secure"
PORT=8001
HEALTH_CHECK_URL="http://localhost:${PORT}/health"
DEBUG_URL="http://localhost:${PORT}/debug/models"
MAX_WAIT_TIME=60  # Secondes à attendre pour que le service soit prêt

echo -e "${BLUE}🐳 Rebuild et redémarrage du conteneur Docker (mode simple)${NC}"
echo ""

# Vérifier que docker est disponible
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Erreur: docker n'est pas installé${NC}"
    exit 1
fi

# Vérifier que .env existe
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠️  Avertissement: Fichier .env non trouvé${NC}"
    echo "   Le conteneur peut ne pas démarrer correctement sans les variables d'environnement"
    read -p "   Continuer quand même? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Étape 1: Arrêter et supprimer le conteneur existant
echo -e "${BLUE}1️⃣  Arrêt et suppression du conteneur existant...${NC}"

# Arrêter le conteneur s'il existe
if docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "   Arrêt du conteneur ${CONTAINER_NAME}..."
    docker stop "${CONTAINER_NAME}" 2>/dev/null || true
    echo "   Suppression du conteneur ${CONTAINER_NAME}..."
    docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
    echo -e "${GREEN}   ✅ Conteneur supprimé${NC}"
else
    echo "   Aucun conteneur existant trouvé"
fi

# Vérifier et arrêter les conteneurs qui utilisent le port
echo "   Vérification des conteneurs utilisant le port ${PORT}..."
CONTAINERS_USING_PORT=$(docker ps -a --format "{{.ID}} {{.Names}} {{.Ports}}" | grep ":${PORT}" || true)
if [ -n "$CONTAINERS_USING_PORT" ]; then
    echo "   Conteneurs trouvés utilisant le port ${PORT}:"
    echo "$CONTAINERS_USING_PORT" | while read -r line; do
        CONTAINER_ID=$(echo "$line" | awk '{print $1}')
        CONTAINER_NAME_FOUND=$(echo "$line" | awk '{print $2}')
        echo "   - Arrêt et suppression de $CONTAINER_NAME_FOUND ($CONTAINER_ID)..."
        docker stop "$CONTAINER_ID" 2>/dev/null || true
        docker rm -f "$CONTAINER_ID" 2>/dev/null || true
    done
fi

# Vérifier les processus locaux utilisant le port
if command -v lsof &> /dev/null; then
    PID_USING_PORT=$(lsof -ti:${PORT} 2>/dev/null || true)
    if [ -n "$PID_USING_PORT" ]; then
        echo "   Processus local trouvé utilisant le port ${PORT} (PID: $PID_USING_PORT)"
        echo "   ⚠️  Arrêt du processus local..."
        kill -9 $PID_USING_PORT 2>/dev/null || true
        sleep 1
    fi
fi

# Attendre un peu pour que les ports soient libérés
sleep 2

# Vérifier que le port est libre
if command -v lsof &> /dev/null; then
    if lsof -ti:${PORT} > /dev/null 2>&1; then
        echo -e "${YELLOW}   ⚠️  Le port ${PORT} est toujours utilisé${NC}"
        echo "   Vous devrez peut-être arrêter manuellement le processus"
    else
        echo -e "${GREEN}   ✅ Port ${PORT} libre${NC}"
    fi
fi

echo -e "${GREEN}   ✅ Nettoyage terminé${NC}"
echo ""

# Étape 2: Rebuild de l'image (sans cache pour forcer la reconstruction)
echo -e "${BLUE}2️⃣  Reconstruction de l'image Docker...${NC}"
echo "   (Cela peut prendre plusieurs minutes)"
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .
echo -e "${GREEN}   ✅ Image reconstruite${NC}"
echo ""

# Étape 3: Charger les variables d'environnement depuis .env
echo -e "${BLUE}3️⃣  Chargement des variables d'environnement...${NC}"
if [ -f .env ]; then
    # Charger les variables principales depuis .env
    export CURSOR_API_KEY=$(grep "^CURSOR_API_KEY=" .env | cut -d= -f2- | tr -d '"' | tr -d "'" || echo "")
    export API_KEY=$(grep "^API_KEY=" .env | cut -d= -f2- | tr -d '"' | tr -d "'" || echo "")
    export CURSOR_AGENT_MODE=$(grep "^CURSOR_AGENT_MODE=" .env | cut -d= -f2- | tr -d '"' | tr -d "'" || echo "cli")
    export CURSOR_AGENT_TIMEOUT=$(grep "^CURSOR_AGENT_TIMEOUT=" .env | cut -d= -f2- | tr -d '"' | tr -d "'" || echo "120")
    export LOG_LEVEL=$(grep "^LOG_LEVEL=" .env | cut -d= -f2- | tr -d '"' | tr -d "'" || echo "INFO")
    echo -e "${GREEN}   ✅ Variables d'environnement chargées${NC}"
else
    echo -e "${YELLOW}   ⚠️  Fichier .env non trouvé, utilisation des valeurs par défaut${NC}"
    # Valeurs par défaut
    CURSOR_AGENT_MODE=${CURSOR_AGENT_MODE:-cli}
    CURSOR_AGENT_TIMEOUT=${CURSOR_AGENT_TIMEOUT:-120}
    LOG_LEVEL=${LOG_LEVEL:-INFO}
fi

echo ""

# Étape 4: Démarrer le conteneur
echo -e "${BLUE}4️⃣  Démarrage du conteneur...${NC}"
docker run -d \
    --name "${CONTAINER_NAME}" \
    -p ${PORT}:${PORT} \
    -e CURSOR_API_KEY="${CURSOR_API_KEY}" \
    -e API_KEY="${API_KEY}" \
    -e CURSOR_AGENT_MODE="${CURSOR_AGENT_MODE}" \
    -e CURSOR_AGENT_CLI_PATH="${CURSOR_AGENT_CLI_PATH:-cursor-agent}" \
    -e CURSOR_AGENT_HTTP_URL="${CURSOR_AGENT_HTTP_URL:-}" \
    -e CURSOR_AGENT_TIMEOUT="${CURSOR_AGENT_TIMEOUT}" \
    -e LOG_LEVEL="${LOG_LEVEL}" \
    -e HOST=0.0.0.0 \
    -e PORT=${PORT} \
    -e RELOAD=false \
    --restart unless-stopped \
    "${IMAGE_NAME}:${IMAGE_TAG}"

echo -e "${GREEN}   ✅ Conteneur démarré${NC}"
echo ""

# Étape 5: Attendre que le service soit prêt
echo -e "${BLUE}5️⃣  Attente que le service soit prêt...${NC}"
WAIT_TIME=0
while [ $WAIT_TIME -lt $MAX_WAIT_TIME ]; do
    if curl -s -f "$HEALTH_CHECK_URL" > /dev/null 2>&1; then
        echo -e "${GREEN}   ✅ Service prêt après ${WAIT_TIME}s${NC}"
        break
    fi
    echo -n "."
    sleep 2
    WAIT_TIME=$((WAIT_TIME + 2))
done

if [ $WAIT_TIME -ge $MAX_WAIT_TIME ]; then
    echo -e "${RED}   ❌ Timeout: Le service n'est pas prêt après ${MAX_WAIT_TIME}s${NC}"
    echo ""
    echo -e "${YELLOW}📋 Affichage des logs pour diagnostic:${NC}"
    docker logs --tail=50 "${CONTAINER_NAME}"
    exit 1
fi
echo ""

# Étape 6: Afficher les logs récents
echo -e "${BLUE}6️⃣  Logs récents du conteneur:${NC}"
docker logs --tail=20 "${CONTAINER_NAME}"
echo ""

# Étape 7: Tester l'endpoint de santé
echo -e "${BLUE}7️⃣  Test de l'endpoint de santé...${NC}"
HEALTH_RESPONSE=$(curl -s "$HEALTH_CHECK_URL" 2>/dev/null || echo "")
if echo "$HEALTH_RESPONSE" | grep -q "ok"; then
    echo -e "${GREEN}   ✅ Health check réussi${NC}"
    echo "   Réponse: $HEALTH_RESPONSE"
else
    echo -e "${YELLOW}   ⚠️  Health check: Réponse inattendue${NC}"
    echo "   Réponse: $HEALTH_RESPONSE"
fi
echo ""

# Étape 8: Tester l'endpoint de debug (si disponible)
echo -e "${BLUE}8️⃣  Test de l'endpoint de debug...${NC}"
DEBUG_RESPONSE=$(curl -s "$DEBUG_URL" 2>/dev/null || echo "")
if echo "$DEBUG_RESPONSE" | grep -q "timestamp"; then
    echo -e "${GREEN}   ✅ Endpoint /debug/models accessible${NC}"
    echo "   (Utilisez 'curl $DEBUG_URL | jq' pour voir les détails)"
else
    echo -e "${YELLOW}   ⚠️  Endpoint /debug/models non disponible ou nécessite authentification${NC}"
    echo "   Réponse: ${DEBUG_RESPONSE:0:100}..."
fi
echo ""

# Résumé
echo -e "${GREEN}✅ Rebuild et redémarrage terminés avec succès!${NC}"
echo ""
echo -e "${BLUE}📋 Commandes utiles:${NC}"
echo "   Voir les logs:        docker logs -f ${CONTAINER_NAME}"
echo "   Arrêter:             docker stop ${CONTAINER_NAME}"
echo "   Supprimer:           docker rm -f ${CONTAINER_NAME}"
echo "   Redémarrer:          docker restart ${CONTAINER_NAME}"
echo "   Tester health:        curl ${HEALTH_CHECK_URL}"
echo "   Tester debug:        curl ${DEBUG_URL} | jq"
echo ""

