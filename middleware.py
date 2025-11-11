"""
Middleware pour l'API FastAPI
"""
from fastapi import Request, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response, JSONResponse
import time
import logging
from typing import Callable

from config import settings

logger = logging.getLogger(__name__)
security = HTTPBearer(auto_error=False)


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Middleware basique pour le rate limiting (à améliorer avec Redis)"""
    
    def __init__(self, app, requests_per_minute: int = 60):
        super().__init__(app)
        self.requests_per_minute = requests_per_minute
        self.request_counts = {}  # En production, utiliser Redis
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        client_ip = request.client.host
        
        # Réinitialiser le compteur toutes les minutes
        current_time = time.time()
        if client_ip in self.request_counts:
            if current_time - self.request_counts[client_ip]["reset_time"] > 60:
                self.request_counts[client_ip] = {
                    "count": 0,
                    "reset_time": current_time
                }
        else:
            self.request_counts[client_ip] = {
                "count": 0,
                "reset_time": current_time
            }
        
        # Vérifier le rate limit
        if self.request_counts[client_ip]["count"] >= self.requests_per_minute:
            logger.warning(f"Rate limit dépassé pour {client_ip}")
            return Response(
                content='{"error": "Rate limit exceeded"}',
                status_code=429,
                media_type="application/json"
            )
        
        self.request_counts[client_ip]["count"] += 1
        
        response = await call_next(request)
        return response


class AuthMiddleware(BaseHTTPMiddleware):
    """Middleware pour l'authentification par API key"""
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        # Ignorer les endpoints de santé et de documentation
        if request.url.path in ["/health", "/docs", "/redoc", "/openapi.json"]:
            return await call_next(request)
        
        # Si aucune API key n'est configurée, passer
        if not settings.api_key:
            return await call_next(request)
        
        # Vérifier l'API key
        auth_header = request.headers.get("Authorization")
        if not auth_header:
            return JSONResponse(
                status_code=401,
                content={"detail": "Authorization header manquant"}
            )
        
        if not auth_header.startswith("Bearer "):
            return JSONResponse(
                status_code=401,
                content={"detail": "Format d'autorisation invalide. Utilisez: Bearer <token>"}
            )
        
        token = auth_header.replace("Bearer ", "")
        if token != settings.api_key:
            logger.warning(f"Tentative d'accès avec un token invalide depuis {request.client.host}")
            return JSONResponse(
                status_code=403,
                content={"detail": "Token d'autorisation invalide"}
            )
        
        return await call_next(request)


class LoggingMiddleware(BaseHTTPMiddleware):
    """Middleware pour le logging des requêtes"""
    
    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        start_time = time.time()
        
        # Log de la requête
        logger.info(
            f"{request.method} {request.url.path} - "
            f"Client: {request.client.host}"
        )
        
        response = await call_next(request)
        
        # Calculer le temps de traitement
        process_time = time.time() - start_time
        
        # Log de la réponse
        logger.info(
            f"{request.method} {request.url.path} - "
            f"Status: {response.status_code} - "
            f"Time: {process_time:.3f}s"
        )
        
        # Ajouter le header X-Process-Time
        response.headers["X-Process-Time"] = str(process_time)
        
        return response
