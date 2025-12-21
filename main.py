"""
FastAPI proxy pour cursor-agent compatible avec l'API ChatGPT/OpenAI

Note sur les performances:
- cursor-agent est un outil CLI uniquement (pas de mode HTTP)
- Tests réalisés: cursor-agent CLI direct prend ~6.3s en moyenne
- Via API (subprocess): ~6.3s également (overhead minimal ~10%)
- Le temps est principalement passé dans cursor-agent lui-même (appel LLM, traitement)
- Les 5-7 secondes sont normaux et attendus pour cursor-agent
- Le mode HTTP dans le code est prévu pour un cas hypothétique ou futur
"""
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import json
import asyncio
import subprocess
import httpx
import uuid
import logging
import os
from datetime import datetime

from config import settings
from middleware import LoggingMiddleware, AuthMiddleware, RateLimitMiddleware

# Configuration du logging
logging.basicConfig(
    level=getattr(logging, settings.log_level.upper()),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title=settings.api_title,
    description=settings.api_description,
    version=settings.api_version
)


@app.on_event("startup")
async def startup_event():
    """
    Initialise le cache des modèles au démarrage pour éviter le premier appel lent
    """
    logger.info("Initialisation du cache des modèles disponibles...")
    try:
        await get_available_models()
        logger.info("Cache des modèles initialisé avec succès")
    except Exception as e:
        logger.warning(f"Impossible d'initialiser le cache des modèles au démarrage: {e}")
        logger.info("Le cache sera initialisé au premier appel")


# Ajouter les middlewares
app.add_middleware(LoggingMiddleware)
if settings.api_key:
    app.add_middleware(AuthMiddleware)
    logger.info("Authentification activée via API key")
# Rate limiting optionnel (décommenter si nécessaire)
# app.add_middleware(RateLimitMiddleware, requests_per_minute=60)


# Modèles Pydantic pour l'API OpenAI-compatible
class Message(BaseModel):
    role: str  # "system", "user", "assistant"
    content: str


class ChatCompletionRequest(BaseModel):
    model: str = "auto"  # Modèle par défaut de cursor-agent (auto-sélection)
    messages: List[Message]
    temperature: Optional[float] = 0.7
    max_tokens: Optional[int] = None
    stream: Optional[bool] = False
    top_p: Optional[float] = 1.0
    frequency_penalty: Optional[float] = 0.0
    presence_penalty: Optional[float] = 0.0
    stop: Optional[List[str]] = None


class Choice(BaseModel):
    index: int
    message: Message
    finish_reason: Optional[str] = "stop"


class Usage(BaseModel):
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int


class ChatCompletionResponse(BaseModel):
    id: str
    object: str = "chat.completion"
    created: int
    model: str
    choices: List[Choice]
    usage: Usage


class ChatCompletionChunk(BaseModel):
    id: str
    object: str = "chat.completion.chunk"
    created: int
    model: str
    choices: List[Dict[str, Any]]


# Cache pour la liste des modèles disponibles (mis à jour dynamiquement)
_available_models_cache: Optional[List[str]] = None
_cache_timestamp: Optional[float] = None
CACHE_DURATION = 3600  # 1 heure (augmenté pour réduire les appels)

# Mapping optionnel pour les alias de compatibilité (OpenAI/Anthropic)
# Ces alias sont mappés vers les modèles cursor-agent réels
ALIAS_MAPPING = {
    # Alias OpenAI → modèles GPT (mappage intelligent selon disponibilité)
    "gpt-4o": None,  # Sera mappé dynamiquement vers gpt-5.2 ou gpt-5.1
    "gpt-4o-mini": None,  # Sera mappé dynamiquement
    "gpt-4-turbo": None,
    "gpt-4": None,
    "gpt-3.5-turbo": None,
    
    # Alias Anthropic Claude Sonnet
    "claude-3-5-sonnet-20241022": "sonnet-4.5",
    "claude-3-5-sonnet": "sonnet-4.5",
    "claude-sonnet-4.5": "sonnet-4.5",
    "claude-sonnet-4": "sonnet-4.5",
    "sonnet-4": "sonnet-4.5",
    
    # Alias Anthropic Claude Sonnet thinking
    "claude-3-5-sonnet-thinking": "sonnet-4.5-thinking",
    "sonnet-4-thinking": "sonnet-4.5-thinking",
    
    # Alias Anthropic Opus
    "claude-opus-4": None,  # Sera mappé vers opus-4.5 ou opus-4.1 selon disponibilité
    "claude-4-opus": None,
    
    # Modèles génériques
    "cursor-agent": "auto",
    "default": "auto",
    "auto": "auto",
}


