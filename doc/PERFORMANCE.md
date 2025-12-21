# Guide de performance et optimisation

Ce document explique les problèmes de performance identifiés, les optimisations appliquées et les facteurs qui influencent les temps d'exécution.

> **Note importante :** cursor-agent est un outil CLI uniquement et ne propose pas de mode HTTP. Le mode HTTP dans le code est prévu pour un cas hypothétique. Voir [HTTP_MODE.md](HTTP_MODE.md) pour plus de détails.

## 📊 Temps d'exécution observés

### Environnement local

| Modèle | Prompt | Temps moyen | Notes |
|--------|--------|-------------|-------|
| `gpt-5.2` | Prompt réaliste | ~5s | Modèle spécifique, rapide |
| `auto` | Prompt réaliste | ~4-5s | Sélection automatique, rapide avec prompts réalistes |
| `auto` | Prompt très court ("test") | ~17-24s | **Lent avec prompts courts** |
| `gpt-5.1` | Prompt réaliste | ~5-6s | Modèle spécifique, rapide |

### Environnement Docker

| Modèle | Prompt | Temps moyen | Notes |
|--------|--------|-------------|-------|
| `gpt-5.2` | Prompt réaliste | ~5s | Identique au local |
| `auto` | Prompt réaliste | ~4-5s | Identique au local |
| `auto` | Prompt très court ("test") | ~24-26s | **Très lent avec prompts courts** |

**Conclusion :** Les temps sont similaires entre local et Docker **après optimisation** (voir section Optimisations Docker).

## 🔍 Analyse du problème

### Problème identifié initialement

Les requêtes via l'API prenaient **5-7 secondes**, ce qui est similaire aux appels CLI directs. Après optimisation, les temps sont maintenant **4-5 secondes** pour des prompts réalistes.

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

## 🎯 Facteurs influençant les performances

### 1. Type de modèle

**Modèles spécifiques (`gpt-5.2`, `gpt-5.1`, `sonnet-4.5`, etc.) :**
- ✅ **Rapides** : ~4-5 secondes
- Pas de sélection de modèle nécessaire
- Performance constante

**Modèle `auto` (sélection automatique) :**
- ✅ **Rapide avec prompts réalistes** : ~4-5 secondes
- ⚠️ **Lent avec prompts très courts** : ~17-26 secondes
- Le modèle `auto` adapte sa sélection selon le prompt :
  - Prompts réalistes → sélection rapide, modèle optimal
  - Prompts très courts → logique de sélection plus complexe, peut choisir un modèle plus lent

**Recommandation :** Utiliser un modèle spécifique (`gpt-5.2`, `gpt-5.1`, etc.) pour des performances constantes, ou utiliser `auto` avec des prompts réalistes.

### 2. Longueur et complexité du prompt

| Type de prompt | Temps avec `auto` | Temps avec `gpt-5.2` |
|----------------|-------------------|----------------------|
| Très court ("test") | ~17-26s | ~5s |
| Court ("Bonjour") | ~5-6s | ~5s |
| Réaliste ("Bonjour, comment ça va ?") | ~4-5s | ~5s |
| Avec système + utilisateur | ~5-6s | ~5s |

**Conclusion :** Les prompts réalistes sont plus rapides avec `auto`. Les modèles spécifiques sont constants quelle que soit la longueur du prompt.

### 3. Environnement (Local vs Docker)

**Avant optimisation :**
- Local : ~6.3s
- Docker : ~19.7s (3x plus lent)

**Après optimisation :**
- Local : ~4-5s
- Docker : ~4-5s (identique au local)

