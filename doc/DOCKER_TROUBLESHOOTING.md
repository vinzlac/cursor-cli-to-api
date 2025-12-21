# Guide de dépannage Docker

Ce guide vous aide à résoudre les problèmes courants avec Docker.

## 🔍 Diagnostic rapide

Utilisez les scripts de diagnostic :

```bash
# Diagnostic complet
just docker-diagnose

# Test spécifique de cursor-agent
just docker-test-cursor
```

Ces scripts vérifient :
- ✅ Si cursor-agent est installé dans le conteneur
- ✅ Si CURSOR_API_KEY est définie
- ✅ Si cursor-agent peut s'exécuter et répondre
- ✅ La connectivité réseau
- ✅ Les logs du conteneur

> **Note :** Si ça fonctionne avec `just run` (sans Docker) mais pas dans Docker, le problème est spécifique à Docker. Vérifiez l'installation de cursor-agent dans le conteneur.

## ❌ Problème : Timeout après 60 secondes

> **Note importante :** cursor-agent est **3x plus lent dans Docker** (~19.7s) qu'en local (~6.3s). C'est normal et le timeout a été augmenté à 120s par défaut pour Docker.

### Symptômes

```
2025-12-21 17:22:07,687 - main - ERROR - Timeout lors de l'appel à cursor-agent
Status: 500 - Time: 60.151s
```

> **Important :** Si ça fonctionne avec `just run` (sans Docker) mais pas dans Docker, le problème est spécifique à Docker.

### Causes possibles

1. **cursor-agent n'est pas installé correctement dans le conteneur**
2. **CURSOR_API_KEY n'est pas définie ou incorrecte dans le conteneur**
3. **Problème de connectivité réseau depuis le conteneur**
4. **cursor-agent ne peut pas s'authentifier dans le conteneur**
5. **cursor-agent ne répond pas dans le conteneur (bloqué ou en erreur)**

### Solutions

#### 1. Vérifier l'installation de cursor-agent

```bash
# Entrer dans le conteneur
docker exec -it <nom-conteneur> bash

# Vérifier que cursor-agent est installé
which cursor-agent
cursor-agent --version

# Tester cursor-agent
cursor-agent --help
```

**Si cursor-agent n'est pas trouvé :**
- Reconstruire l'image : `just docker-build`
- Vérifier les logs du build pour voir si l'installation a échoué

#### 2. Vérifier CURSOR_API_KEY

```bash
# Vérifier dans le conteneur
docker exec <nom-conteneur> printenv CURSOR_API_KEY

# Vérifier dans .env
grep CURSOR_API_KEY .env
```

**Si CURSOR_API_KEY n'est pas définie :**
- Vérifier que `.env` contient `CURSOR_API_KEY=...`
- Vérifier que Docker Compose charge bien le `.env`
- Pour les modes sécurisés, vérifier que la variable est exportée

#### 3. Tester cursor-agent dans le conteneur

**Méthode rapide (recommandée) :**
```bash
just docker-test-cursor
```

**Méthode manuelle :**
```bash
# Entrer dans le conteneur
docker exec -it <nom-conteneur> bash

# Tester avec un prompt simple
cursor-agent --print --model auto "user: test"
```

**Si ça timeout ou échoue :**
- Vérifier la connectivité réseau : `curl https://cursor.com`
- Vérifier que CURSOR_API_KEY est correcte : `printenv CURSOR_API_KEY`
- Vérifier les logs : `docker logs <nom-conteneur>`
- **Si ça fonctionne en local mais pas dans Docker :** Reconstruire l'image Docker

#### 4. Augmenter le timeout (recommandé pour Docker)

cursor-agent est **3x plus lent dans Docker** (~19.7s vs ~6.3s en local). Le timeout par défaut est maintenant **120s pour Docker**.

Si vous avez encore des timeouts, augmentez-le :

```env
# Dans .env
CURSOR_AGENT_TIMEOUT=180  # 3 minutes
```

Puis redémarrez le conteneur.

**Note :** Le timeout est automatiquement augmenté à 120s dans les fichiers docker-compose.

## ❌ Problème : cursor-agent non trouvé

