# Points à améliorer

Ce document liste les améliorations possibles pour le projet cursor-openai-proxy, classées par priorité.

## 🔴 Priorité Haute

### 1. Implémenter le mode library

**Problème actuel :**
Le mode `library` est déclaré mais non implémenté, levant une `NotImplementedError`.

**Fichier concerné :** `main.py`

**Solution :**
```python
async def _call_cursor_agent_library(messages: List[Message], model: str) -> str:
    """
    Appel via bibliothèque Python
    
    Args:
        messages: Liste des messages
        model: Le modèle à utiliser (déjà mappé au format cursor-agent)
    """
    # TODO: Implémenter selon la bibliothèque cursor-agent disponible
    # Exemple d'implémentation:
    # from cursor_agent import CursorAgent
    # agent = CursorAgent(model=model, api_key=settings.cursor_api_key)
    # return await agent.chat(messages)
    
    raise NotImplementedError(
        "Mode library non implémenté. "
        "Modifiez _call_cursor_agent_library() dans main.py pour intégrer votre bibliothèque."
    )
```

**Impact :** Bloque l'utilisation du mode library, réduisant la flexibilité du projet.

---

### 2. Améliorer le comptage de tokens

**Problème actuel :**
Le comptage de tokens utilise une approximation basique (1 token ≈ 4 caractères), ce qui peut fausser les métriques.

**Fichier concerné :** `main.py`, fonction `count_tokens()`

**Solution :**
```python
import tiktoken

def count_tokens(text: str, model: str = "gpt-4") -> int:
    """
    Compte précis des tokens avec tiktoken
    
    Args:
        text: Texte à compter
        model: Modèle pour déterminer l'encodage (par défaut gpt-4)
    
    Returns:
        Nombre de tokens
    """
    try:
        # Utiliser l'encodage approprié selon le modèle
        encoding = tiktoken.encoding_for_model(model)
        return len(encoding.encode(text))
    except KeyError:
        # Fallback sur cl100k_base (utilisé par GPT-4)
        encoding = tiktoken.get_encoding("cl100k_base")
        return len(encoding.encode(text))
```

**Dépendance à ajouter :**
```toml
# Dans pyproject.toml
dependencies = [
    # ... autres dépendances
    "tiktoken>=0.5.0",
]
```

**Impact :** Améliore la précision des métriques d'utilisation (usage tokens).

---

### 3. Améliorer le streaming

**Problème actuel :**
Le streaming est simulé en découpant la réponse par mots, ce qui n'est pas un vrai streaming depuis cursor-agent.

**Fichier concerné :** `main.py`, fonction `chat_completions_stream()`

**Solution :**
- Si cursor-agent supporte le streaming, utiliser son streaming natif
- Sinon, implémenter un streaming progressif plus réaliste

**Exemple d'amélioration :**
```python
@app.post("/v1/chat/completions-stream")
async def chat_completions_stream(request: ChatCompletionRequest):
    """
    Endpoint pour le streaming (Server-Sent Events) compatible OpenAI
    """
    async def generate():
        try:
            cursor_model = map_model_name(request.model)
            
            # Si cursor-agent supporte le streaming, l'utiliser directement
            # Sinon, utiliser un streaming progressif
            async for chunk in stream_cursor_agent(request.messages, cursor_model):
                yield f"data: {chunk.model_dump_json()}\n\n"
            
            yield "data: [DONE]\n\n"
            
        except Exception as e:
            error_chunk = {
                "error": {
                    "message": str(e),
                    "type": "server_error"
                }
            }
            yield f"data: {json.dumps(error_chunk)}\n\n"
    
    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        }
    )
```

**Impact :** Améliore l'expérience utilisateur avec un streaming plus fluide et réaliste.

---

## 🟡 Priorité Moyenne

### 4. Validation de configuration

**Problème actuel :**
La configuration n'a pas de validation stricte des valeurs (ex. `cursor_agent_mode` peut être n'importe quelle chaîne).

**Fichier concerné :** `config.py`

