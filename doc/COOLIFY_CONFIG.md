# Configuration Coolify

Guide pour configurer correctement l'application sur Coolify.

## Variables d'environnement requises

### Variables obligatoires

Ces variables doivent être configurées dans Coolify → Configuration → Environment Variables :

```bash
# Authentification Cursor (OBLIGATOIRE)
CURSOR_API_KEY=key_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Authentification API (recommandé pour sécuriser votre proxy)
API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### Variables optionnelles (recommandées)

Ces variables ont des valeurs par défaut mais il est recommandé de les configurer explicitement :

```bash
# Mode d'exécution de cursor-agent (défaut: cli)
CURSOR_AGENT_MODE=cli

# Timeout pour les appels à cursor-agent en secondes (défaut: 120)
# Recommandé: 120-180 pour Docker/Coolify
CURSOR_AGENT_TIMEOUT=120

# Niveau de log (défaut: INFO)
# Options: DEBUG, INFO, WARNING, ERROR
LOG_LEVEL=INFO
```

## Configuration dans Coolify

### Étape 1: Accéder aux variables d'environnement

1. Allez dans votre projet sur Coolify
2. Cliquez sur **Configuration**
3. Dans le menu de gauche, cliquez sur **Environment Variables**

### Étape 2: Ajouter les variables

Ajoutez les variables suivantes :

| Variable | Valeur | Description |
|----------|--------|-------------|
| `CURSOR_API_KEY` | `key_...` | Token Cursor (obligatoire) |
| `API_KEY` | `sk-...` | Clé API pour sécuriser le proxy (recommandé) |
| `CURSOR_AGENT_MODE` | `cli` | Mode d'exécution (défaut: cli) |
| `CURSOR_AGENT_TIMEOUT` | `120` | Timeout en secondes (défaut: 120) |
| `LOG_LEVEL` | `INFO` | Niveau de log (défaut: INFO) |

### Étape 3: Sauvegarder et redéployer

1. Cliquez sur **Save**
2. Redéployez l'application pour que les nouvelles variables prennent effet

## Valeurs par défaut

Si vous ne configurez pas ces variables, l'application utilisera ces valeurs par défaut :

- `CURSOR_AGENT_MODE`: `cli`
- `CURSOR_AGENT_TIMEOUT`: `120` (secondes)
- `LOG_LEVEL`: `INFO`

**Note importante** : Le timeout par défaut est maintenant de 120s (au lieu de 60s) pour être adapté à Docker/Coolify où cursor-agent est plus lent.

## Vérification

Après le déploiement, vous pouvez vérifier que les variables sont bien configurées :

```bash
# Depuis le terminal Coolify ou via docker exec
docker exec <container-name> env | grep -E "CURSOR_AGENT|LOG_LEVEL"
```

Ou utilisez l'endpoint de debug :

```bash
curl https://votre-domaine.com/debug/models | jq '.cursor_api_key_configured'
```

## Dépannage

### Problème : Timeout lors des appels de completion

**Solution** : Augmentez `CURSOR_AGENT_TIMEOUT` à 180 ou 240 secondes :

```bash
CURSOR_AGENT_TIMEOUT=180
```

### Problème : Peu de modèles détectés

**Solution** : Vérifiez que `CURSOR_API_KEY` est correctement configurée et valide.

### Problème : Logs insuffisants pour déboguer

**Solution** : Changez `LOG_LEVEL` à `DEBUG` :

```bash
LOG_LEVEL=DEBUG
```

**Attention** : Les logs DEBUG sont très verbeux, revenez à `INFO` en production.

## Comparaison avec Docker local

Sur votre Docker local, ces variables sont probablement définies dans votre fichier `.env` :

```bash
# .env (local)
CURSOR_API_KEY=key_...
API_KEY=sk-...
CURSOR_AGENT_MODE=cli
CURSOR_AGENT_TIMEOUT=120
LOG_LEVEL=INFO
```

Sur Coolify, vous devez les configurer manuellement dans l'interface, car Coolify ne lit pas automatiquement un fichier `.env` du dépôt Git.

## Recommandations

1. **Toujours configurer `CURSOR_API_KEY`** : Sans cette variable, cursor-agent ne fonctionnera pas
2. **Configurer `API_KEY`** : Pour sécuriser votre proxy et éviter les accès non autorisés
3. **Utiliser `CURSOR_AGENT_TIMEOUT=120` minimum** : Pour éviter les timeouts sur Coolify
4. **Utiliser `LOG_LEVEL=INFO` en production** : Pour avoir des logs utiles sans être trop verbeux

