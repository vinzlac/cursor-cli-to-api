#!/usr/bin/env bash
# Script pour rebuilder l'image Docker et redémarrer le conteneur

set -e

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.yml"
SERVICE_NAME="api"
HEALTH_CHECK_URL="http://localhost:8001/health"
DEBUG_URL="http://localhost:8001/debug/models"
MAX_WAIT_TIME=60  # Secondes à attendre pour que le service soit prêt

echo -e "${BLUE}🐳 Rebuild et redémarrage du conteneur Docker${NC}"
echo ""

# Vérifier que docker-compose est disponible
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Erreur: docker-compose n'est pas installé${NC}"
    exit 1
fi

# Utiliser docker compose (nouvelle version) si disponible, sinon docker-compose
if docker compose version &> /dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
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

# Étape 1: Arrêter tous les conteneurs existants
echo -e "${BLUE}1️⃣  Arrêt des conteneurs existants...${NC}"

# Arrêter et supprimer avec docker-compose (--remove-orphans pour nettoyer les conteneurs orphelins)
# Utiliser -v pour supprimer aussi les volumes et --remove-orphans pour les conteneurs orphelins
$DOCKER_COMPOSE -f "$COMPOSE_FILE" down -v --remove-orphans 2>/dev/null || true

# Supprimer spécifiquement le service api s'il existe
$DOCKER_COMPOSE -f "$COMPOSE_FILE" rm -sf "$SERVICE_NAME" 2>/dev/null || true

# Supprimer les conteneurs arrêtés du projet
$DOCKER_COMPOSE -f "$COMPOSE_FILE" rm -f 2>/dev/null || true

# Vérifier et arrêter les conteneurs qui utilisent le port 8001 ou appartiennent au projet
echo "   Vérification des conteneurs du projet..."
CONTAINERS_TO_REMOVE=$(docker ps -a --format "{{.ID}} {{.Names}}" | grep -E "8001|cursor-cli-to-api|1d6ae864ecec" || true)
if [ -n "$CONTAINERS_TO_REMOVE" ]; then
    echo "   Conteneurs trouvés à supprimer:"
    echo "$CONTAINERS_TO_REMOVE" | while read -r line; do
        CONTAINER_ID=$(echo "$line" | awk '{print $1}')
        CONTAINER_NAME=$(echo "$line" | awk '{print $2}')
        echo "   - Suppression de $CONTAINER_NAME ($CONTAINER_ID)..."
        docker stop "$CONTAINER_ID" 2>/dev/null || true
        docker rm -f "$CONTAINER_ID" 2>/dev/null || true
    done
fi

# Supprimer tous les conteneurs du projet par nom de service
echo "   Suppression des conteneurs par nom de service..."
docker ps -a --filter "name=${SERVICE_NAME}" --format "{{.ID}}" | while read -r container_id; do
    if [ -n "$container_id" ]; then
        echo "   - Suppression du conteneur $container_id..."
        docker rm -f "$container_id" 2>/dev/null || true
    fi
done

# Nettoyer les réseaux orphelins
docker network prune -f 2>/dev/null || true

# Vérifier les processus locaux utilisant le port 8001
if command -v lsof &> /dev/null; then
    PID_USING_PORT=$(lsof -ti:8001 2>/dev/null || true)
    if [ -n "$PID_USING_PORT" ]; then
        echo "   Processus local trouvé utilisant le port 8001 (PID: $PID_USING_PORT)"
        echo "   ⚠️  Arrêt du processus local..."
        kill -9 $PID_USING_PORT 2>/dev/null || true
        sleep 1
    fi
fi

# Attendre un peu pour que les ports soient libérés
sleep 2

# Vérifier que le port est libre
if command -v lsof &> /dev/null; then
    if lsof -ti:8001 > /dev/null 2>&1; then
        echo -e "${YELLOW}   ⚠️  Le port 8001 est toujours utilisé${NC}"
        echo "   Vous devrez peut-être arrêter manuellement le processus"
    else
        echo -e "${GREEN}   ✅ Port 8001 libre${NC}"
    fi
fi

echo -e "${GREEN}   ✅ Nettoyage terminé${NC}"
echo ""

# Étape 2: Rebuild de l'image (sans cache pour forcer la reconstruction)
echo -e "${BLUE}2️⃣  Reconstruction de l'image Docker...${NC}"
echo "   (Cela peut prendre plusieurs minutes)"
$DOCKER_COMPOSE -f "$COMPOSE_FILE" build --no-cache
echo -e "${GREEN}   ✅ Image reconstruite${NC}"
echo ""

# Étape 3: Démarrer le conteneur (avec --force-recreate pour forcer la recréation)
echo -e "${BLUE}3️⃣  Démarrage du conteneur...${NC}"

# Vérifier une dernière fois qu'il n'y a pas de conteneurs orphelins
ORPHANED_CONTAINERS=$(docker ps -a --filter "name=cursor-cli-to-api" --format "{{.ID}}" || true)
if [ -n "$ORPHANED_CONTAINERS" ]; then
    echo "   Suppression des conteneurs orphelins restants..."
    echo "$ORPHANED_CONTAINERS" | while read -r container_id; do
        docker rm -f "$container_id" 2>/dev/null || true
    done
    sleep 1
fi

# Démarrer avec force-recreate et remove-orphans
$DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d --force-recreate --remove-orphans --no-deps
echo -e "${GREEN}   ✅ Conteneur démarré${NC}"
echo ""

# Étape 4: Attendre que le service soit prêt
echo -e "${BLUE}4️⃣  Attente que le service soit prêt...${NC}"
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
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" logs --tail=50
    exit 1
fi
echo ""

# Étape 5: Afficher les logs récents
echo -e "${BLUE}5️⃣  Logs récents du conteneur:${NC}"
$DOCKER_COMPOSE -f "$COMPOSE_FILE" logs --tail=20
echo ""

# Étape 6: Tester l'endpoint de santé
echo -e "${BLUE}6️⃣  Test de l'endpoint de santé...${NC}"
HEALTH_RESPONSE=$(curl -s "$HEALTH_CHECK_URL" 2>/dev/null || echo "")
if echo "$HEALTH_RESPONSE" | grep -q "ok"; then
    echo -e "${GREEN}   ✅ Health check réussi${NC}"
    echo "   Réponse: $HEALTH_RESPONSE"
else
    echo -e "${YELLOW}   ⚠️  Health check: Réponse inattendue${NC}"
    echo "   Réponse: $HEALTH_RESPONSE"
fi
echo ""

# Étape 7: Tester l'endpoint de debug (si disponible)
echo -e "${BLUE}7️⃣  Test de l'endpoint de debug...${NC}"
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
echo "   Voir les logs:        $DOCKER_COMPOSE -f $COMPOSE_FILE logs -f"
echo "   Arrêter:              $DOCKER_COMPOSE -f $COMPOSE_FILE down"
echo "   Redémarrer:           $DOCKER_COMPOSE -f $COMPOSE_FILE restart"
echo "   Tester health:        curl $HEALTH_CHECK_URL"
echo "   Tester debug:         curl $DEBUG_URL | jq"
echo ""