async def get_available_models() -> List[str]:
    """
    Récupère la liste des modèles disponibles depuis cursor-agent.
    Utilise un cache pour éviter d'interroger cursor-agent à chaque requête.
    
    Returns:
        Liste des noms de modèles disponibles
    """
    global _available_models_cache, _cache_timestamp
    
    # Vérifier le cache
    current_time = datetime.now().timestamp()
    if _available_models_cache and _cache_timestamp:
        if current_time - _cache_timestamp < CACHE_DURATION:
            return _available_models_cache
    
    # Récupérer la liste depuis cursor-agent
    try:
        # Essayer d'obtenir la liste via une commande cursor-agent
        # Si cursor-agent ne supporte pas --list-models, on utilise une méthode de fallback
        cli_path = settings.cursor_agent_cli_path or "cursor-agent"
        env = os.environ.copy()
        if settings.cursor_api_key:
            env["CURSOR_API_KEY"] = settings.cursor_api_key
        
        # Méthode 1: Essayer avec un modèle invalide pour obtenir la liste
        # (cursor-agent retourne la liste dans le message d'erreur)
        # Réduire le timeout pour éviter les longs délais
        loop = asyncio.get_event_loop()
        result = await loop.run_in_executor(
            None,
            lambda: subprocess.run(
                [cli_path, "--model", "invalid-model-test", "test"],
                capture_output=True,
                text=True,
                timeout=3,  # Réduit de 10s à 3s pour éviter les longs délais
                env=env
            )
        )
        
        # Parser la liste depuis le message d'erreur
        # Le message peut être dans stderr ou stdout
        error_msg = result.stderr or result.stdout or ""
        
        if result.returncode != 0 and "Available models:" in error_msg:
            # Extraire la liste des modèles depuis le message d'erreur
            # Format: "Available models: composer-1, auto, sonnet-4.5, ..."
            models_line = error_msg.split("Available models:")[1].strip()
            # Prendre seulement la première ligne (avant \n si présent)
            models_line = models_line.split("\n")[0].strip()
            # Parser: "composer-1, auto, sonnet-4.5, ..."
            models = [m.strip() for m in models_line.split(",") if m.strip()]
            if models:
                _available_models_cache = models
                _cache_timestamp = current_time
                logger.info(f"Modèles disponibles détectés: {models}")
                return models
        
        # Méthode 2: Fallback - utiliser une liste par défaut si la détection échoue
        logger.warning("Impossible de détecter les modèles, utilisation de la liste par défaut")
        default_models = ["auto", "composer-1"]
        _available_models_cache = default_models
        _cache_timestamp = current_time
        return default_models
        
    except Exception as e:
        logger.error(f"Erreur lors de la récupération des modèles: {e}")
        # Fallback vers une liste minimale
        default_models = ["auto", "composer-1"]
        _available_models_cache = default_models
        _cache_timestamp = current_time
        return default_models


