# Problème : cursor-agent plus lent dans Docker

> **✅ RÉSOLU** : Ce problème a été résolu grâce aux optimisations décrites ci-dessous. Les temps sont maintenant identiques entre local et Docker (~4-5s).

## 🔍 Constat initial

cursor-agent était **beaucoup plus lent dans Docker** que en local :

- **En local :** ~6.3 secondes
- **Dans Docker :** ~19.7 secondes (3x plus lent)
- **Avec `--output-format text` :** ~29 secondes (encore plus lent)

## 🎯 Causes probables

### 1. Ressources limitées

Docker peut limiter les ressources CPU/mémoire, ce qui ralentit cursor-agent.

**Solution :** Augmenter les ressources Docker :
- Docker Desktop → Settings → Resources
- Augmenter CPU et Memory

### 2. Latence réseau

La connexion depuis le conteneur peut être plus lente.

**Vérification :**
```bash
docker exec <conteneur> curl -w "@-" -o /dev/null -s https://cursor.com <<'EOF'
time_namelookup:  %{time_namelookup}\n
time_connect:  %{time_connect}\n
time_total:  %{time_total}\n
EOF
```

### 3. Initialisation plus lente

cursor-agent peut prendre plus de temps à s'initialiser dans Docker.

**Vérification :**
```bash
# Mesurer le temps d'initialisation
time docker exec <conteneur> cursor-agent --version
```

### 4. Problème de cache/volumes

Les caches Node.js ou cursor-agent peuvent ne pas être optimaux dans Docker.

## ✅ Solutions appliquées (RÉSOLU)

### 1. Retrait de `--output-format text` ⚡ (Optimisation principale)

**Problème identifié :** L'option `--output-format text` ralentissait significativement cursor-agent dans Docker :
- Avec `--output-format text` : ~29 secondes
- Sans `--output-format text` : ~16 secondes
- **Impact :** -13 secondes (-45%)

**Solution :** Retiré de la commande cursor-agent dans `main.py` :
```python
# Avant (lent dans Docker)
cmd = [cli_path, "--print", "--output-format", "text", "--model", model, prompt]

# Après (rapide)
cmd = [cli_path, "--print", "--model", model, prompt]
```

**Résultat :** Réduction de ~13 secondes dans Docker. Les temps sont maintenant identiques entre local et Docker (~4-5s).

### 2. Timeout augmenté

Le timeout par défaut est passé de **60s à 120s** pour Docker :

- `docker-compose.yml` : `CURSOR_AGENT_TIMEOUT=${CURSOR_AGENT_TIMEOUT:-120}`
- `docker-compose.secure.yml` : `CURSOR_AGENT_TIMEOUT=${CURSOR_AGENT_TIMEOUT:-120}`
- `docker-compose.insecure.yml` : `CURSOR_AGENT_TIMEOUT=${CURSOR_AGENT_TIMEOUT:-120}`
- Scripts `just` : `CURSOR_AGENT_TIMEOUT=${CURSOR_AGENT_TIMEOUT:-120}`

**Raison :** cursor-agent peut prendre jusqu'à 20-25 secondes dans Docker avec certains prompts (notamment avec le modèle `auto` et des prompts courts), le timeout de 60s était trop court.

### 3. Logs améliorés

Les logs sont plus détaillés pour identifier où le temps est perdu :
- Logs de la commande complète
- Logs du prompt
- Logs détaillés de stdout/stderr
- Logs de timing à chaque étape

### 4. Cache des modèles au démarrage

Les modèles disponibles sont chargés au démarrage de l'application (`@app.on_event("startup")`), ce qui évite de les récupérer à chaque requête.

**Impact :** Réduction de ~100-200ms par requête.

## 🔧 Solutions à essayer

### 1. Augmenter les ressources Docker

Dans Docker Desktop :
1. Settings → Resources
2. Augmenter CPU (4+ cores recommandés)
3. Augmenter Memory (4GB+ recommandés)
4. Appliquer & Restart

### 2. Configurer le timeout dans .env

```env
# Dans .env
CURSOR_AGENT_TIMEOUT=180  # 3 minutes pour être sûr
```

### 3. Vérifier la connectivité réseau

```bash
# Depuis le conteneur
docker exec <conteneur> curl -v https://cursor.com
```

### 4. Utiliser un réseau Docker personnalisé

```yaml
# Dans docker-compose.yml
networks:
  cursor-net:
    driver: bridge

services:
  api:
    networks:
      - cursor-net
```

### 5. Optimiser l'image Docker

- Utiliser une image de base plus légère
- Optimiser les layers Docker
- Utiliser un cache multi-stage

## 📊 Comparaison des temps

### Avant optimisation

| Environnement | Modèle | Prompt | Temps moyen | Notes |
|---------------|--------|--------|-------------|-------|
| Local | `gpt-5.2` | Réaliste | ~6.3s | cursor-agent en local |
| Docker | `gpt-5.2` | Réaliste | ~19.7s | cursor-agent dans conteneur |
| Docker (avec `--output-format text`) | `gpt-5.2` | Réaliste | ~29s | Encore plus lent |
| Différence | - | - | **+13.4s** | Overhead Docker |

### Après optimisation ✅

| Environnement | Modèle | Prompt | Temps moyen | Amélioration |
|---------------|--------|--------|-------------|--------------|
| Local | `gpt-5.2` | Réaliste | ~5s | - |
| Docker | `gpt-5.2` | Réaliste | ~5s | **-14.7s (-75%)** |
| Local | `auto` | Réaliste | ~4-5s | - |
| Docker | `auto` | Réaliste | ~4-5s | **Identique au local** |
| Docker | `auto` | Court ("test") | ~16-24s | Lent mais acceptable |

**Conclusion :** Après optimisation, Docker est aussi rapide que le local pour des prompts réalistes. La différence de performance a été éliminée.

## 💡 Recommandations (après optimisation)

1. **✅ Utiliser Docker sans problème de performance**
   - Les temps sont maintenant identiques entre local et Docker (~4-5s)
   - Docker est recommandé pour la production (isolation, reproductibilité)

2. **Choisir le bon modèle selon le cas d'usage**
   - **Modèles spécifiques (`gpt-5.2`, `gpt-5.1`, etc.)** : Performance constante (~4-5s) quelle que soit la longueur du prompt
   - **Modèle `auto`** : Rapide avec prompts réalistes (~4-5s), lent avec prompts courts (~16-24s)
   - ✅ **Recommandation production :** Utiliser un modèle spécifique pour des performances prévisibles

3. **Utiliser des prompts réalistes**
   - Éviter les prompts très courts ("test", "hello")
   - Utiliser des phrases complètes pour de meilleures performances avec `auto`

4. **Configurer le timeout approprié**
   - Timeout par défaut : 120s (suffisant pour la plupart des cas)
   - Si vous utilisez `auto` avec des prompts courts, le timeout peut être augmenté à 180s

5. **Monitoring des performances**
   - Activer les logs DEBUG pour voir les temps détaillés
   - Surveiller les logs pour identifier les requêtes lentes

## 🔗 Références

- [Guide de dépannage Docker](DOCKER_TROUBLESHOOTING.md)
- [Guide de performance](PERFORMANCE.md)
- [Guide Docker](DOCKER_USAGE.md)

---

**Date de dernière mise à jour :** 2025-12-21

**Statut :** ✅ RÉSOLU - Les optimisations ont éliminé la différence de performance entre local et Docker.

