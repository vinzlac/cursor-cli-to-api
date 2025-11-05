# Justfile pour cursor-cli-to-api
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

# Lance les tests d'intégration
test-integration:
    @echo "🔗 Lancement des tests d'intégration..."
    @./scripts/test_integration.sh

# Build l'image Docker
docker-build:
    @echo "🐳 Construction de l'image Docker..."
    docker build -t cursor-cli-to-api:latest .

# Lance avec Docker Compose
docker-up:
    @echo "🚀 Démarrage avec Docker Compose..."
    docker-compose up -d

# Arrête Docker Compose
docker-down:
    @echo "🛑 Arrêt de Docker Compose..."
    docker-compose down

# Voir les logs Docker
docker-logs:
    @echo "📋 Logs Docker..."
    docker-compose logs -f