def map_model_name(model: str, available_models: List[str]) -> str:
    """
    Mappe un nom de modèle vers un nom de modèle cursor-agent valide.
    Utilise la liste dynamique des modèles disponibles.
    
    Args:
        model: Nom du modèle (format OpenAI, Anthropic ou cursor-agent)
        available_models: Liste des modèles disponibles depuis cursor-agent
    
    Returns:
        Nom du modèle au format cursor-agent valide
    """
    model_lower = model.lower()
    
    # Vérifier d'abord si c'est déjà un modèle cursor-agent valide
    if model in available_models:
        logger.info(f"Modèle '{model}' utilisé tel quel (modèle cursor-agent)")
        return model
    
    # Vérifier les alias avec mapping fixe
    if model_lower in ALIAS_MAPPING:
        mapped = ALIAS_MAPPING[model_lower]
        if mapped and mapped in available_models:
            logger.info(f"Modèle '{model}' mappé vers '{mapped}' (alias)")
            return mapped
        elif mapped is None:
            # Mapping intelligent pour les alias None (gpt-4o, opus, etc.)
            # Chercher le meilleur modèle disponible
            if model_lower.startswith("gpt-"):
                # Chercher un modèle GPT disponible
                for gpt_model in ["gpt-5.2", "gpt-5.1", "gpt-5"]:
                    if gpt_model in available_models:
                        logger.info(f"Modèle '{model}' mappé vers '{gpt_model}' (alias GPT)")
                        return gpt_model
            elif "opus" in model_lower:
                # Chercher un modèle Opus disponible
                for opus_model in ["opus-4.5", "opus-4.1"]:
                    if opus_model in available_models:
                        logger.info(f"Modèle '{model}' mappé vers '{opus_model}' (alias Opus)")
                        return opus_model
    
    # Si aucun mapping trouvé, utiliser le modèle par défaut
    default_model = "auto" if "auto" in available_models else available_models[0] if available_models else "auto"
    logger.warning(f"Modèle '{model}' non reconnu, utilisation de '{default_model}'")
    return default_model


async def call_cursor_agent(messages: List[Message], model: str = "auto") -> str:
    """
    Appelle cursor-agent avec les messages fournis.
    
    Supporte trois modes:
    - cli: Appel via ligne de commande
    - http: Appel via API HTTP
    - library: Appel via bibliothèque Python (à implémenter)
    
    Args:
        messages: Liste des messages de la conversation
        model: Nom du modèle cursor-agent à utiliser (déjà mappé)
    """
    import time
    start_time = time.time()
    
    mode = settings.cursor_agent_mode.lower()
    logger.info(f"Appel à cursor-agent en mode: {mode}, modèle: {model}")
    
    # Convertir les messages en format attendu
    format_start = time.time()
    prompt = "\n".join([f"{msg.role}: {msg.content}" for msg in messages])
    format_duration = (time.time() - format_start) * 1000
    logger.debug(f"Formatage des messages: {format_duration:.2f}ms")
    
    try:
        if mode == "cli":
            return await _call_cursor_agent_cli(prompt, model)
        elif mode == "http":
            return await _call_cursor_agent_http(messages, model)
        elif mode == "library":
            return await _call_cursor_agent_library(messages, model)
        else:
            # Mode simulation par défaut pour les tests
            logger.warning(f"Mode '{mode}' non reconnu, utilisation du mode simulation")
            await asyncio.sleep(0.1)
            return f"Réponse simulée de cursor-agent (modèle: {model}) pour: {prompt[:50]}..."
            
    except subprocess.TimeoutExpired:
        logger.error("Timeout lors de l'appel à cursor-agent")
        raise HTTPException(
            status_code=504,
            detail=f"Timeout lors de l'appel à cursor-agent (>{settings.cursor_agent_timeout}s)"
        )
    except Exception as e:
        logger.error(f"Erreur lors de l'appel à cursor-agent: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de l'appel à cursor-agent: {str(e)}"
        )


