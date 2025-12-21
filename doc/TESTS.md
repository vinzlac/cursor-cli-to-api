# Guide des tests et scripts de validation

Ce document liste tous les scripts de test disponibles pour valider et analyser le comportement de cursor-agent.

## 📋 Scripts de test disponibles

### Tests de performance

#### `scripts/test-cli-direct.sh`

Test de performance de cursor-agent en CLI direct (sans passer par l'API).

**Usage :**
```bash
./scripts/test-cli-direct.sh
# ou
just test-cli-direct
```

**Ce qu'il teste :**
- Temps d'exécution de cursor-agent en CLI direct
- Comparaison avec les temps via l'API
- Calcul de l'overhead du subprocess

**Résultats attendus :**
- Temps moyen : ~6.3 secondes
- Confirme que l'overhead du subprocess est minimal (~10%)

---

#### `scripts/test-performance.sh`

Test de performance général de l'API.

**Usage :**
```bash
./scripts/test-performance.sh
# ou
just test-performance
```

**Ce qu'il teste :**
- Temps de réponse de l'API
- 3 requêtes consécutives
- Calcul du temps moyen

**Résultats attendus :**
- Temps moyen : ~6-7 secondes par requête

---

### Tests de processus persistant

#### `scripts/test-persistent-process.sh`

Test complet pour déterminer si cursor-agent peut rester en vie et accepter plusieurs prompts.

**Usage :**
```bash
./scripts/test-persistent-process.sh
# ou
just test-persistent
```

**Ce qu'il teste :**
1. cursor-agent avec stdin continu
2. Processus persistant avec pipe nommé
3. Mode interactif avec expect (si disponible)

**Résultats :**
- ❌ cursor-agent ne supporte pas le mode persistant
- Chaque appel avec `--print` est indépendant

---

#### `scripts/test-persistent-simple.sh`

Test simple pour voir si cursor-agent peut rester en vie.

**Usage :**
```bash
./scripts/test-persistent-simple.sh
```

**Ce qu'il teste :**
- Processus en arrière-plan avec communication bidirectionnelle
- Envoi de prompts via pipe

**Résultats :**
- ❌ cursor-agent ne répond pas correctement via pipe

---

### Tests de sessions

#### `scripts/test-chat-session.sh`

Test avec les sessions de chat cursor-agent (`create-chat`, `--resume`).

**Usage :**
```bash
./scripts/test-chat-session.sh
# ou
just test-sessions
```

**Ce qu'il teste :**
1. Création d'un chat et obtention de l'ID
2. Utilisation de `--resume` avec un chatId
3. Envoi de plusieurs prompts à la même session
4. Mode interactif (sans `--print`)

**Résultats :**
- ✅ `--resume` fonctionne techniquement
- ⚠️ Mais chaque appel crée toujours un nouveau processus
- ⚠️ Plus lent que créer un nouveau chat

---

#### `scripts/test-resume-performance.sh`

Comparaison de performance entre différentes méthodes d'utilisation des sessions.

**Usage :**
```bash
./scripts/test-resume-performance.sh
# ou
just test-resume-perf
```

**Ce qu'il teste :**
1. `--resume` avec le même chatId (3 prompts)
2. Nouveau chatId à chaque fois (3 prompts)
3. Sans `--resume` (nouveau chat implicite)

**Résultats :**
- `--resume` avec même chatId : **9697ms** par prompt (plus lent)
- Nouveau chatId à chaque fois : **6457ms** par prompt (plus rapide)
- Sans `--resume` : **7295ms** par prompt (intermédiaire)

**Conclusion :** `--resume` n'améliore pas les performances.

---

### Tests de configuration

#### `scripts/test-http-mode.sh`

Vérification de la configuration du mode HTTP.

**Usage :**
```bash
./scripts/test-http-mode.sh
# ou
just test-http-mode
```

**Ce qu'il teste :**
- Vérification de cursor-agent
- Options disponibles
- Configuration actuelle (.env)
- Test de connexion à l'API HTTP (si configurée)

**Résultats :**
- cursor-agent ne propose pas de mode HTTP
- Le mode HTTP dans le code est prévu pour un cas hypothétique

---

## 🎯 Commandes `just` disponibles

Toutes les commandes de test sont disponibles via `just` :

```bash
# Tests de performance
just test-performance      # Test général de l'API
just test-cli-direct       # Test CLI direct

# Tests de processus persistant
just test-persistent       # Test complet processus persistant

# Tests de sessions
just test-sessions        # Test des sessions cursor-agent
just test-resume-perf     # Comparaison --resume vs nouveau chat

# Tests de configuration
just test-http-mode       # Vérification mode HTTP
```

---

## 📊 Interprétation des résultats

### Temps de réponse normaux

- **CLI direct :** ~6.3 secondes
- **Via API (subprocess) :** ~6.3 secondes
- **Overhead subprocess :** ~660ms (~10%)

### Ce qui est normal

✅ Temps de 5-7 secondes est **normal** pour cursor-agent
- Initialisation : ~2-3s
- Connexion : ~1-2s
- Appel LLM : ~1-2s
- Traitement : ~0.5s

### Ce qui n'est pas possible

❌ Processus persistant
- cursor-agent avec `--print` est "one-shot"
- Chaque appel crée un nouveau processus

❌ Mode HTTP
- cursor-agent ne propose pas de mode HTTP
- Pas de serveur HTTP intégré

❌ Sessions plus rapides
- `--resume` est plus lent que créer un nouveau chat
- Le chargement du contexte ajoute du temps

---

## 🔧 Utilisation pour le développement

### Déboguer un problème de performance

1. **Tester en CLI direct :**
   ```bash
   just test-cli-direct
   ```
   - Compare avec les temps de l'API
   - Identifie si le problème vient de cursor-agent ou de notre code

2. **Tester l'API :**
   ```bash
   just test-performance
   ```
   - Mesure les temps de réponse réels
   - Identifie les variations

3. **Vérifier la configuration :**
   ```bash
   just test-http-mode
   ```
   - Vérifie que la configuration est correcte
   - Identifie les problèmes de configuration

### Valider une optimisation

1. **Mesurer avant :**
   ```bash
   just test-performance > before.txt
   ```

2. **Appliquer l'optimisation**

3. **Mesurer après :**
   ```bash
   just test-performance > after.txt
   ```

4. **Comparer :**
   ```bash
   diff before.txt after.txt
   ```

---

## 📝 Notes importantes

- Tous les scripts nécessitent `CURSOR_API_KEY` dans `.env`
- Les temps peuvent varier selon la charge du réseau et des serveurs Cursor
- Les tests peuvent prendre plusieurs minutes (cursor-agent est lent)
- Certains tests peuvent échouer si cursor-agent n'est pas installé ou configuré

---

## 🔗 Références

- [Guide de performance](PERFORMANCE.md) - Analyse détaillée des performances
- [Processus persistant et sessions](PERSISTENT_PROCESS.md) - Résultats des tests
- [Guide d'intégration](INTEGRATION.md) - Modes d'intégration

---

**Date de dernière mise à jour :** 2025-01-21

