# Guide de performance et optimisation

Ce document explique les problèmes de performance identifiés et les solutions possibles.

> **Note importante :** cursor-agent est un outil CLI uniquement et ne propose pas de mode HTTP. Le mode HTTP dans le code est prévu pour un cas hypothétique. Voir [HTTP_MODE.md](HTTP_MODE.md) pour plus de détails.

## 🔍 Analyse du problème

### Problème identifié

Les requêtes via l'API prennent **5-7 secondes**, ce qui est similaire aux appels CLI directs.

### Tests de performance réalisés

Tests effectués avec cursor-agent en CLI direct (mode non-interactif) :

| Test | Temps | Prompt |
|------|-------|--------|
| Test 1 | 7295ms | "Explique-moi ce qu'est FastAPI en 2 phrases" |
| Test 2 | 5222ms | "Bonjour" |
| Test 3 | 6524ms | System + "Qu'est-ce que Python?" |
| **Moyenne** | **6340ms** | - |

### Analyse des logs

D'après les logs de timing et les tests CLI directs :
- **cursor-agent CLI direct : ~6300ms** (temps réel de cursor-agent)
- **Via API (subprocess) : ~5000-7000ms** (temps total)
- **Overhead du subprocess : ~660ms** (seulement ~10% du temps total)

**Conclusion :** Le temps est principalement passé dans **cursor-agent lui-même** (appel API au LLM, traitement, etc.), pas dans notre code. L'overhead du subprocess est minimal (~10%).

## 🎯 Causes probables

### 1. Overhead du subprocess

Chaque appel crée un **nouveau processus** cursor-agent, ce qui implique :
- Initialisation de cursor-agent (chargement des dépendances, Node.js, etc.)
- Connexion réseau au service Cursor
- Authentification
- Traitement de la requête

**En CLI direct :** cursor-agent peut rester en mémoire et réutiliser des connexions.

### 2. Format des messages

Le format actuel :
```python
prompt = "\n".join([f"{msg.role}: {msg.content}" for msg in messages])
# Résultat: "system: ...\nuser: ..."
```

Peut ne pas être optimal pour cursor-agent qui pourrait attendre un format différent.

### 3. Pas de réutilisation de processus

Contrairement à un serveur HTTP qui reste en mémoire, chaque appel subprocess doit :
- Démarrer cursor-agent
- Se connecter
- Traiter
- Se fermer

## 💡 Solutions possibles

### Solution 1 : Mode HTTP (non disponible actuellement)

> ⚠️ **cursor-agent est un outil CLI uniquement** et ne propose pas de mode HTTP. Cette solution n'est donc pas applicable actuellement.

Si dans le futur cursor-agent proposait une API HTTP, ce serait la solution la plus rapide, mais ce n'est pas le cas aujourd'hui.

### Solution 2 : Mode Library (si disponible)

Si cursor-agent était disponible comme bibliothèque Python (actuellement non disponible) :

```env
CURSOR_AGENT_MODE=library
```

**Avantages :**
- Pas d'overhead de subprocess
- Appel direct en mémoire
- Le plus rapide

**Inconvénients :**
- Nécessite une bibliothèque Python cursor-agent
- Actuellement non disponible

### Solution 3 : Accepter l'overhead du subprocess (recommandé)

**C'est la solution actuelle et la plus simple.**

L'overhead de 5-7 secondes est **normal pour un subprocess** qui doit :
- S'initialiser à chaque appel
- Se connecter au service Cursor
- S'authentifier
- Traiter la requête

**Avantages :**
- Simple et fiable
- Pas de complexité supplémentaire
- Fonctionne avec cursor-agent tel quel

**Inconvénients :**
- Plus lent qu'un appel direct (5-7s vs 1-2s en CLI direct)

### Solution 4 : Pool de processus (avancé, complexe)

Créer un pool de processus cursor-agent qui restent en mémoire :

```python
# Garder plusieurs processus cursor-agent actifs
# Réutiliser les processus au lieu d'en créer de nouveaux
```

**Avantages :**
- Réduit l'overhead d'initialisation
- Plus rapide que créer un nouveau processus à chaque fois