async def _call_cursor_agent_cli(prompt: str, model: str) -> str:
    """
    Appel via CLI
    
    Args:
        prompt: Le prompt à envoyer à cursor-agent
        model: Le modèle à utiliser (déjà mappé au format cursor-agent)
    """
    import time
    start_time = time.time()
    
    cli_path = settings.cursor_agent_cli_path or "cursor-agent"
    
    # Préparer l'environnement avec le token si disponible
    env = os.environ.copy()
    if settings.cursor_api_key:
        # cursor-agent attend CURSOR_API_KEY
        env["CURSOR_API_KEY"] = settings.cursor_api_key
    
    # Construire la commande avec le modèle
    # Utiliser --print pour le mode non-interactif (plus rapide pour les scripts)
    # Utiliser --output-format text pour éviter le parsing JSON (plus rapide)
    # Format: cursor-agent --print --model <model> <prompt>
    cmd = [cli_path, "--print", "--output-format", "text", "--model", model, prompt]
    logger.debug(f"Commande cursor-agent: {' '.join(cmd[:5])}... (prompt: {len(prompt)} chars)")
    
    # Mesurer le temps avant l'appel subprocess
    pre_subprocess_time = time.time()
    logger.debug(f"Temps avant subprocess: {(pre_subprocess_time - start_time)*1000:.2f}ms")
    
    # Exécuter dans un thread pour ne pas bloquer l'event loop
    # Note: L'overhead du subprocess est inévitable en mode CLI
    # Chaque appel crée un nouveau processus cursor-agent qui doit :
    # 1. S'initialiser (charger Node.js, dépendances, etc.)
    # 2. Se connecter au service Cursor
    # 3. S'authentifier
    # 4. Traiter la requête
    # C'est pourquoi c'est plus lent qu'un appel CLI direct où cursor-agent reste en mémoire
    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(
        None,
        lambda: subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=settings.cursor_agent_timeout,
            env=env
        )
    )
    
    # Mesurer le temps après l'appel subprocess
    post_subprocess_time = time.time()
    subprocess_duration = (post_subprocess_time - pre_subprocess_time) * 1000
    total_duration = (post_subprocess_time - start_time) * 1000
    logger.info(f"cursor-agent subprocess: {subprocess_duration:.2f}ms (total: {total_duration:.2f}ms)")
    
    if result.returncode != 0:
        logger.error(f"cursor-agent stderr: {result.stderr[:500]}")
        raise RuntimeError(f"cursor-agent a retourné le code {result.returncode}: {result.stderr}")
    
    return result.stdout.strip()


async def _call_cursor_agent_http(messages: List[Message], model: str) -> str:
    """
    Appel via API HTTP
    
    Args:
        messages: Liste des messages
        model: Le modèle à utiliser (déjà mappé au format cursor-agent)
    """
    import time
    start_time = time.time()
    
    if not settings.cursor_agent_http_url:
        raise ValueError("CURSOR_AGENT_HTTP_URL doit être défini pour le mode HTTP")
    
    url = settings.cursor_agent_http_url
    payload = {
        "model": model,
        "messages": [{"role": msg.role, "content": msg.content} for msg in messages]
    }
    
    # Préparer les headers avec authentification si token disponible
    headers = {"Content-Type": "application/json"}
    if settings.cursor_api_key:
        headers["Authorization"] = f"Bearer {settings.cursor_api_key}"
    
    logger.info(f"Requête HTTP à cursor-agent: {url} avec modèle {model}")
    
    # Mesurer le temps de la requête HTTP
    http_start = time.time()
    try:
        async with httpx.AsyncClient(timeout=settings.cursor_agent_timeout) as client:
            response = await client.post(url, json=payload, headers=headers)
            response.raise_for_status()
            data = response.json()
    except httpx.ConnectError as e:
        logger.error(f"Impossible de se connecter à {url}: {e}")
        raise HTTPException(
            status_code=503,
            detail=f"Impossible de se connecter à cursor-agent HTTP: {url}. Vérifiez que le serveur est démarré."
        )
    except httpx.TimeoutException:
        logger.error(f"Timeout lors de la connexion à {url}")
        raise HTTPException(
            status_code=504,
            detail=f"Timeout lors de l'appel à cursor-agent HTTP (>{settings.cursor_agent_timeout}s)"
        )
    except Exception as e:
        logger.error(f"Erreur lors de l'appel HTTP: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de l'appel à cursor-agent HTTP: {str(e)}"
        )
    
    http_duration = (time.time() - http_start) * 1000
    total_duration = (time.time() - start_time) * 1000
    logger.info(f"cursor-agent HTTP: {http_duration:.2f}ms (total: {total_duration:.2f}ms)")
    
    # Adapter selon le format de réponse de cursor-agent
    return data.get("response") or data.get("content") or data.get("text") or str(data)


