# Guide d'intégration avec cursor-agent

Ce guide explique comment intégrer ce proxy avec cursor-agent selon différents modes d'utilisation.

## Modes d'intégration

### Mode CLI (recommandé pour commencer)

Si cursor-agent est disponible en ligne de commande:

1. **Vérifier que cursor-agent est accessible:**
   ```bash
   which cursor-agent
   # ou
   cursor-agent --version
   ```

2. **Configurer dans `.env`:**
   ```env
   CURSOR_AGENT_MODE=cli
   CURSOR_AGENT_CLI_PATH=cursor-agent  # ou le chemin complet si nécessaire
   CURSOR_AGENT_TIMEOUT=60
   ```

3. **Adapter la fonction `_call_cursor_agent_cli()` si nécessaire:**
   
   Si cursor-agent attend un format spécifique, modifiez `main.py`:
   ```python
   async def _call_cursor_agent_cli(prompt: str) -> str:
       cli_path = settings.cursor_agent_cli_path or "cursor-agent"
       
       # Adapter selon le format attendu par cursor-agent
       # Exemple: cursor-agent --input-file ou cursor-agent --stdin
       loop = asyncio.get_event_loop()
       result = await loop.run_in_executor(
           None,
           lambda: subprocess.run(
               [cli_path, "--prompt", prompt],  # Adapter les arguments
               capture_output=True,
               text=True,
               timeout=settings.cursor_agent_timeout
           )
       )
       return result.stdout.strip()
   ```

### Mode HTTP

Si cursor-agent expose une API HTTP:

1. **Configurer dans `.env`:**
   ```env
   CURSOR_AGENT_MODE=http
   CURSOR_AGENT_HTTP_URL=http://localhost:3000/api/chat
   CURSOR_AGENT_TIMEOUT=60
   ```

2. **Adapter la fonction `_call_cursor_agent_http()` si nécessaire:**
   
   Modifiez `main.py` pour correspondre au format de l'API cursor-agent:
   ```python
   async def _call_cursor_agent_http(messages: List[Message]) -> str:
       url = settings.cursor_agent_http_url
       
       # Adapter le payload selon l'API cursor-agent
       payload = {
           "prompt": "\n".join([m.content for m in messages]),
           # ou
           "conversation": [{"role": m.role, "text": m.content} for m in messages]
       }
       
       async with httpx.AsyncClient(timeout=settings.cursor_agent_timeout) as client:
           response = await client.post(url, json=payload)
           response.raise_for_status()
           data = response.json()
           
           # Adapter selon le format de réponse
           return data.get("result") or data.get("output") or str(data)
   ```

### Mode Library

Si cursor-agent est disponible comme bibliothèque Python:

1. **Installer la bibliothèque cursor-agent:**
   ```bash
   uv pip install cursor-agent
   # ou selon le nom du package
   ```

2. **Configurer dans `.env`:**
   ```env
   CURSOR_AGENT_MODE=library
   ```

3. **Implémenter `_call_cursor_agent_library()` dans `main.py`:**
   ```python
   async def _call_cursor_agent_library(messages: List[Message]) -> str:
       from cursor_agent import CursorAgent  # Adapter l'import
       
       agent = CursorAgent()
       
       # Adapter selon l'API de la bibliothèque
       result = await agent.process_messages([
           {"role": msg.role, "content": msg.content}
           for msg in messages
       ])
       
       return result
   ```

## Test de l'intégration

1. **Démarrer le serveur:**
   ```bash
   just dev
   ```

2. **Tester avec curl:**
   ```bash
   curl -X POST http://localhost:8000/v1/chat/completions \
     -H "Content-Type: application/json" \
     -d '{
       "model": "cursor-agent",
       "messages": [
         {"role": "user", "content": "Bonjour"}
       ]
     }'
   ```

3. **Vérifier les logs:**
   Les logs devraient indiquer le mode utilisé et les erreurs éventuelles.

## 🔧 Dépannage

### Erreur: "cursor-agent n'est pas trouvé"
- Vérifiez que cursor-agent est dans votre PATH
- Ou définissez `CURSOR_AGENT_CLI_PATH` avec le chemin complet

### Erreur: "Timeout"
- Augmentez `CURSOR_AGENT_TIMEOUT` dans `.env`
- Vérifiez que cursor-agent répond correctement

### Erreur: "Format de réponse invalide"
- Adaptez les fonctions `_call_cursor_agent_*()` pour correspondre au format réel
- Vérifiez les logs pour voir la réponse brute

## Exemples de configuration

### Exemple 1: CLI avec chemin personnalisé
```env
CURSOR_AGENT_MODE=cli
CURSOR_AGENT_CLI_PATH=/usr/local/bin/cursor-agent
CURSOR_AGENT_TIMEOUT=120
```

### Exemple 2: API HTTP avec authentification
```env
CURSOR_AGENT_MODE=http
CURSOR_AGENT_HTTP_URL=https://api.cursor-agent.com/v1/chat
CURSOR_AGENT_TIMEOUT=60
```

Puis adapter `_call_cursor_agent_http()` pour inclure les headers d'authentification.
