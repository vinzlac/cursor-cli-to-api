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
    logger.info("Authentification activ?e via API key")
# Rate limiting optionnel (d?commenter si n?cessaire)
# app.add_middleware(RateLimitMiddleware, requests_per_minute=60)


# Mod?les Pydantic pour l'API OpenAI-compatible
class Message(BaseModel):
    role: str  # "system", "user", "assistant"
    content: str


class ChatCompletionRequest(BaseModel):
    model: str = "cursor-agent"
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


async def call_cursor_agent(messages: List[Message]) -> str:
    """
    Appelle cursor-agent avec les messages fournis.
    
    Supporte trois modes:
    - cli: Appel via ligne de commande
    - http: Appel via API HTTP
    - library: Appel via biblioth?que Python (? impl?menter)
    """
    mode = settings.cursor_agent_mode.lower()
    logger.info(f"Appel ? cursor-agent en mode: {mode}")
    
    # Convertir les messages en format attendu
    prompt = "\n".join([f"{msg.role}: {msg.content}" for msg in messages])
    
    try:
        if mode == "cli":
            return await _call_cursor_agent_cli(prompt)
        elif mode == "http":
            return await _call_cursor_agent_http(messages)
        elif mode == "library":
            return await _call_cursor_agent_library(messages)
        else:
            # Mode simulation par d?faut pour les tests
            logger.warning(f"Mode '{mode}' non reconnu, utilisation du mode simulation")
            await asyncio.sleep(0.1)
            return f"R?ponse simul?e de cursor-agent pour: {prompt[:50]}..."
            
    except subprocess.TimeoutExpired:
        logger.error("Timeout lors de l'appel ? cursor-agent")
        raise HTTPException(
            status_code=504,
            detail=f"Timeout lors de l'appel ? cursor-agent (>{settings.cursor_agent_timeout}s)"
        )
    except Exception as e:
        logger.error(f"Erreur lors de l'appel ? cursor-agent: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de l'appel ? cursor-agent: {str(e)}"
        )


async def _call_cursor_agent_cli(prompt: str) -> str:
    """Appel via CLI"""
    cli_path = settings.cursor_agent_cli_path or "cursor-agent"
    
    # Ex?cuter dans un thread pour ne pas bloquer l'event loop
    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(
        None,
        lambda: subprocess.run(
            [cli_path, prompt],
            capture_output=True,
            text=True,
            timeout=settings.cursor_agent_timeout
        )
    )
    
    if result.returncode != 0:
        raise RuntimeError(f"cursor-agent a retourn? le code {result.returncode}: {result.stderr}")
    
    return result.stdout.strip()


async def _call_cursor_agent_http(messages: List[Message]) -> str:
    """Appel via API HTTP"""
    if not settings.cursor_agent_http_url:
        raise ValueError("CURSOR_AGENT_HTTP_URL doit ?tre d?fini pour le mode HTTP")
    
    url = settings.cursor_agent_http_url
    payload = {
        "messages": [{"role": msg.role, "content": msg.content} for msg in messages]
    }
    
    async with httpx.AsyncClient(timeout=settings.cursor_agent_timeout) as client:
        response = await client.post(url, json=payload)
        response.raise_for_status()
        data = response.json()
        
        # Adapter selon le format de réponse de cursor-agent
        return data.get("response") or data.get("content") or str(data)


async def _call_cursor_agent_library(messages: List[Message]) -> str:
    """Appel via bibliothèque Python (à implémenter selon votre bibliothèque)"""
    # Exemple d'implémentation:
    # from cursor_agent import CursorAgent
    # agent = CursorAgent()
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
        # Appeler cursor-agent
        response_content = await call_cursor_agent(request.messages)
        
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
            # Appeler cursor-agent
            response_content = await call_cursor_agent(request.messages)
            
            # Simuler le streaming en envoyant des chunks
            chunk_id = f"chatcmpl-{uuid.uuid4().hex[:12]}"
            created = int(datetime.now().timestamp())
            
            # Envoyer les chunks de mani?re progressive
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
                await asyncio.sleep(0.05)  # D?lai pour simuler le streaming
            
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
    """Endpoint de sant?"""
    return {"status": "ok", "service": "cursor-agent-proxy"}


@app.get("/v1/models")
async def list_models():
    """
    Liste les mod?les disponibles (compatible OpenAI)
    """
    return {
        "object": "list",
        "data": [
            {
                "id": "cursor-agent",
                "object": "model",
                "created": int(datetime.now().timestamp()),
                "owned_by": "cursor"
            }
        ]
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host=settings.host,
        port=settings.port,
        reload=settings.reload
    )
