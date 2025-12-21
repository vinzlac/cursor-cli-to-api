# Justfile pour cursor-openai-proxy
# Command runner moderne pour gérer les tâches du projet

# Affiche l'aide avec toutes les commandes disponibles
default:
    @just --list

# Installe les dépendances avec uv
install:
    @echo "📦 Installation des dépendances avec uv..."
    uv sync

# Démarre le serveur en mode production
run:
    @echo "🚀 Démarrage du serveur..."
    uv run uvicorn main:app --host 0.0.0.0 --port 8001

# Démarre le serveur en mode développement avec reload automatique
dev:
    @echo "🔧 Démarrage en mode développement..."
    uv run uvicorn main:app --host 0.0.0.0 --port 8001 --reload

# Démarre le serveur en arrière-plan (daemon)
start:
    #!/usr/bin/env bash
    echo "🚀 Démarrage du serveur en arrière-plan..."
    if pgrep -f "uvicorn main:app" > /dev/null; then
        echo "⚠️  Un serveur est déjà en cours d'exécution"
        echo "   Utilisez 'just stop' pour l'arrêter d'abord"
        exit 1
    fi
    nohup uv run uvicorn main:app --host 0.0.0.0 --port 8001 > server.log 2>&1 &
    sleep 2
    if pgrep -f "uvicorn main:app" > /dev/null; then
        echo "✅ Serveur démarré en arrière-plan"
        echo "   PID: $(pgrep -f "uvicorn main:app")"
        echo "   Logs: tail -f server.log"
        echo "   Status: just status"
        echo "   Arrêter: just stop"
    else
        echo "❌ Échec du démarrage, voir server.log"
        exit 1
    fi

# Arrête le serveur en cours d'exécution
stop:
    @echo "🛑 Arrêt du serveur..."
    @pkill -f "uvicorn main:app" 2>/dev/null && echo "✅ Serveur arrêté" || echo "⚠️  Aucun serveur en cours d'exécution"

# Affiche les logs du serveur en temps réel
logs:
    @echo "📜 Logs du serveur (Ctrl+C pour quitter):"
    @if [ -f server.log ]; then tail -f server.log; else echo "❌ Fichier server.log introuvable. Le serveur est-il démarré avec 'just start' ?"; fi

# Vérifie l'état du serveur
status:
    #!/usr/bin/env bash
    echo "📊 État du serveur:"
    echo ""
    if pgrep -f "uvicorn main:app" > /dev/null; then
        echo "  Status: ✅ EN COURS D'EXÉCUTION"
        echo "  PID: $(pgrep -f "uvicorn main:app" | tr '\n' ' ')"
        echo "  Port: 8001"
        echo ""
        if curl -s http://localhost:8001/health > /dev/null 2>&1; then
            echo "  Santé: ✅ Le serveur répond correctement"
            echo "  URL: http://localhost:8001"
            echo "  Docs: http://localhost:8001/docs"
        else
            echo "  Santé: ⚠️  Le processus existe mais ne répond pas"
        fi
    else
        echo "  Status: ❌ ARRÊTÉ"
        echo ""
        echo "  Pour démarrer: just dev  ou  just run"
    fi

# Lance les tests
test:
    @echo "🧪 Lancement des tests..."
    uv run pytest

# Lance les tests avec couverture
test-cov:
    @echo "📊 Lancement des tests avec couverture..."
    uv run pytest --cov=. --cov-report=html --cov-report=term

# Lance les tests en mode watch
test-watch:
    @echo "👀 Lancement des tests en mode watch..."
    uv run ptw tests || echo "⚠️  pytest-watch non disponible: uv pip install pytest-watch"

# Lance les tests d'intégration bash/curl (nécessite un serveur déjà lancé)
test-integration-curl:
    @echo "🧪 Lancement des tests d'intégration (bash/curl)..."
    @./scripts/test_integration.sh

# Lance les tests d'intégration LOCAUX (Python uniquement, port 8001)
test-integration-local:
    #!/usr/bin/env bash
    echo "🧪 Tests d'intégration LOCAUX (Python, port 8001)"
    echo "   Le serveur sera lancé automatiquement"
    echo ""
    if [ -f .env ]; then
        export $(grep "^API_KEY=" .env | xargs)
        export $(grep "^CURSOR_API_KEY=" .env | xargs)
    fi
    if [ -z "$API_KEY" ]; then
        echo "⚠️  API_KEY non trouvée dans .env"
        echo "   Les tests d'authentification seront ignorés."
    fi
    if [ -z "$CURSOR_API_KEY" ]; then
        echo "⚠️  CURSOR_API_KEY non trouvée dans .env"
        echo "   Les tests seront ignorés."
    fi
    echo ""
    uv run pytest tests/test_integration_local.py -v -s

