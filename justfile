# Justfile pour cursor-cli-to-api
# Command runner moderne pour g?rer les t?ches du projet

# Affiche l'aide avec toutes les commandes disponibles
default:
    @just --list

# Installe les d?pendances avec uv
install:
    @echo "?? Installation des d?pendances avec uv..."
    uv sync

# D?marre le serveur en mode production
run:
    @echo "?? D?marrage du serveur..."
    uv run uvicorn main:app --host 0.0.0.0 --port 8000

# D?marre le serveur en mode d?veloppement avec reload automatique
dev:
    @echo "?? D?marrage en mode d?veloppement..."
    uv run uvicorn main:app --host 0.0.0.0 --port 8000 --reload

# Lance les tests
test:
    @echo "?? Lancement des tests..."
    uv run pytest

# Lance les tests avec couverture
test-cov:
    @echo "?? Lancement des tests avec couverture..."
    uv run pytest --cov=. --cov-report=html --cov-report=term

# Lance les tests en mode watch
test-watch:
    @echo "?? Lancement des tests en mode watch..."
    uv run ptw tests || echo "??  pytest-watch non disponible: uv pip install pytest-watch"

# Nettoie les fichiers g?n?r?s (cache, venv, etc.)
clean:
    @echo "?? Nettoyage des fichiers g?n?r?s..."
    rm -rf .venv
    rm -rf __pycache__
    rm -rf .pytest_cache
    rm -rf .coverage
    rm -rf htmlcov
    find . -type d -name "*.egg-info" -exec rm -r {} + 2>/dev/null || true
    find . -type f -name "*.pyc" -delete
    find . -type f -name "*.pyo" -delete

# Formate le code avec ruff (si install?)
format:
    @echo "? Formatage du code..."
    uv run ruff format . || echo "??  ruff non disponible, utilisez: uv pip install ruff"

# V?rifie le code avec ruff (si install?)
lint:
    @echo "?? V?rification du code..."
    uv run ruff check . || echo "??  ruff non disponible, utilisez: uv pip install ruff"

# Lance format + lint
check: format lint
    @echo "? V?rification termin?e"

# Ouvre la documentation API dans le navigateur
docs:
    @echo "?? Ouverture de la documentation..."
    @open http://localhost:8000/docs || xdg-open http://localhost:8000/docs || echo "Serveur non d?marr? ou navigateur non disponible"

# Cr?e un nouvel environnement virtuel
venv:
    @echo "?? Cr?ation de l'environnement virtuel..."
    uv venv

# Affiche les informations sur l'environnement
info:
    @echo "?? Informations sur l'environnement:"
    @echo "Python: $$(uv run python --version)"
    @echo "uv: $$(uv --version)"
    @echo "Venv: $$([ -d .venv ] && echo '? Cr??' || echo '? Non cr??')"

# Installe les d?pendances de d?veloppement
install-dev:
    @echo "?? Installation des d?pendances de d?veloppement..."
    uv sync --dev

# Ex?cute l'exemple d'utilisation
example:
    @echo "?? Ex?cution de l'exemple..."
    uv run python example_usage.py

# V?rifie que le serveur est accessible
health:
    @echo "?? V?rification de sant?..."
    @curl -s http://localhost:8000/health | jq . || echo "? Serveur non accessible"

# Configure le fichier .env de mani?re interactive
setup-env:
    @echo "?? Configuration du fichier .env..."
    @./scripts/setup-env.sh

# Lance les tests d'int?gration
test-integration:
    @echo "?? Lancement des tests d'int?gration..."
    @./scripts/test_integration.sh

# Build l'image Docker
docker-build:
    @echo "?? Construction de l'image Docker..."
    docker build -t cursor-cli-to-api:latest .

# Lance avec Docker Compose
docker-up:
    @echo "?? D?marrage avec Docker Compose..."
    docker-compose up -d

# Arr?te Docker Compose
docker-down:
    @echo "?? Arr?t de Docker Compose..."
    docker-compose down

# Voir les logs Docker
docker-logs:
    @echo "?? Logs Docker..."
    docker-compose logs -f