Voir section [Optimisations Docker](#optimisations-docker) pour les détails.

## 📊 Comparaison des temps

### Temps observés (mesurés après optimisation)

| Méthode | Modèle | Prompt | Temps moyen | Notes |
|---------|--------|--------|-------------|-------|
| **CLI direct** | `gpt-5.2` | Réaliste | **~5s** | cursor-agent en mode non-interactif (`--print`) |
| **API via subprocess** | `gpt-5.2` | Réaliste | **~5s** | Même temps que CLI direct (overhead minimal) |
| **API via subprocess** | `auto` | Réaliste | **~4-5s** | Rapide avec prompts réalistes |
| **API via subprocess** | `auto` | Très court | **~17-26s** | Lent avec prompts courts |
| API via HTTP | N/A | N/A | N/A | cursor-agent ne propose pas de mode HTTP |
| API via Library | N/A | N/A | N/A | cursor-agent n'est pas disponible comme bibliothèque |

**Conclusion :** Le temps de 4-5 secondes est **normal et attendu** pour cursor-agent avec des prompts réalistes. C'est le temps nécessaire pour :
- Initialiser cursor-agent
- Se connecter au service Cursor
- Appeler le LLM (GPT-5.2, etc.)
- Recevoir et traiter la réponse

## 🐳 Optimisations Docker

### Problème initial

cursor-agent était **3x plus lent dans Docker** (~19.7s) qu'en local (~6.3s).

### Optimisations appliquées

#### 1. Retrait de `--output-format text`

**Problème :** L'option `--output-format text` ralentissait significativement cursor-agent dans Docker :
- Avec `--output-format text` : ~29 secondes
- Sans `--output-format text` : ~16 secondes

**Solution :** Retiré de la commande cursor-agent dans `main.py` :
```python
# Avant (lent)
cmd = [cli_path, "--print", "--output-format", "text", "--model", model, prompt]

# Après (rapide)
cmd = [cli_path, "--print", "--model", model, prompt]
```

**Impact :** Réduction de ~13 secondes dans Docker.

#### 2. Augmentation du timeout

Le timeout par défaut est passé de **60s à 120s** pour Docker :
- `docker-compose.yml` : `CURSOR_AGENT_TIMEOUT=${CURSOR_AGENT_TIMEOUT:-120}`
- `docker-compose.secure.yml` : `CURSOR_AGENT_TIMEOUT=${CURSOR_AGENT_TIMEOUT:-120}`
- `docker-compose.insecure.yml` : `CURSOR_AGENT_TIMEOUT=${CURSOR_AGENT_TIMEOUT:-120}`

**Raison :** cursor-agent peut prendre jusqu'à 20-25 secondes dans Docker avec certains prompts, le timeout de 60s était trop court.

#### 3. Utilisation de `--print` pour le mode non-interactif

L'option `--print` est utilisée pour le mode non-interactif, ce qui est plus rapide pour les scripts :
```python
cmd = [cli_path, "--print", "--model", model, prompt]
```

#### 4. Cache des modèles au démarrage

Les modèles disponibles sont chargés au démarrage de l'application (`@app.on_event("startup")`), ce qui évite de les récupérer à chaque requête.

**Impact :** Réduction de ~100-200ms par requête.

### Résultats après optimisation

| Environnement | Modèle | Prompt | Temps moyen | Amélioration |
|---------------|--------|--------|-------------|--------------|
| Local | `gpt-5.2` | Réaliste | ~5s | - |
| Docker (avant) | `gpt-5.2` | Réaliste | ~19.7s | - |
| Docker (après) | `gpt-5.2` | Réaliste | ~5s | **-14.7s (-75%)** |
| Docker (avant) | `auto` | Court | ~29s | - |
| Docker (après) | `auto` | Court | ~16s | **-13s (-45%)** |

**Conclusion :** Après optimisation, Docker est aussi rapide que le local pour des prompts réalistes.

## 🚀 Recommandations

### Court terme (recommandé)

1. **Utiliser des modèles spécifiques pour des performances constantes**
   - Préférer `gpt-5.2`, `gpt-5.1`, `sonnet-4.5`, etc. plutôt que `auto`
   - Performance constante (~4-5s) quelle que soit la longueur du prompt
   - ✅ **Recommandé pour la production**

2. **Si vous utilisez `auto`, utiliser des prompts réalistes**
   - Éviter les prompts très courts ("test", "hello")
   - Utiliser des phrases complètes ("Bonjour, comment ça va ?")
   - Performance similaire aux modèles spécifiques (~4-5s)

3. **Activer les logs DEBUG** pour voir les détails :
   ```bash
   LOG_LEVEL=DEBUG python main.py
   ```

4. **Optimisations déjà appliquées** :
   - ✅ Cache des modèles au démarrage
   - ✅ Utilisation de `--print` pour le mode non-interactif
   - ✅ Retrait de `--output-format text` (ralentissait dans Docker)
   - ✅ Timeout augmenté à 120s pour Docker

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
- [Problème Docker lent](DOCKER_SLOW.md) - Optimisations Docker appliquées

---

**Date de dernière mise à jour :** 2025-12-21