# Lance les tests d'intégration DOCKER (avec Docker Compose, port 8002)
test-integration-docker:
    #!/usr/bin/env bash
    echo "🧪 Tests d'intégration DOCKER (port 8002)"
    echo "   Docker Compose sera lancé automatiquement"
    echo ""
    if [ -f .env ]; then
        export $(grep "^API_KEY=" .env | xargs)
        export $(grep "^CURSOR_API_KEY=" .env | xargs)
    fi
    if [ -z "$API_KEY" ]; then
        echo "⚠️  API_KEY non trouvée dans .env"
    fi
    if [ -z "$CURSOR_API_KEY" ]; then
        echo "⚠️  CURSOR_API_KEY non trouvée dans .env"
    fi
    echo ""
    uv run pytest tests/test_integration_docker.py -v -s

# Lance tous les tests d'intégration (local + docker)
test-integration-all: test-integration-local test-integration-docker
    @echo ""
    @echo "✅ Tous les tests d'intégration terminés!"

# Lance TOUS les tests (unitaires + intégration local + intégration docker)
test-all: test test-integration-local test-integration-docker
    @echo ""
    @echo "╔════════════════════════════════════════════════════════════════╗"
    @echo "║                                                                ║"
    @echo "║            ✅ TOUS LES TESTS TERMINÉS AVEC SUCCÈS ! 🎉        ║"
    @echo "║                                                                ║"
    @echo "╔════════════════════════════════════════════════════════════════╝"

# Nettoie les fichiers générés (cache, venv, etc.)
clean:
    @echo "🧹 Nettoyage des fichiers générés..."
    rm -rf .venv
    rm -rf __pycache__
    rm -rf .pytest_cache
    rm -rf .coverage
    rm -rf htmlcov
    find . -type d -name "*.egg-info" -exec rm -r {} + 2>/dev/null || true
    find . -type f -name "*.pyc" -delete
    find . -type f -name "*.pyo" -delete

# Formate le code avec ruff (si installé)
format:
    @echo "✨ Formatage du code..."
    uv run ruff format . || echo "⚠️  ruff non disponible, utilisez: uv pip install ruff"

# Vérifie le code avec ruff (si installé)
lint:
    @echo "🔍 Vérification du code..."
    uv run ruff check . || echo "⚠️  ruff non disponible, utilisez: uv pip install ruff"

# Lance format + lint
check: format lint
    @echo "✅ Vérification terminée"

# Ouvre la documentation API dans le navigateur
docs:
    @echo "📚 Ouverture de la documentation..."
    @open http://localhost:8001/docs || xdg-open http://localhost:8001/docs || echo "Serveur non démarré ou navigateur non disponible"

# Crée un nouvel environnement virtuel
venv:
    @echo "🐍 Création de l'environnement virtuel..."
    uv venv

# Affiche les informations sur l'environnement
info:
    #!/usr/bin/env bash
    echo "ℹ️  Informations sur l'environnement:"
    echo "Python: $(uv run python --version)"
    echo "uv: $(uv --version)"
    if [ -d .venv ]; then echo "Venv: ✅ Créé"; else echo "Venv: ❌ Non créé"; fi

# Installe les dépendances de développement
install-dev:
    @echo "🔧 Installation des dépendances de développement..."
    uv sync --dev

# Exécute l'exemple d'utilisation
example:
    @echo "🎯 Exécution de l'exemple..."
    uv run python example_usage.py

# Vérifie que le serveur est accessible
health:
    @echo "🏥 Vérification de santé..."
    @curl -s http://localhost:8001/health | jq . || echo "❌ Serveur non accessible"

# Configure le fichier .env de manière interactive
setup-env:
    @echo "⚙️  Configuration du fichier .env..."
    @./scripts/setup-env.sh

# Configure le token CURSOR_API_KEY dans .env (pour Docker)
update-cursor-token:
    @echo "🔑 Configuration du token Cursor pour Docker..."
    @./scripts/update-cursor-token.sh

