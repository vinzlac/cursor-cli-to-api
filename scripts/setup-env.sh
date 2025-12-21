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

# Demander CURSOR_API_KEY (doit être fournie par l'utilisateur depuis Cursor Settings)
echo ""
echo "🔑 Configuration de CURSOR_API_KEY"
echo "   ⚠️  IMPORTANT: Ce token DOIT être fourni par vous depuis Cursor."
echo "   Il ne peut PAS être généré automatiquement."
echo ""
echo "   Ce token permet à cursor-agent de s'authentifier auprès des services Cursor."
echo "   Vous pouvez le trouver dans: Cursor → Settings → API Keys"
echo ""
read -p "Entrez votre CURSOR_API_KEY (ou appuyez sur Entrée pour laisser vide): " cursor_api_key
if [ ! -z "$cursor_api_key" ]; then
    # Utiliser awk pour remplacer la ligne de manière sûre (évite les problèmes d'échappement)
    if grep -q "^CURSOR_API_KEY=" "$ENV_FILE"; then
        # Créer un fichier temporaire avec la valeur mise à jour
        if [[ "$OSTYPE" == "darwin"* ]]; then
            awk -v key="$cursor_api_key" '/^CURSOR_API_KEY=/ { print "CURSOR_API_KEY=" key; next } { print }' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
        else
            awk -v key="$cursor_api_key" '/^CURSOR_API_KEY=/ { print "CURSOR_API_KEY=" key; next } { print }' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
        fi
    else
        # Ajouter la ligne si elle n'existe pas
        echo "CURSOR_API_KEY=$cursor_api_key" >> "$ENV_FILE"
    fi
    
    # Vérifier que la valeur a bien été sauvegardée
    saved_value=$(grep "^CURSOR_API_KEY=" "$ENV_FILE" | cut -d= -f2-)
    if [ "$saved_value" = "$cursor_api_key" ]; then
        echo "✅ CURSOR_API_KEY configurée: ${cursor_api_key:0:20}..."
    else
        echo "⚠️  Attention: La valeur sauvegardée ne correspond pas. Vérifiez le fichier .env manuellement."
        echo "   Valeur entrée: ${cursor_api_key:0:20}..."
        echo "   Valeur sauvegardée: ${saved_value:0:20}..."
    fi
else
    echo "⚠️  CURSOR_API_KEY laissée vide. Vous pourrez la configurer plus tard."
fi

# Demander si on veut activer l'authentification
echo ""
echo "🔐 Configuration de API_KEY (pour protéger votre proxy)"
echo "   ⚠️  Note: API_KEY est DIFFÉRENT de CURSOR_API_KEY"
echo "   - API_KEY: Protège VOTRE API proxy (générée automatiquement)"
echo "   - CURSOR_API_KEY: Token pour cursor-agent (doit venir de Cursor Settings)"
echo ""
read -p "Activer l'authentification par API key? (o/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[OoYy]$ ]]; then
    # Sauvegarder CURSOR_API_KEY avant de modifier le fichier
    saved_cursor_key=$(grep "^CURSOR_API_KEY=" "$ENV_FILE" | cut -d= -f2- || echo "")
    
    # Générer une clé API (c'est API_KEY, pas CURSOR_API_KEY)
    if command -v python3 &> /dev/null; then
        api_key=$(python3 -c "import secrets; print('sk-' + secrets.token_urlsafe(32))")
    elif command -v python &> /dev/null; then
        api_key=$(python -c "import secrets; print('sk-' + secrets.token_urlsafe(32))")
    else
        # Fallback avec openssl
        api_key="sk-$(openssl rand -hex 32)"
    fi
    
    # Utiliser awk pour remplacer API_KEY de manière sûre
    if grep -q "^API_KEY=" "$ENV_FILE"; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            awk -v key="$api_key" '/^API_KEY=/ { print "API_KEY=" key; next } { print }' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
        else
            awk -v key="$api_key" '/^API_KEY=/ { print "API_KEY=" key; next } { print }' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
        fi
    else
        echo "API_KEY=$api_key" >> "$ENV_FILE"
    fi
    
    # Restaurer CURSOR_API_KEY si elle a été écrasée par erreur
    if [ ! -z "$saved_cursor_key" ]; then
        current_cursor_key=$(grep "^CURSOR_API_KEY=" "$ENV_FILE" | cut -d= -f2- || echo "")
        if [ "$current_cursor_key" != "$saved_cursor_key" ]; then
            echo "⚠️  Restauration de CURSOR_API_KEY..."
            if [[ "$OSTYPE" == "darwin"* ]]; then
                awk -v key="$saved_cursor_key" '/^CURSOR_API_KEY=/ { print "CURSOR_API_KEY=" key; next } { print }' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
            else
                awk -v key="$saved_cursor_key" '/^CURSOR_API_KEY=/ { print "CURSOR_API_KEY=" key; next } { print }' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
            fi
        fi
    fi
    
    echo "🔑 Clé API générée: $api_key"
    echo "   (Note: C'est API_KEY pour protéger votre proxy, pas CURSOR_API_KEY)"
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