async def _call_cursor_agent_library(messages: List[Message], model: str) -> str:
    """
    Appel via bibliothèque Python (à implémenter selon votre bibliothèque)
    
    Args:
        messages: Liste des messages
        model: Le modèle à utiliser (déjà mappé au format cursor-agent)
    """
    # Exemple d'implémentation:
    # from cursor_agent import CursorAgent
    # agent = CursorAgent(model=model)
    # return await agent.chat(messages)
    
    raise NotImplementedError(
        "Mode library non implémenté. "
        "Modifiez _call_cursor_agent_library() dans main.py pour intégrer votre bibliothèque."
    )


def count_tokens(text: str) -> int:
    """
    Compte approximatif des tokens (à améliorer avec tiktoken si nécessaire)
    """
    # Approximation: 1 token ≈ 4 caractères
    return len(text) // 4


@app.post("/v1/chat/completions", response_model=ChatCompletionResponse)
async def chat_completions(request: ChatCompletionRequest):
    """
    Endpoint principal compatible avec l'API OpenAI ChatGPT
    """
    # Validation: messages ne doit pas être vide
    if not request.messages:
        raise HTTPException(
            status_code=422,
            detail="Messages list cannot be empty"
        )
    
    try:
        import time
        request_start = time.time()
        
        # Récupérer la liste des modèles disponibles
        models_start = time.time()
        available_models = await get_available_models()
        models_duration = (time.time() - models_start) * 1000
        logger.debug(f"Récupération des modèles: {models_duration:.2f}ms")
        
        # Mapper le modèle au format cursor-agent
        map_start = time.time()
        cursor_model = map_model_name(request.model, available_models)
        map_duration = (time.time() - map_start) * 1000
        logger.debug(f"Mapping du modèle: {map_duration:.2f}ms")
        
        # Appeler cursor-agent avec le modèle mappé
        call_start = time.time()
        response_content = await call_cursor_agent(request.messages, cursor_model)
        call_duration = (time.time() - call_start) * 1000
        logger.info(f"Appel cursor-agent: {call_duration:.2f}ms")
        
        # Construire la réponse au format OpenAI
        response_message = Message(role="assistant", content=response_content)
        
        # Calculer les tokens (approximatif)
        prompt_text = "\n".join([msg.content for msg in request.messages])
        prompt_tokens = count_tokens(prompt_text)
        completion_tokens = count_tokens(response_content)
        
        return ChatCompletionResponse(
            id=f"chatcmpl-{uuid.uuid4().hex[:12]}",
            created=int(datetime.now().timestamp()),
            model=request.model,
            choices=[
                Choice(
                    index=0,
                    message=response_message,
                    finish_reason="stop"
                )
            ],
            usage=Usage(
                prompt_tokens=prompt_tokens,
                completion_tokens=completion_tokens,
                total_tokens=prompt_tokens + completion_tokens
            )
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/v1/chat/completions-stream")
async def chat_completions_stream(request: ChatCompletionRequest):
    """
    Endpoint pour le streaming (Server-Sent Events) compatible OpenAI
    """
    async def generate():
        try:
            # Récupérer la liste des modèles disponibles
            available_models = await get_available_models()
            
            # Mapper le modèle au format cursor-agent
            cursor_model = map_model_name(request.model, available_models)
            
            # Appeler cursor-agent avec le modèle mappé
            response_content = await call_cursor_agent(request.messages, cursor_model)
            
            # Simuler le streaming en envoyant des chunks
            chunk_id = f"chatcmpl-{uuid.uuid4().hex[:12]}"
            created = int(datetime.now().timestamp())
            
            # Envoyer les chunks de manière progressive
            words = response_content.split()
            for i, word in enumerate(words):
                chunk = ChatCompletionChunk(
                    id=chunk_id,
                    created=created,
                    model=request.model,
                    choices=[{
                        "index": 0,
                        "delta": {"content": word + " "},
                        "finish_reason": None if i < len(words) - 1 else "stop"
                    }]
                )
                yield f"data: {chunk.model_dump_json()}\n\n"
                await asyncio.sleep(0.05)  # Délai pour simuler le streaming
            
            # Chunk final
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


@app.get("/health")
async def health():
    """Endpoint de santé"""
    return {"status": "ok", "service": "cursor-agent-proxy"}


@app.get("/v1/models")
async def list_models():
    """
    Liste les modèles disponibles (compatible OpenAI)
    
    Retourne tous les modèles supportés par cursor-agent (détectés dynamiquement),
    ainsi que leurs alias OpenAI/Anthropic pour la compatibilité.
    """
    timestamp = int(datetime.now().timestamp())
    
    # Récupérer la liste dynamique des modèles depuis cursor-agent
    available_models = await get_available_models()
    
    # Déterminer le propriétaire selon le préfixe du modèle
    def get_owner(model_id: str) -> str:
        if model_id.startswith("gpt-"):
            return "openai"
        elif model_id.startswith("sonnet-") or model_id.startswith("opus-") or model_id.startswith("claude-"):
            return "anthropic"
        elif model_id.startswith("gemini-"):
            return "google"
        elif model_id == "grok":
            return "xai"
        elif model_id in ["auto", "composer-1"]:
            return "cursor"
        else:
            return "cursor"
    
    # Créer un set pour éviter les doublons
    seen_models = set()
    
    # Créer la liste des modèles natifs cursor-agent
    native_models = []
    for model_id in available_models:
        if model_id not in seen_models:
            native_models.append({
                "id": model_id,
                "object": "model",
                "created": timestamp,
                "owned_by": get_owner(model_id)
            })
            seen_models.add(model_id)
    
    # Ajouter les alias pour compatibilité (uniquement ceux qui ont un mapping)
    alias_models = []
    for alias, mapped in ALIAS_MAPPING.items():
        # Ignorer les alias qui sont déjà dans la liste des modèles natifs
        if alias in seen_models:
            continue
            
        # Ajouter l'alias si :
        # 1. Il a un mapping fixe (mapped n'est pas None)
        # 2. Ou s'il commence par gpt- ou opus (mapping intelligent)
        if mapped and mapped in available_models:
            alias_models.append({
                "id": alias,
                "object": "model",
                "created": timestamp,
                "owned_by": get_owner(mapped)
            })
            seen_models.add(alias)
        elif mapped is None and (alias.startswith("gpt-") or "opus" in alias):
            # Pour les alias avec mapping intelligent, ajouter s'il y a un modèle compatible disponible
            if alias.startswith("gpt-"):
                for gpt_model in ["gpt-5.2", "gpt-5.1", "gpt-5"]:
                    if gpt_model in available_models:
                        alias_models.append({
                            "id": alias,
                            "object": "model",
                            "created": timestamp,
                            "owned_by": "openai"
                        })
                        seen_models.add(alias)
                        break
            elif "opus" in alias:
                for opus_model in ["opus-4.5", "opus-4.1"]:
                    if opus_model in available_models:
                        alias_models.append({
                            "id": alias,
                            "object": "model",
                            "created": timestamp,
                            "owned_by": "anthropic"
                        })
                        seen_models.add(alias)
                        break
    
    return {
        "object": "list",
        "data": native_models + alias_models
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host=settings.host,
        port=settings.port,
        reload=settings.reload
    )