# Build l'image Docker
docker-build:
    @echo "🐳 Construction de l'image Docker..."
    docker build -t cursor-openai-proxy:latest .

# Build l'image Docker avec tag basé sur la version de cursor-agent et le hash git
docker-build-tagged:
    @echo "🐳 Construction de l'image Docker avec tag personnalisé..."
    @./scripts/docker-build-tagged.sh

# Lance avec Docker Compose
docker-up:
    @echo "🚀 Démarrage avec Docker Compose..."
    docker-compose up -d

# Lance Docker Compose en mode SÉCURISÉ (avec API_KEY)
docker-compose-secure:
    #!/usr/bin/env bash
    echo "🔒 Démarrage Docker Compose en mode SÉCURISÉ (avec API_KEY)..."
    if [ ! -f .env ]; then
        echo "❌ Fichier .env non trouvé"
        exit 1
    fi
    # Charger uniquement les variables nécessaires depuis .env
    # NE PAS utiliser env_file dans docker-compose pour éviter d'exposer tout le .env
    export CURSOR_API_KEY=$(grep "^CURSOR_API_KEY=" .env | cut -d= -f2- | tr -d '"' | tr -d "'")
    export API_KEY=$(grep "^API_KEY=" .env | cut -d= -f2- | tr -d '"' | tr -d "'")
    export CURSOR_AGENT_MODE=${CURSOR_AGENT_MODE:-cli}
    export LOG_LEVEL=${LOG_LEVEL:-INFO}
    
    if [ -z "$CURSOR_API_KEY" ]; then
        echo "⚠️  CURSOR_API_KEY non trouvée dans .env"
    fi
    if [ -z "$API_KEY" ]; then
        echo "⚠️  API_KEY non trouvée dans .env"
        echo "   L'API sera accessible sans authentification"
    fi
    
    docker-compose -f docker-compose.secure.yml up -d
    
    echo "✅ Docker Compose lancé en mode sécurisé"
    echo "   Fichier: docker-compose.secure.yml"
    echo "   Port: 8001"
    echo "   API nécessite: Authorization: Bearer <API_KEY>"
    echo ""
    echo "💡 Commandes utiles:"
    echo "   docker-compose -f docker-compose.secure.yml logs -f"
    echo "   docker-compose -f docker-compose.secure.yml down"

# Lance Docker Compose en mode NON SÉCURISÉ (sans API_KEY)
docker-compose-insecure:
    #!/usr/bin/env bash
    echo "🔓 Démarrage Docker Compose en mode NON SÉCURISÉ (sans API_KEY)..."
    if [ ! -f .env ]; then
        echo "❌ Fichier .env non trouvé"
        exit 1
    fi
    # Charger uniquement CURSOR_API_KEY depuis .env (pas API_KEY)
    # NE PAS utiliser env_file dans docker-compose pour éviter d'exposer tout le .env
    export CURSOR_API_KEY=$(grep "^CURSOR_API_KEY=" .env | cut -d= -f2- | tr -d '"' | tr -d "'")
    export CURSOR_AGENT_MODE=${CURSOR_AGENT_MODE:-cli}
    export CURSOR_AGENT_TIMEOUT=${CURSOR_AGENT_TIMEOUT:-120}
    export LOG_LEVEL=${LOG_LEVEL:-INFO}
    
    if [ -z "$CURSOR_API_KEY" ]; then
        echo "⚠️  CURSOR_API_KEY non trouvée dans .env"
    fi
    
    docker-compose -f docker-compose.insecure.yml up -d
    
    echo "✅ Docker Compose lancé en mode non sécurisé"
    echo "   Fichier: docker-compose.insecure.yml"
    echo "   Port: 8001"
    echo "   ⚠️  API accessible SANS authentification"
    echo ""
    echo "💡 Commandes utiles:"
    echo "   docker-compose -f docker-compose.insecure.yml logs -f"
    echo "   docker-compose -f docker-compose.insecure.yml down"

# Arrête Docker Compose
docker-down:
    @echo "🛑 Arrêt de Docker Compose..."
    docker-compose down

# Arrête Docker Compose (mode sécurisé)
docker-compose-down-secure:
    @echo "🛑 Arrêt de Docker Compose (mode sécurisé)..."
    docker-compose -f docker-compose.secure.yml down

