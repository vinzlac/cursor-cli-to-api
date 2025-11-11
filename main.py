"""
FastAPI proxy pour cursor-agent compatible avec l'API ChatGPT/OpenAI
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


# Mapping des modèles OpenAI/Anthropic vers les modèles cursor-agent
# Modèles réels disponibles: composer-1, auto, sonnet-4.5, sonnet-4.5-thinking,
# gpt-5, gpt-5-codex, gpt-5-codex-high, opus-4.1, grok
MODEL_MAPPING = {
    # Modèles OpenAI → gpt-5
    "gpt-4o": "gpt-5",
    "gpt-4o-mini": "gpt-5",
    "gpt-4-turbo": "gpt-5",
    "gpt-4": "gpt-5",
    "gpt-3.5-turbo": "gpt-5",
    
    # Modèles Anthropic Claude Sonnet → sonnet-4.5
    "claude-3-5-sonnet-20241022": "sonnet-4.5",
    "claude-3-5-sonnet": "sonnet-4.5",
    "claude-sonnet-4.5": "sonnet-4.5",
    "claude-sonnet-4": "sonnet-4.5",
    "sonnet-4": "sonnet-4.5",  # Ancien nom
    
    # Modèles Anthropic Claude Sonnet avec thinking → sonnet-4.5-thinking
    "claude-3-5-sonnet-thinking": "sonnet-4.5-thinking",
    "sonnet-4-thinking": "sonnet-4.5-thinking",  # Ancien nom
    
    # Modèles Anthropic Opus → opus-4.1
    "claude-opus-4": "opus-4.1",
    "claude-4-opus": "opus-4.1",
    
    # Modèles génériques
    "cursor-agent": "auto",
    "default": "auto",
    "auto": "auto",
}


def map_model_name(model: str) -> str:
    """
    Mappe un nom de modèle OpenAI vers un nom de modèle cursor-agent.
    Si le modèle n'est pas trouvé dans le mapping, retourne "default".
    
    Args:
        model: Nom du modèle (format OpenAI ou cursor-agent)
    
    Returns:
        Nom du modèle au format cursor-agent
    """
    mapped = MODEL_MAPPING.get(model.lower())
    if mapped:
        logger.info(f"Modèle '{model}' mappé vers '{mapped}'")
        return mapped
    
    # Si pas de mapping trouvé, vérifier si c'est déjà un modèle cursor-agent valide
    cursor_models = [
        "composer-1", "auto", "sonnet-4.5", "sonnet-4.5-thinking",
        "gpt-5", "gpt-5-codex", "gpt-5-codex-high", "opus-4.1", "grok"
    ]
    if model in cursor_models:
        logger.info(f"Modèle '{model}' utilisé tel quel")
        return model
    
    # Sinon, utiliser le modèle par défaut (auto)
    logger.warning(f"Modèle '{model}' non reconnu, utilisation de 'auto'")
    return "auto"


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
    mode = settings.cursor_agent_mode.lower()
    logger.info(f"Appel à cursor-agent en mode: {mode}, modèle: {model}")
    
    # Convertir les messages en format attendu
    prompt = "\n".join([f"{msg.role}: {msg.content}" for msg in messages])
    
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
    cli_path = settings.cursor_agent_cli_path or "cursor-agent"
    
    # Préparer l'environnement avec le token si disponible
    env = os.environ.copy()
    if settings.cursor_api_key:
        # cursor-agent attend CURSOR_API_KEY
        env["CURSOR_API_KEY"] = settings.cursor_api_key
    
    # Construire la commande avec le modèle
    cmd = [cli_path, "--model", model, prompt]
    logger.info(f"Commande cursor-agent: {' '.join(cmd[:3])}... (prompt tronqué)")
    
    # Exécuter dans un thread pour ne pas bloquer l'event loop
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
    
    if result.returncode != 0:
        raise RuntimeError(f"cursor-agent a retourné le code {result.returncode}: {result.stderr}")
    
    return result.stdout.strip()


async def _call_cursor_agent_http(messages: List[Message], model: str) -> str:
    """
    Appel via API HTTP
    
    Args:
        messages: Liste des messages
        model: Le modèle à utiliser (déjà mappé au format cursor-agent)
    """
    if not settings.cursor_agent_http_url:
        raise ValueError("CURSOR_AGENT_HTTP_URL doit être défini pour le mode HTTP")
    
    url = settings.cursor_agent_http_url
    payload = {
        "model": model,
        "messages": [{"role": msg.role, "content": msg.content} for msg in messages]
    }
    
    # Préparer les headers avec authentification si token disponible
    headers = {}
    if settings.cursor_api_key:
        headers["Authorization"] = f"Bearer {settings.cursor_api_key}"
    
    logger.info(f"Requête HTTP à cursor-agent: {url} avec modèle {model}")
    
    async with httpx.AsyncClient(timeout=settings.cursor_agent_timeout) as client:
        response = await client.post(url, json=payload, headers=headers)
        response.raise_for_status()
        data = response.json()
        
        # Adapter selon le format de réponse de cursor-agent
        return data.get("response") or data.get("content") or str(data)


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
        # Mapper le modèle au format cursor-agent
        cursor_model = map_model_name(request.model)
        
        # Appeler cursor-agent avec le modèle mappé
        response_content = await call_cursor_agent(request.messages, cursor_model)
        
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
            # Mapper le modèle au format cursor-agent
            cursor_model = map_model_name(request.model)
            
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
    
    Retourne tous les modèles supportés par cursor-agent, ainsi que leurs alias OpenAI/Anthropic.
    """
    timestamp = int(datetime.now().timestamp())
    
    # Modèles natifs cursor-agent (basé sur: cursor-agent --help)
    native_models = [
        {"id": "auto", "object": "model", "created": timestamp, "owned_by": "cursor"},
        {"id": "composer-1", "object": "model", "created": timestamp, "owned_by": "cursor"},
        {"id": "gpt-5", "object": "model", "created": timestamp, "owned_by": "openai"},
        {"id": "gpt-5-codex", "object": "model", "created": timestamp, "owned_by": "openai"},
        {"id": "gpt-5-codex-high", "object": "model", "created": timestamp, "owned_by": "openai"},
        {"id": "sonnet-4.5", "object": "model", "created": timestamp, "owned_by": "anthropic"},
        {"id": "sonnet-4.5-thinking", "object": "model", "created": timestamp, "owned_by": "anthropic"},
        {"id": "opus-4.1", "object": "model", "created": timestamp, "owned_by": "anthropic"},
        {"id": "grok", "object": "model", "created": timestamp, "owned_by": "xai"},
    ]
    
    # Alias populaires (pour compatibilité avec clients OpenAI/Anthropic)
    alias_models = [
        # Alias OpenAI
        {"id": "gpt-4o", "object": "model", "created": timestamp, "owned_by": "openai"},
        {"id": "gpt-4o-mini", "object": "model", "created": timestamp, "owned_by": "openai"},
        {"id": "gpt-4-turbo", "object": "model", "created": timestamp, "owned_by": "openai"},
        {"id": "gpt-4", "object": "model", "created": timestamp, "owned_by": "openai"},
        {"id": "gpt-3.5-turbo", "object": "model", "created": timestamp, "owned_by": "openai"},
        # Alias Anthropic
        {"id": "claude-3-5-sonnet-20241022", "object": "model", "created": timestamp, "owned_by": "anthropic"},
        {"id": "claude-3-5-sonnet", "object": "model", "created": timestamp, "owned_by": "anthropic"},
        {"id": "claude-opus-4", "object": "model", "created": timestamp, "owned_by": "anthropic"},
    ]
    
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