### Symptômes

```
Error: cursor-agent command not found
```

### Solutions

1. **Reconstruire l'image Docker**
   ```bash
   just docker-build
   ```

2. **Vérifier le Dockerfile**
   - L'installation de cursor-agent doit réussir
   - Le PATH doit inclure `/root/.local/bin`

3. **Vérifier les logs du build**
   ```bash
   docker build -t cursor-openai-proxy:latest . 2>&1 | grep -i cursor
   ```

## ❌ Problème : Erreur d'authentification

### Symptômes

```
Error: Authentication required. Please run 'cursor-agent login' first
```

### Solutions

1. **Vérifier CURSOR_API_KEY**
   ```bash
   # Dans le conteneur
   docker exec <nom-conteneur> printenv CURSOR_API_KEY
   ```

2. **Vérifier que la clé est correcte**
   - Obtenez votre clé depuis : Cursor → Settings → API Keys
   - Vérifiez qu'elle est bien dans `.env`

3. **Vérifier que la variable est passée au conteneur**
   - Pour Docker Compose : vérifier `docker-compose.yml`
   - Pour Docker Run : vérifier les `-e CURSOR_API_KEY=...`

## ❌ Problème : Connectivité réseau

### Symptômes

```
Timeout lors de la connexion
Erreur réseau
```

### Solutions

1. **Vérifier la connectivité depuis le conteneur**
   ```bash
   docker exec <nom-conteneur> curl -v https://cursor.com
   ```

2. **Vérifier les paramètres réseau Docker**
   - Vérifier que le conteneur peut accéder à Internet
   - Vérifier les pare-feu/proxy

3. **Tester avec un conteneur interactif**
   ```bash
   docker run -it --rm cursor-openai-proxy:latest bash
   # Puis tester cursor-agent
   ```

## 🔧 Commandes utiles

### Voir les logs

```bash
# Docker Compose
docker-compose logs -f

# Docker Run
docker logs -f <nom-conteneur>

# Avec just
just docker-logs
```

### Entrer dans le conteneur

```bash
docker exec -it <nom-conteneur> bash
```

### Vérifier les variables d'environnement

```bash
docker exec <nom-conteneur> env | grep CURSOR
```

### Reconstruire l'image

```bash
just docker-build
# ou
docker build -t cursor-openai-proxy:latest .
```

### Redémarrer le conteneur

```bash
# Docker Compose
docker-compose restart

# Docker Run
docker restart <nom-conteneur>
```

## 📝 Checklist de dépannage

- [ ] cursor-agent est installé dans le conteneur (`which cursor-agent`)
- [ ] cursor-agent peut s'exécuter (`cursor-agent --version`)
- [ ] CURSOR_API_KEY est définie dans le conteneur
- [ ] CURSOR_API_KEY est correcte (depuis Cursor Settings)
- [ ] La connectivité réseau fonctionne (`curl https://cursor.com`)
- [ ] Les logs ne montrent pas d'erreurs évidentes
- [ ] L'image Docker est à jour (reconstruite récemment)
- [ ] Le timeout est suffisant (`CURSOR_AGENT_TIMEOUT`)

## 🆘 Si rien ne fonctionne

1. **Reconstruire complètement**
   ```bash
   docker-compose down
   docker rmi cursor-openai-proxy:latest
   just docker-build
   just docker-up
   ```

2. **Tester en local (sans Docker)**
   ```bash
   just dev
   ```
   Si ça fonctionne en local mais pas dans Docker, le problème vient de Docker.

3. **Vérifier la version de cursor-agent**
   ```bash
   docker exec <nom-conteneur> cursor-agent --version
   ```
   Comparer avec la version locale.

4. **Créer une issue GitHub**
   - Inclure les logs complets
   - Inclure le résultat de `just docker-diagnose`
   - Inclure la version de Docker et de cursor-agent

## 🔗 Références

- [Guide Docker](DOCKER_USAGE.md)
- [Guide de configuration](CONFIGURATION.md)
- [Guide d'intégration](INTEGRATION.md)

---

**Date de dernière mise à jour :** 2025-01-21