# Arrête Docker Compose (mode non sécurisé)
docker-compose-down-insecure:
    @echo "🛑 Arrêt de Docker Compose (mode non sécurisé)..."
    docker-compose -f docker-compose.insecure.yml down

# Voir les logs Docker
docker-logs:
    @echo "📋 Logs Docker..."
    docker-compose logs -f

# Voir les logs Docker Compose (mode sécurisé)
docker-compose-logs-secure:
    @echo "📋 Logs Docker Compose (mode sécurisé)..."
    docker-compose -f docker-compose.secure.yml logs -f

# Voir les logs Docker Compose (mode non sécurisé)
docker-compose-logs-insecure:
    @echo "📋 Logs Docker Compose (mode non sécurisé)..."
    docker-compose -f docker-compose.insecure.yml logs -f

# ============================================================================
# Docker Run (sans docker-compose)
# ============================================================================

# Lance Docker Run en mode SÉCURISÉ (avec API_KEY)
docker-run-secure:
    #!/usr/bin/env bash
    echo "🔒 Démarrage Docker Run en mode SÉCURISÉ (avec API_KEY)..."
    if [ ! -f .env ]; then
        echo "❌ Fichier .env non trouvé"
        exit 1
    fi
    # Charger uniquement les variables nécessaires depuis .env
    export CURSOR_API_KEY=$(grep "^CURSOR_API_KEY=" .env | cut -d= -f2- | tr -d '"' | tr -d "'")
    export API_KEY=$(grep "^API_KEY=" .env | cut -d= -f2- | tr -d '"' | tr -d "'")
    export CURSOR_AGENT_MODE=${CURSOR_AGENT_MODE:-cli}
    export LOG_LEVEL=${LOG_LEVEL:-INFO}
    
    if [ -z "$CURSOR_API_KEY" ]; then
        echo "⚠️  CURSOR_API_KEY non trouvée dans .env"
    fi
    if [ -z "$API_KEY" ]; then
        echo "⚠️  API_KEY non trouvée dans .env"
        echo "   L'API sera accessible sans authentification"
    fi
    
    # Arrêter et supprimer le conteneur existant s'il existe
    docker stop cursor-api-run-secure 2>/dev/null || true
    docker rm cursor-api-run-secure 2>/dev/null || true
    
    docker run -d \
        --name cursor-api-run-secure \
        -p 8001:8001 \
        -e CURSOR_API_KEY="$CURSOR_API_KEY" \
        -e API_KEY="$API_KEY" \
        -e CURSOR_AGENT_MODE="$CURSOR_AGENT_MODE" \
        -e CURSOR_AGENT_TIMEOUT="${CURSOR_AGENT_TIMEOUT:-120}" \
        -e LOG_LEVEL="$LOG_LEVEL" \
        -e HOST=0.0.0.0 \
        -e PORT=8001 \
        -e RELOAD=false \
        --restart unless-stopped \
        cursor-openai-proxy:latest
    
    echo "✅ Conteneur Docker Run lancé en mode sécurisé"
    echo "   Nom: cursor-api-run-secure"
    echo "   Port: 8001"
    echo "   API nécessite: Authorization: Bearer <API_KEY>"
    echo ""
    echo "💡 Commandes utiles:"
    echo "   docker logs -f cursor-api-run-secure"
    echo "   docker stop cursor-api-run-secure"
    echo "   docker rm cursor-api-run-secure"