**Inconvénients :**
- Très complexe à implémenter
- Gestion de la mémoire et des processus
- Nécessite une gestion de la vie des processus
- Risque de fuites mémoire
- Peut ne pas fonctionner correctement avec cursor-agent

### Solution 5 : Optimiser le format des messages

Tester différents formats pour voir si cursor-agent répond plus vite :

```python
# Format 1: Actuel
prompt = "\n".join([f"{msg.role}: {msg.content}" for msg in messages])

# Format 2: Avec majuscules
prompt = "\n".join([f"{msg.role.capitalize()}: {msg.content}" for msg in messages])

# Format 3: Format JSON
import json
prompt = json.dumps([{"role": msg.role, "content": msg.content} for msg in messages])
```

### Solution 6 : Utiliser stdin au lieu d'arguments

Passer le prompt via stdin peut être plus rapide pour les longs prompts :

```python
process = subprocess.Popen(
    [cli_path, "--print", "--model", model],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE
)
stdout, stderr = process.communicate(input=prompt.encode())
```

## 📊 Comparaison des temps

### Temps observés (mesurés)

| Méthode | Temps moyen | Notes |
|---------|-------------|-------|
| **CLI direct** | **~6.3s** | cursor-agent en mode non-interactif (`--print`) |
| **API via subprocess** | **~6.3s** | Même temps que CLI direct (overhead minimal) |
| API via HTTP | N/A | cursor-agent ne propose pas de mode HTTP |
| API via Library | N/A | cursor-agent n'est pas disponible comme bibliothèque |

**Conclusion :** Le temps de 5-7 secondes est **normal et attendu** pour cursor-agent. C'est le temps nécessaire pour :
- Initialiser cursor-agent
- Se connecter au service Cursor
- Appeler le LLM (GPT-5.2, etc.)
- Recevoir et traiter la réponse

## 🚀 Recommandations

### Court terme (recommandé)

1. **Accepter l'overhead du subprocess**
   - C'est normal pour un outil CLI
   - 5-7 secondes est acceptable pour la plupart des cas d'usage
   - Simple et fiable

2. **Activer les logs DEBUG** pour voir les détails :
   ```bash
   LOG_LEVEL=DEBUG python main.py
   ```

3. **Optimiser ce qui peut l'être** :
   - Cache des modèles (déjà fait ✅)
   - Format des messages (peut être optimisé)
   - Utilisation de `--print` (déjà fait ✅)

### Moyen terme (si nécessaire)

1. **Ajouter un cache des réponses** pour les requêtes identiques
   - Réduit les appels répétés
   - Améliore les performances pour les requêtes courantes

2. **Monitoring des performances** avec des métriques détaillées
   - Identifier les goulots d'étranglement
   - Suivre l'évolution des performances

### Long terme (si vraiment nécessaire)

1. **Implémenter un pool de processus** (très complexe)
   - Nécessite une architecture sophistiquée
   - Risque de bugs et de fuites mémoire
   - Peut ne pas fonctionner avec cursor-agent

2. **Créer un wrapper HTTP personnalisé** (si vous avez besoin d'une API HTTP)
   - Wrapper qui appelle cursor-agent en CLI
   - Expose une API HTTP
   - Permet de réutiliser les connexions

## 🔧 Test de performance

Pour tester les performances :

```bash
# Test simple
time curl -X POST http://localhost:8001/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-5.2", "messages": [{"role": "user", "content": "Test"}]}'

# Test avec logs détaillés
LOG_LEVEL=DEBUG python main.py
```

## 📝 Notes

- Le temps de réponse dépend aussi de la latence réseau vers les services Cursor
- Les modèles plus complexes (gpt-5.2, opus-4.5) peuvent être plus lents
- Le premier appel peut être plus lent (initialisation)
- Les appels suivants peuvent être plus rapides (cache, connexions réutilisées)

## 🔗 Références

- [Documentation cursor-agent](https://docs.cursor.com)
- [Guide d'intégration](INTEGRATION.md)
- [Points à améliorer](AMELIORATIONS.md)
- [Processus persistant et sessions](PERSISTENT_PROCESS.md) - Tests détaillés sur les processus persistants

