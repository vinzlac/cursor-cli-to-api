#!/usr/bin/env bash
# Script pour tester le mode HTTP de cursor-agent

set -e

echo "🔍 Vérification du mode HTTP cursor-agent"
echo "=========================================="
echo ""

# Vérifier si cursor-agent expose une API HTTP
echo "1. Vérification de cursor-agent..."
if ! command -v cursor-agent &> /dev/null; then
    echo "❌ cursor-agent n'est pas installé"
    exit 1
fi

echo "✅ cursor-agent trouvé: $(which cursor-agent)"
echo ""

# Vérifier les options disponibles
echo "2. Options disponibles de cursor-agent:"
cursor-agent --help 2>&1 | grep -E "http|server|port|api" -i || echo "   ⚠️  Aucune option HTTP trouvée"
echo ""

# Vérifier la configuration actuelle
echo "3. Configuration actuelle (.env):"
if [ -f .env ]; then
    if grep -q "^CURSOR_AGENT_MODE=" .env; then
        CURRENT_MODE=$(grep "^CURSOR_AGENT_MODE=" .env | cut -d= -f2)
        echo "   Mode actuel: $CURRENT_MODE"
    else
        echo "   Mode actuel: non défini (défaut: cli)"
    fi
    
    if grep -q "^CURSOR_AGENT_HTTP_URL=" .env; then
        HTTP_URL=$(grep "^CURSOR_AGENT_HTTP_URL=" .env | cut -d= -f2)
        echo "   URL HTTP: $HTTP_URL"
        
        # Tester si l'URL est accessible
        if [ -n "$HTTP_URL" ]; then
            echo ""
            echo "4. Test de connexion à l'API HTTP..."
            if curl -s --connect-timeout 3 "$HTTP_URL" > /dev/null 2>&1; then
                echo "   ✅ L'URL est accessible"
            else
                echo "   ❌ L'URL n'est pas accessible"
                echo "   Vérifiez que le serveur cursor-agent HTTP est démarré"
            fi
        fi
    else
        echo "   URL HTTP: non définie"
    fi
else
    echo "   ⚠️  Fichier .env non trouvé"
fi

echo ""
echo "=========================================="
echo "💡 Pour utiliser le mode HTTP:"
echo ""
echo "1. Vérifiez si cursor-agent expose une API HTTP"
echo "   - Consultez la documentation cursor-agent"
echo "   - Ou vérifiez s'il existe un serveur HTTP cursor-agent"
echo ""
echo "2. Si une API HTTP existe, configurez dans .env:"
echo "   CURSOR_AGENT_MODE=http"
echo "   CURSOR_AGENT_HTTP_URL=http://localhost:PORT/api/chat"
echo ""
echo "3. Redémarrez le serveur:"
echo "   just dev"
echo ""
echo "4. Testez avec:"
echo "   ./scripts/test-performance.sh"
echo ""
echo "📖 Voir doc/PERFORMANCE.md pour plus de détails"