# Lance Docker Run en mode NON SÉCURISÉ (sans API_KEY)
docker-run-insecure:
    #!/usr/bin/env bash
    echo "🔓 Démarrage Docker Run en mode NON SÉCURISÉ (sans API_KEY)..."
    if [ ! -f .env ]; then
        echo "❌ Fichier .env non trouvé"
        exit 1
    fi
    # Charger uniquement CURSOR_API_KEY depuis .env (pas API_KEY)
    export CURSOR_API_KEY=$(grep "^CURSOR_API_KEY=" .env | cut -d= -f2- | tr -d '"' | tr -d "'")
    export CURSOR_AGENT_MODE=${CURSOR_AGENT_MODE:-cli}
    export CURSOR_AGENT_TIMEOUT=${CURSOR_AGENT_TIMEOUT:-120}
    export LOG_LEVEL=${LOG_LEVEL:-INFO}
    
    if [ -z "$CURSOR_API_KEY" ]; then
        echo "⚠️  CURSOR_API_KEY non trouvée dans .env"
    fi
    
    # Arrêter et supprimer le conteneur existant s'il existe
    docker stop cursor-api-run-insecure 2>/dev/null || true
    docker rm cursor-api-run-insecure 2>/dev/null || true
    
    docker run -d \
        --name cursor-api-run-insecure \
        -p 8001:8001 \
        -e CURSOR_API_KEY="$CURSOR_API_KEY" \
        -e CURSOR_AGENT_MODE="$CURSOR_AGENT_MODE" \
        -e CURSOR_AGENT_TIMEOUT="${CURSOR_AGENT_TIMEOUT:-120}" \
        -e LOG_LEVEL="$LOG_LEVEL" \
        -e HOST=0.0.0.0 \
        -e PORT=8001 \
        -e RELOAD=false \
        --restart unless-stopped \
        cursor-openai-proxy:latest
    
    echo "✅ Conteneur Docker Run lancé en mode non sécurisé"
    echo "   Nom: cursor-api-run-insecure"
    echo "   Port: 8001"
    echo "   ⚠️  API accessible SANS authentification"
    echo ""
    echo "💡 Commandes utiles:"
    echo "   docker logs -f cursor-api-run-insecure"
    echo "   docker stop cursor-api-run-insecure"
    echo "   docker rm cursor-api-run-insecure"

# Arrête Docker Run (mode sécurisé)
docker-run-down-secure:
    @echo "🛑 Arrêt de Docker Run (mode sécurisé)..."
    @docker stop cursor-api-run-secure 2>/dev/null || true
    @docker rm cursor-api-run-secure 2>/dev/null || true
    @echo "✅ Conteneur arrêté et supprimé"

# Arrête Docker Run (mode non sécurisé)
docker-run-down-insecure:
    @echo "🛑 Arrêt de Docker Run (mode non sécurisé)..."
    @docker stop cursor-api-run-insecure 2>/dev/null || true
    @docker rm cursor-api-run-insecure 2>/dev/null || true
    @echo "✅ Conteneur arrêté et supprimé"

# Arrête tous les conteneurs Docker Run
docker-run-down:
    @echo "🛑 Arrêt de tous les conteneurs Docker Run..."
    @docker stop cursor-api-run-secure cursor-api-run-insecure 2>/dev/null || true
    @docker rm cursor-api-run-secure cursor-api-run-insecure 2>/dev/null || true
    @echo "✅ Tous les conteneurs arrêtés et supprimés"

# Voir les logs Docker Run (mode sécurisé)
docker-run-logs-secure:
    @echo "📋 Logs Docker Run (mode sécurisé)..."
    @docker logs -f cursor-api-run-secure

# Voir les logs Docker Run (mode non sécurisé)
docker-run-logs-insecure:
    @echo "📋 Logs Docker Run (mode non sécurisé)..."
    @docker logs -f cursor-api-run-insecure

# Tester les performances
test-performance:
    @echo "⚡ Test de performance..."
    @./scripts/test-performance.sh

# Diagnostic Docker
docker-diagnose:
    @echo "🔍 Diagnostic Docker..."
    @./scripts/docker-diagnose.sh

# Tester cursor-agent dans Docker
docker-test-cursor:
    @echo "🧪 Test cursor-agent dans Docker..."
    @./scripts/docker-test-cursor.sh

# Vérifier le mode HTTP
test-http-mode:
    @echo "🔍 Vérification du mode HTTP..."
    @./scripts/test-http-mode.sh

# Tester cursor-agent en CLI direct
test-cli-direct:
    @echo "⚡ Test de performance cursor-agent CLI direct..."
    @./scripts/test-cli-direct.sh

# Tester les processus persistants
test-persistent:
    @echo "🧪 Test de processus persistant cursor-agent..."
    @./scripts/test-persistent-process.sh

# Tester les sessions avec --resume
test-sessions:
    @echo "🧪 Test des sessions cursor-agent..."
    @./scripts/test-chat-session.sh

# Comparer les performances --resume vs nouveau chat
test-resume-perf:
    @echo "⚡ Test de performance --resume vs nouveau chat..."
    @./scripts/test-resume-performance.sh
