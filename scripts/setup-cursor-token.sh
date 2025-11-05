#!/bin/bash
#
# Script sécurisé pour configurer votre CURSOR_API_TOKEN dans .zshrc
# La clé ne sera PAS affichée à l'écran
#

set -e

echo "🔐 Configuration sécurisée de CURSOR_API_TOKEN"
echo ""
echo "⚠️  IMPORTANT:"
echo "   1. Révoqué votre ancienne clé dans Cursor → Paramètres → Clés API"
echo "   2. Généré une NOUVELLE clé"
echo ""
read -p "Avez-vous déjà révoqué l'ancienne clé et généré une nouvelle? (o/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[OoYy]$ ]]; then
    echo "❌ Veuillez d'abord révoquer l'ancienne clé et générer une nouvelle."
    echo ""
    echo "📖 Instructions:"
    echo "   1. Ouvrir Cursor Desktop"
    echo "   2. Aller dans Paramètres (⚙️)"
    echo "   3. Cliquer sur 'Clés API'"
    echo "   4. Révoquer l'ancienne clé"
    echo "   5. Générer une nouvelle clé"
    echo "   6. Relancer ce script"
    exit 1
fi

echo ""
echo "📝 Entrez votre NOUVELLE clé Cursor API"
echo "   (elle ne sera PAS affichée à l'écran)"
echo ""

# Lire la clé de manière sécurisée (sans l'afficher)
read -s -p "CURSOR_API_TOKEN: " NEW_TOKEN
echo ""

# Vérifier que la clé n'est pas vide
if [ -z "$NEW_TOKEN" ]; then
    echo "❌ Erreur: La clé ne peut pas être vide"
    exit 1
fi

# Vérifier le format basique (commence par "key_")
if [[ ! "$NEW_TOKEN" =~ ^key_ ]]; then
    echo "⚠️  Avertissement: La clé ne commence pas par 'key_'"
    read -p "Voulez-vous continuer quand même? (o/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[OoYy]$ ]]; then
        exit 1
    fi
fi

# Backup du .zshrc
cp ~/.zshrc ~/.zshrc.backup.$(date +%Y%m%d_%H%M%S)
echo "✅ Backup créé: ~/.zshrc.backup.$(date +%Y%m%d_%H%M%S)"

# Remplacer le placeholder dans .zshrc
if grep -q "VOTRE_NOUVELLE_CLE_CURSOR" ~/.zshrc; then
    # Échapper les caractères spéciaux pour sed
    ESCAPED_TOKEN=$(echo "$NEW_TOKEN" | sed 's/[\/&]/\\&/g')
    sed -i.tmp "s/VOTRE_NOUVELLE_CLE_CURSOR/$ESCAPED_TOKEN/g" ~/.zshrc
    rm ~/.zshrc.tmp
    echo "✅ Clé ajoutée dans ~/.zshrc"
else
    echo "⚠️  Le placeholder n'a pas été trouvé dans .zshrc"
    echo "   La clé a peut-être déjà été configurée."
fi

# Recharger le .zshrc
echo ""
echo "🔄 Pour appliquer les changements, exécutez:"
echo "   source ~/.zshrc"
echo ""
echo "✅ Configuration terminée avec succès!"
echo ""
echo "🧪 Pour tester:"
echo "   source ~/.zshrc"
echo "   echo \${CURSOR_API_TOKEN:0:10}...  # Affiche les 10 premiers caractères"