**Solution :**
```python
from typing import Literal
from pydantic import field_validator

class Settings(BaseSettings):
    # ... autres champs
    
    cursor_agent_mode: Literal["cli", "http", "library"] = "cli"
    
    @field_validator("cursor_agent_http_url")
    @classmethod
    def validate_http_url(cls, v, info):
        mode = info.data.get("cursor_agent_mode")
        if mode == "http" and not v:
            raise ValueError("CURSOR_AGENT_HTTP_URL est requis en mode HTTP")
        if v and not v.startswith(("http://", "https://")):
            raise ValueError("CURSOR_AGENT_HTTP_URL doit être une URL valide")
        return v
```

**Impact :** Détecte les erreurs de configuration plus tôt, évite les erreurs à l'exécution.

---

### 5. Rate limiting distribué

**Problème actuel :**
Le rate limiting utilise un dictionnaire en mémoire, non adapté à plusieurs instances.

**Fichier concerné :** `middleware.py`

**Solution :**
Utiliser Redis pour un rate limiting partagé entre instances :

```python
import redis.asyncio as redis
from datetime import timedelta

class RateLimitMiddleware(BaseHTTPMiddleware):
    """Middleware pour le rate limiting avec Redis"""
    
    def __init__(self, app, requests_per_minute: int = 60, redis_url: str = None):
        super().__init__(app)
        self.requests_per_minute = requests_per_minute
        self.redis_client = None
        if redis_url:
            self.redis_client = redis.from_url(redis_url)
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        if not self.redis_client:
            # Fallback sur le rate limiting en mémoire
            return await self._in_memory_rate_limit(request, call_next)
        
        client_ip = request.client.host
        key = f"rate_limit:{client_ip}"
        
        # Utiliser Redis pour le comptage
        current = await self.redis_client.incr(key)
        if current == 1:
            await self.redis_client.expire(key, timedelta(minutes=1))
        
        if current > self.requests_per_minute:
            logger.warning(f"Rate limit dépassé pour {client_ip}")
            return Response(
                content='{"error": "Rate limit exceeded"}',
                status_code=429,
                media_type="application/json"
            )
        
        response = await call_next(request)
        return response
```

**Dépendance à ajouter :**
```toml
dependencies = [
    # ... autres dépendances
    "redis>=5.0.0",
]
```

**Impact :** Permet le scaling horizontal avec plusieurs instances du serveur.

---

### 6. Cache des réponses

**Problème actuel :**
Chaque requête appelle cursor-agent, même pour des requêtes identiques.

**Solution :**
Implémenter un cache simple pour les requêtes identiques :

```python
from functools import lru_cache
import hashlib
import json

# Cache en mémoire (ou utiliser Redis pour un cache distribué)
response_cache = {}

def get_cache_key(messages: List[Message], model: str) -> str:
    """Génère une clé de cache basée sur les messages et le modèle"""
    cache_data = {
        "messages": [{"role": m.role, "content": m.content} for m in messages],
        "model": model
    }
    cache_str = json.dumps(cache_data, sort_keys=True)
    return hashlib.sha256(cache_str.encode()).hexdigest()

@app.post("/v1/chat/completions", response_model=ChatCompletionResponse)
async def chat_completions(request: ChatCompletionRequest):
    # Vérifier le cache (optionnel, peut être désactivé)
    if settings.enable_cache:
        cache_key = get_cache_key(request.messages, request.model)
        if cache_key in response_cache:
            logger.info(f"Cache hit pour {cache_key[:8]}...")
            return response_cache[cache_key]
    
    # ... code existant ...
    
    # Stocker dans le cache
    if settings.enable_cache:
        response_cache[cache_key] = response
        # Nettoyer le cache périodiquement (ou utiliser TTL avec Redis)
    
    return response
```

**Impact :** Réduit la charge sur cursor-agent et améliore les temps de réponse pour les requêtes répétées.

---

## 🟢 Priorité Basse

### 7. Métriques et monitoring

**Problème actuel :**
Pas de métriques de performance ou de monitoring.

**Solution :**
Ajouter Prometheus/OpenTelemetry pour les métriques :

