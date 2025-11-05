# Guide de sécurité

Ce guide explique les aspects de sécurité de cursor-cli-to-api.

## ?? Authentification de l'API Proxy

### Qu'est-ce que API_KEY ?

**`API_KEY` n'est PAS une clé li?e ? cursor-agent ou ? Cursor l'?diteur.**

C'est une clé que **VOUS g?n?rez** pour prot?ger **votre API proxy FastAPI**. Elle sert ? authentifier les requêtes vers votre serveur proxy.

### Comment ça fonctionne ?

1. **Sans API_KEY (d?veloppement):**
   - N'importe qui peut appeler votre API
   - Utile pour tester localement
   - ?? Ne jamais utiliser en production sur un serveur accessible publiquement

2. **Avec API_KEY (production):**
   - Toutes les requêtes doivent inclure: `Authorization: Bearer <API_KEY>`
   - Les requêtes sans clé valide sont rejet?es (403)
   - Prot?ge votre API contre les acc?s non autoris?s

### G?n?rer une clé API s?curis?e

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
# R?pondez "oui" ? "Activer l'authentification par API key?"
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

## ?? Authentification de cursor-agent (si nécessaire)

Si cursor-agent lui-m?me nécessite une authentification (token API), c'est diff?rent et doit ?tre g?r? dans les fonctions d'intégration.

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
- `API_KEY` = Cl? pour prot?ger VOTRE API proxy
- `CURSOR_AGENT_TOKEN` = Token pour authentifier les appels vers cursor-agent (si cursor-agent le nécessite)

## ??? Recommandations de sécurité

### En d?veloppement

```env
# Pas d'authentification nécessaire
API_KEY=

# Logs détaill?s pour le débogage
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
   - Voir `DEPLOYMENT.md` pour la configuration

2. **Rate Limiting:**
   - Activez le `RateLimitMiddleware` dans `main.py`:
   ```python
   app.add_middleware(RateLimitMiddleware, requests_per_minute=60)
   ```

3. **Firewall:**
   - Limitez l'acc?s au port 8000 uniquement aux IPs autoris?es
   - Utilisez un reverse proxy (Nginx) pour un contr?le plus fin

4. **Validation des entr?es:**
   - L'API valide d?j? les entr?es avec Pydantic
   - Adaptez les validations selon vos besoins

5. **Logs et monitoring:**
   - Surveillez les logs pour d?tecter les tentatives d'acc?s suspectes
   - Configurez des alertes en cas d'erreurs r?p?t?es

## ?? Bonnes pratiques

1. **Ne jamais commiter `.env`:**
   - Le fichier `.env` est d?j? dans `.gitignore`
   - Ne jamais partager vos clés API

2. **Rotation des clés:**
   - Changez r?guli?rement vos clés API en production
   - Utilisez des clés diff?rentes pour chaque environnement

3. **Gestion des secrets:**
   - Utilisez un gestionnaire de secrets (HashiCorp Vault, AWS Secrets Manager) en production
   - Ne stockez jamais de secrets dans le code

4. **Limitation des permissions:**
   - Si cursor-agent nécessite des permissions sp?cifiques, vérifiez-les avant de les accorder

## ?? D?pannage

### Erreur 401/403

- V?rifiez que `API_KEY` est correctement défini dans `.env`
- V?rifiez que le header `Authorization: Bearer <API_KEY>` est présent
- V?rifiez qu'il n'y a pas d'espaces dans la clé

### L'authentification ne fonctionne pas

- Redémarrez le serveur apr?s modification de `.env`
- V?rifiez les logs pour voir les erreurs d'authentification
- V?rifiez que `API_KEY` n'est pas vide si vous essayez de l'utiliser
