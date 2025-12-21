# Problème : cursor-agent plus lent dans Docker

## 🔍 Constat

cursor-agent est **beaucoup plus lent dans Docker** que en local :

- **En local :** ~6.3 secondes
- **Dans Docker :** ~19.7 secondes (3x plus lent)

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

## ✅ Solutions appliquées

### 1. Timeout augmenté

Le timeout par défaut est passé de **60s à 120s** pour Docker :

- `docker-compose.yml` : `CURSOR_AGENT_TIMEOUT=${CURSOR_AGENT_TIMEOUT:-120}`
- `docker-compose.secure.yml` : `CURSOR_AGENT_TIMEOUT=${CURSOR_AGENT_TIMEOUT:-120}`
- `docker-compose.insecure.yml` : `CURSOR_AGENT_TIMEOUT=${CURSOR_AGENT_TIMEOUT:-120}`
- Scripts `just` : `CURSOR_AGENT_TIMEOUT=${CURSOR_AGENT_TIMEOUT:-120}`

### 2. Logs améliorés

Les logs sont plus détaillés pour identifier où le temps est perdu :
- Logs de la commande complète
- Logs du prompt
- Logs détaillés de stdout/stderr

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

| Environnement | Temps moyen | Notes |
|----------------|-------------|-------|
| Local (just run) | ~6.3s | cursor-agent en local |
| Docker | ~19.7s | cursor-agent dans conteneur |
| Différence | **+13.4s** | Overhead Docker |

## 💡 Recommandations

1. **Accepter la lenteur dans Docker** (recommandé)
   - C'est normal que Docker soit plus lent
   - 20 secondes est acceptable pour la plupart des cas d'usage
   - Augmenter le timeout à 120s ou 180s

2. **Optimiser Docker** (si nécessaire)
   - Augmenter les ressources
   - Utiliser un réseau optimisé
   - Vérifier la connectivité

3. **Utiliser en local pour le développement**
   - `just run` pour le développement (plus rapide)
   - Docker pour la production (plus isolé)

## 🔗 Références

- [Guide de dépannage Docker](DOCKER_TROUBLESHOOTING.md)
- [Guide de performance](PERFORMANCE.md)
- [Guide Docker](DOCKER_USAGE.md)

---

**Date de dernière mise à jour :** 2025-01-21

