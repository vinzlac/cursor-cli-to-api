# Guide du mode HTTP

> ⚠️ **Note importante :** cursor-agent est un outil CLI et **ne propose pas de mode HTTP**. Le mode HTTP dans ce proxy est prévu pour un cas hypothétique où un serveur HTTP cursor-agent externe existerait, ou pour une future évolution.

## 🔍 État actuel

### cursor-agent est un outil CLI uniquement

**cursor-agent est un outil CLI** et ne propose pas de mode serveur HTTP. Le mode HTTP dans ce proxy est donc **actuellement non utilisable** avec cursor-agent standard.

Le mode HTTP dans le code est prévu pour :
- Un serveur HTTP cursor-agent externe hypothétique
- Une future évolution de cursor-agent
- Un wrapper HTTP personnalisé que vous pourriez créer

## 🚀 Options pour utiliser le mode HTTP

### Option 1 : Serveur HTTP cursor-agent (si disponible)

Si cursor-agent peut être lancé en mode serveur HTTP :

1. **Lancer cursor-agent en mode serveur** (vérifier la documentation cursor-agent)
2. **Configurer dans `.env`** :
   ```env
   CURSOR_AGENT_MODE=http
   CURSOR_AGENT_HTTP_URL=http://localhost:PORT/api/chat
   ```
3. **Redémarrer le proxy**

### Option 2 : Utiliser l'API Cursor directement

Si vous avez accès à l'API Cursor directement, vous pouvez :

1. **Créer un wrapper HTTP** qui appelle l'API Cursor
2. **Configurer le proxy pour utiliser ce wrapper**

### Option 3 : Mode Library (recommandé si disponible)

Si cursor-agent est disponible comme bibliothèque Python, c'est la meilleure option :

1. **Installer la bibliothèque cursor-agent**
2. **Implémenter `_call_cursor_agent_library()`**
3. **Configurer** :
   ```env
   CURSOR_AGENT_MODE=library
   ```

## 📊 Comparaison des performances

### Mode CLI (actuel)
- **Temps moyen :** 5-7 secondes
- **Overhead :** Initialisation subprocess à chaque appel
- **Avantages :** Simple, pas de serveur externe
- **Inconvénients :** Lent à cause de l'overhead

### Mode HTTP (théorique)
- **Temps estimé :** 1-2 secondes
- **Overhead :** Minimal (connexion HTTP)
- **Avantages :** Plus rapide, connexion persistante
- **Inconvénients :** Nécessite un serveur HTTP cursor-agent

### Mode Library (théorique)
- **Temps estimé :** < 1 seconde
- **Overhead :** Minimal (appel direct)
- **Avantages :** Le plus rapide
- **Inconvénients :** Nécessite une bibliothèque Python

## 🧪 Test du mode HTTP

### Si vous avez un serveur HTTP cursor-agent

1. **Vérifier que le serveur est accessible** :
   ```bash
   curl http://localhost:PORT/health
   ```

2. **Configurer dans `.env`** :
   ```env
   CURSOR_AGENT_MODE=http
   CURSOR_AGENT_HTTP_URL=http://localhost:PORT/api/chat
   ```

3. **Tester avec le script** :
   ```bash
   ./scripts/test-performance.sh
   ```

### Si vous n'avez pas de serveur HTTP

Le mode HTTP n'est pas disponible. Options :
- Utiliser le mode CLI (actuel, mais plus lent)
- Implémenter le mode Library si disponible
- Créer un wrapper HTTP pour l'API Cursor

## 🔧 Dépannage

### Erreur : "Impossible de se connecter à cursor-agent HTTP"

**Cause :** Le serveur HTTP cursor-agent n'est pas démarré ou l'URL est incorrecte.

**Solution :**
1. Vérifiez que le serveur HTTP cursor-agent est démarré
2. Vérifiez l'URL dans `CURSOR_AGENT_HTTP_URL`
3. Testez la connexion : `curl http://localhost:PORT/health`

### Erreur : "Timeout"

**Cause :** Le serveur HTTP ne répond pas dans les délais.

**Solution :**
1. Augmentez `CURSOR_AGENT_TIMEOUT` dans `.env`
2. Vérifiez que le serveur HTTP est opérationnel
3. Vérifiez la latence réseau

## 📝 Notes

- Le mode HTTP nécessite un serveur HTTP cursor-agent externe
- Si ce serveur n'existe pas, le mode CLI reste la seule option
- L'overhead du mode CLI (5-7s) est normal pour un subprocess
- Pour de meilleures performances, privilégiez le mode Library si disponible

## 🔗 Références

- [Guide de performance](PERFORMANCE.md)
- [Guide d'intégration](INTEGRATION.md)
- [Documentation cursor-agent](https://docs.cursor.com)

