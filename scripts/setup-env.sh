#!/bin/bash
# Script pour créer et configurer le fichier .env

set -e

ENV_FILE=".env"
EXAMPLE_FILE=".env.example"

echo "⚙️ Configuration du fichier .env"
echo "=================================="
echo ""

# Vérifier si .env existe déjà
if [ -f "$ENV_FILE" ]; then
    echo "⚠️  Le fichier .env existe déjà."
    read -p "Voulez-vous le remplacer? (o/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[OoYy]$ ]]; then
        echo "Annulé."
        exit 0
    fi
    echo ""
fi

# Copier le fichier d'exemple
if [ -f "$EXAMPLE_FILE" ]; then
    cp "$EXAMPLE_FILE" "$ENV_FILE"
    echo "✅ Fichier .env créé à partir de .env.example"
else
    echo "❌ Fichier .env.example non trouvé!"
    exit 1
fi

echo ""
echo "⚙️ Configuration interactive (appuyez sur Entrée pour garder les valeurs par défaut)"
echo ""

# Demander le mode cursor-agent
read -p "Mode cursor-agent [cli/http/library] (défaut: cli): " mode
if [ ! -z "$mode" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/CURSOR_AGENT_MODE=.*/CURSOR_AGENT_MODE=$mode/" "$ENV_FILE"
    else
        # Linux
        sed -i "s/CURSOR_AGENT_MODE=.*/CURSOR_AGENT_MODE=$mode/" "$ENV_FILE"
    fi
fi

# Si mode CLI, demander le chemin
if [ -z "$mode" ] || [ "$mode" = "cli" ]; then
    read -p "Chemin vers cursor-agent CLI (défaut: cursor-agent): " cli_path
    if [ ! -z "$cli_path" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|CURSOR_AGENT_CLI_PATH=.*|CURSOR_AGENT_CLI_PATH=$cli_path|" "$ENV_FILE"
        else
            sed -i "s|CURSOR_AGENT_CLI_PATH=.*|CURSOR_AGENT_CLI_PATH=$cli_path|" "$ENV_FILE"
        fi
    fi
fi

# Si mode HTTP, demander l'URL
if [ "$mode" = "http" ]; then
    read -p "URL de l'API HTTP cursor-agent: " http_url
    if [ ! -z "$http_url" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|CURSOR_AGENT_HTTP_URL=.*|CURSOR_AGENT_HTTP_URL=$http_url|" "$ENV_FILE"
        else
            sed -i "s|CURSOR_AGENT_HTTP_URL=.*|CURSOR_AGENT_HTTP_URL=$http_url|" "$ENV_FILE"
        fi
    fi
fi

# Demander si on veut activer l'authentification
read -p "Activer l'authentification par API key? (o/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[OoYy]$ ]]; then
    # Générer une clé API
    if command -v python3 &> /dev/null; then
        api_key=$(python3 -c "import secrets; print('sk-' + secrets.token_urlsafe(32))")
    elif command -v python &> /dev/null; then
        api_key=$(python -c "import secrets; print('sk-' + secrets.token_urlsafe(32))")
    else
        # Fallback avec openssl
        api_key="sk-$(openssl rand -hex 32)"
    fi
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s|API_KEY=.*|API_KEY=$api_key|" "$ENV_FILE"
    else
        sed -i "s|API_KEY=.*|API_KEY=$api_key|" "$ENV_FILE"
    fi
    echo "🔑 Clé API générée: $api_key"
fi

# Demander le niveau de log
read -p "Niveau de log [DEBUG/INFO/WARNING/ERROR] (défaut: INFO): " log_level
if [ ! -z "$log_level" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/LOG_LEVEL=.*/LOG_LEVEL=$log_level/" "$ENV_FILE"
    else
        sed -i "s/LOG_LEVEL=.*/LOG_LEVEL=$log_level/" "$ENV_FILE"
    fi
fi

echo ""
echo "=================================="
echo "✅ Configuration terminée!"
echo ""
echo "📄 Fichier .env créé avec les paramètres suivants:"
echo ""
cat "$ENV_FILE" | grep -v "^#" | grep -v "^$" | sed 's/^/   /'
echo ""
echo "✏️ Vous pouvez éditer .env manuellement pour ajuster les paramètres."
echo "📖 Voir CONFIGURATION.md pour plus de détails."