```python
from prometheus_client import Counter, Histogram, generate_latest
from fastapi.responses import Response

# Métriques
request_count = Counter('api_requests_total', 'Total API requests', ['method', 'endpoint'])
request_duration = Histogram('api_request_duration_seconds', 'API request duration')

@app.get("/metrics")
async def metrics():
    """Endpoint Prometheus pour les métriques"""
    return Response(content=generate_latest(), media_type="text/plain")

# Dans les middlewares, enregistrer les métriques
request_count.labels(method=request.method, endpoint=request.url.path).inc()
request_duration.observe(process_time)
```

**Impact :** Permet le monitoring et l'analyse des performances en production.

---

### 8. Améliorer la conversion des messages

**Problème actuel :**
La conversion des messages en prompt simple perd le contexte des rôles (system/user/assistant).

**Fichier concerné :** `main.py`, fonction `call_cursor_agent()`

**Solution :**
Améliorer la conversion pour préserver le contexte :

```python
def format_messages_for_cursor_agent(messages: List[Message]) -> str:
    """
    Convertit les messages au format attendu par cursor-agent
    en préservant le contexte des rôles
    """
    formatted = []
    for msg in messages:
        if msg.role == "system":
            formatted.append(f"System: {msg.content}")
        elif msg.role == "user":
            formatted.append(f"User: {msg.content}")
        elif msg.role == "assistant":
            formatted.append(f"Assistant: {msg.content}")
    
    return "\n".join(formatted)
```

**Impact :** Améliore la qualité des réponses en préservant mieux le contexte de la conversation.

---

### 9. Gestion des erreurs plus détaillée

**Problème actuel :**
Les erreurs sont génériques, peu d'informations pour le débogage.

**Solution :**
Ajouter des codes d'erreur spécifiques et des messages plus détaillés :

```python
class CursorAgentError(Exception):
    """Erreur spécifique pour cursor-agent"""
    def __init__(self, message: str, error_code: str = None, details: dict = None):
        self.message = message
        self.error_code = error_code
        self.details = details or {}
        super().__init__(self.message)

# Dans les handlers
except subprocess.TimeoutExpired:
    raise HTTPException(
        status_code=504,
        detail={
            "error": "timeout",
            "message": f"Timeout lors de l'appel à cursor-agent (>{settings.cursor_agent_timeout}s)",
            "timeout": settings.cursor_agent_timeout
        }
    )
```

**Impact :** Facilite le débogage et la résolution des problèmes.

---

### 10. Tests de charge

**Problème actuel :**
Pas de tests de charge pour valider les performances.

**Solution :**
Ajouter des tests de charge avec `locust` ou `pytest-benchmark` :

```python
# tests/test_load.py
import pytest
from locust import HttpUser, task, between

class APIUser(HttpUser):
    wait_time = between(1, 3)
    
    @task
    def chat_completion(self):
        self.client.post(
            "/v1/chat/completions",
            json={
                "model": "auto",
                "messages": [{"role": "user", "content": "Test"}]
            },
            headers={"Authorization": f"Bearer {API_KEY}"}
        )
```

**Impact :** Permet d'identifier les goulots d'étranglement avant la mise en production.

---

## 📋 Checklist d'implémentation

### Priorité Haute
- [ ] Implémenter le mode library
- [ ] Améliorer le comptage de tokens avec tiktoken
- [ ] Améliorer le streaming

### Priorité Moyenne
- [ ] Ajouter la validation de configuration
- [ ] Implémenter le rate limiting distribué avec Redis
- [ ] Ajouter un cache des réponses

### Priorité Basse
- [ ] Ajouter des métriques et monitoring
- [ ] Améliorer la conversion des messages
- [ ] Améliorer la gestion des erreurs
- [ ] Ajouter des tests de charge

---

## 🔗 Références

- [tiktoken Documentation](https://github.com/openai/tiktoken)
- [Redis Python Client](https://redis.readthedocs.io/)
- [Prometheus Python Client](https://github.com/prometheus/client_python)
- [FastAPI Best Practices](https://fastapi.tiangolo.com/tutorial/)

