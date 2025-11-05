#!/bin/bash
# Script pour cr?er et configurer le fichier .env

set -e

ENV_FILE=".env"
EXAMPLE_FILE=".env.example"

echo "?? Configuration du fichier .env"
echo "=================================="
echo ""

# V?rifier si .env existe d?j?
if [ -f "$ENV_FILE" ]; then
    echo "??  Le fichier .env existe d?j?."
    read -p "Voulez-vous le remplacer? (o/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[OoYy]$ ]]; then
        echo "Annul?."
        exit 0
    fi
    echo ""
fi

# Copier le fichier d'exemple
if [ -f "$EXAMPLE_FILE" ]; then
    cp "$EXAMPLE_FILE" "$ENV_FILE"
    echo "? Fichier .env cr?? ? partir de .env.example"
else
    echo "? Fichier .env.example non trouv?!"
    exit 1
fi

echo ""
echo "?? Configuration interactive (appuyez sur Entr?e pour garder les valeurs par d?faut)"
echo ""

# Demander le mode cursor-agent
read -p "Mode cursor-agent [cli/http/library] (d?faut: cli): " mode
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
    read -p "Chemin vers cursor-agent CLI (d?faut: cursor-agent): " cli_path
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
    # G?n?rer une cl? API
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
    echo "? Cl? API g?n?r?e: $api_key"
fi

# Demander le niveau de log
read -p "Niveau de log [DEBUG/INFO/WARNING/ERROR] (d?faut: INFO): " log_level
if [ ! -z "$log_level" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/LOG_LEVEL=.*/LOG_LEVEL=$log_level/" "$ENV_FILE"
    else
        sed -i "s/LOG_LEVEL=.*/LOG_LEVEL=$log_level/" "$ENV_FILE"
    fi
fi

echo ""
echo "=================================="
echo "? Configuration termin?e!"
echo ""
echo "?? Fichier .env cr?? avec les param?tres suivants:"
echo ""
cat "$ENV_FILE" | grep -v "^#" | grep -v "^$" | sed 's/^/   /'
echo ""
echo "?? Vous pouvez ?diter .env manuellement pour ajuster les param?tres."
echo "?? Voir CONFIGURATION.md pour plus de d?tails."
