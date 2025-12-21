# Guide de sécurité

Ce guide explique les aspects de sécurité de cursor-openai-proxy.

## 🔐 Authentification de l'API Proxy

### Qu'est-ce que API_KEY ?

**`API_KEY` n'est PAS une clé liée à cursor-agent ou à Cursor l'éditeur.**

C'est une clé que **VOUS générez** pour protéger **votre API proxy FastAPI**. Elle sert à authentifier les requêtes vers votre serveur proxy.

### Comment ça fonctionne ?

1. **Sans API_KEY (développement):**
   - N'importe qui peut appeler votre API
   - Utile pour tester localement
   - ⚠️ Ne jamais utiliser en production sur un serveur accessible publiquement

2. **Avec API_KEY (production):**
   - Toutes les requêtes doivent inclure: `Authorization: Bearer <API_KEY>`
   - Les requêtes sans clé valide sont rejetées (403)
   - Protège votre API contre les accès non autorisés

### Générer une clé API sécurisée

**Avec Python:**
```bash
python -c "import secrets; print('sk-' + secrets.token_urlsafe(32))"
```

**Avec OpenSSL:**
```bash
echo "sk-$(openssl rand -hex 32)"
```

**Avec le script de configuration:**
```bash
just setup-env
# Répondez "oui" à "Activer l'authentification par API key?"
```

### Utiliser l'API avec authentification

**Avec curl:**
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Authorization: Bearer sk-votre-cle-ici" \
  -H "Content-Type: application/json" \
  -d '{"model": "cursor-agent", "messages": [{"role": "user", "content": "Bonjour"}]}'
```

**Avec le client OpenAI Python:**
```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="sk-votre-cle-ici"  # Votre API_KEY ici
)

response = client.chat.completions.create(
    model="cursor-agent",
    messages=[{"role": "user", "content": "Bonjour"}]
)
```

## 🔑 Authentification de cursor-agent (si nécessaire)

Si cursor-agent lui-même nécessite une authentification (token API), c'est différent et doit être géré dans les fonctions d'intégration.

### Mode HTTP avec authentification cursor-agent

Si cursor-agent nécessite un token, modifiez `_call_cursor_agent_http()` dans `main.py`:

```python
async def _call_cursor_agent_http(messages: List[Message]) -> str:
    url = settings.cursor_agent_http_url
    cursor_agent_token = os.getenv("CURSOR_AGENT_TOKEN")  # Token pour cursor-agent
    
    payload = {"messages": [{"role": msg.role, "content": msg.content} for msg in messages]}
    headers = {}
    
    if cursor_agent_token:
        headers["Authorization"] = f"Bearer {cursor_agent_token}"
    
    async with httpx.AsyncClient(timeout=settings.cursor_agent_timeout) as client:
        response = await client.post(url, json=payload, headers=headers)
        response.raise_for_status()
        data = response.json()
        return data.get("response") or data.get("content") or str(data)
```

Puis ajoutez dans `.env`:
```env
# Token pour authentifier les appels vers cursor-agent (si nécessaire)
CURSOR_AGENT_TOKEN=votre-token-cursor-agent
```

**Note:** Ne confondez pas:
- `API_KEY` = Clé pour protéger VOTRE API proxy
- `CURSOR_AGENT_TOKEN` = Token pour authentifier les appels vers cursor-agent (si cursor-agent le nécessite)

## 🛡️ Recommandations de sécurité

### En développement

```env
# Pas d'authentification nécessaire
API_KEY=

# Logs détaillés pour le débogage
LOG_LEVEL=DEBUG
```

### En production

```env
# Authentification activée
API_KEY=sk-generate-a-secure-random-key-here

# Logs standards
LOG_LEVEL=INFO

# Pas de rechargement automatique
RELOAD=false
```

### Autres mesures de sécurité

1. **HTTPS/TLS:**
   - Utilisez HTTPS en production (avec Nginx + Let's Encrypt)
   - Voir [DEPLOYMENT.md](DEPLOYMENT.md) pour la configuration

2. **Rate Limiting:**
   - Activez le `RateLimitMiddleware` dans `main.py`:
   ```python
   app.add_middleware(RateLimitMiddleware, requests_per_minute=60)
   ```

3. **Firewall:**
   - Limitez l'accès au port 8000 uniquement aux IPs autorisées
   - Utilisez un reverse proxy (Nginx) pour un contrôle plus fin

4. **Validation des entrées:**
   - L'API valide déjà les entrées avec Pydantic
   - Adaptez les validations selon vos besoins

5. **Logs et monitoring:**
   - Surveillez les logs pour détecter les tentatives d'accès suspectes
   - Configurez des alertes en cas d'erreurs répétées

## ✅ Bonnes pratiques

1. **Ne jamais commiter `.env`:**
   - Le fichier `.env` est déjà dans `.gitignore`
   - Ne jamais partager vos clés API

2. **Rotation des clés:**
   - Changez régulièrement vos clés API en production
   - Utilisez des clés différentes pour chaque environnement

3. **Gestion des secrets:**
   - Utilisez un gestionnaire de secrets (HashiCorp Vault, AWS Secrets Manager) en production
   - Ne stockez jamais de secrets dans le code

4. **Limitation des permissions:**
   - Si cursor-agent nécessite des permissions spécifiques, vérifiez-les avant de les accorder

## 🔧 Dépannage

### Erreur 401/403

- Vérifiez que `API_KEY` est correctement défini dans `.env`
- Vérifiez que le header `Authorization: Bearer <API_KEY>` est présent
- Vérifiez qu'il n'y a pas d'espaces dans la clé

### L'authentification ne fonctionne pas

- Redémarrez le serveur après modification de `.env`
- Vérifiez les logs pour voir les erreurs d'authentification
- Vérifiez que `API_KEY` n'est pas vide si vous essayez de l'utiliser
