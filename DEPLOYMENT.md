# Guide de d?ploiement

Ce guide explique comment d?ployer cursor-cli-to-api en production.

## D?ploiement avec Docker

### Pr?requis

- Docker et Docker Compose install?s
- Fichier `.env` configur?

### D?ploiement rapide

```bash
# Construire et d?marrer
docker-compose up -d

# V?rifier les logs
docker-compose logs -f

# Arr?ter
docker-compose down
```

### D?ploiement avec le script

```bash
# D?ploiement automatique
./scripts/deploy.sh

# Ou sans build Docker
DOCKER_BUILD=false ./scripts/deploy.sh
```

## D?ploiement manuel

### Sur un serveur Linux

1. **Installer les d?pendances syst?me:**
   ```bash
   # Installer uv
   curl -LsSf https://astral.sh/uv/install.sh | sh
   
   # Installer just (optionnel mais recommand?)
   curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash
   ```

2. **Cloner et configurer:**
   ```bash
   git clone <repository>
   cd cursor-cli-to-api
   cp .env.example .env
   # ?diter .env
   ```

3. **Installer les d?pendances:**
   ```bash
   just install
   ```

4. **D?marrer avec systemd (recommand?):**

   Cr?er `/etc/systemd/system/cursor-api.service`:
   ```ini
   [Unit]
   Description=Cursor Agent API Proxy
   After=network.target

   [Service]
   Type=simple
   User=www-data
   WorkingDirectory=/path/to/cursor-cli-to-api
   Environment="PATH=/path/to/cursor-cli-to-api/.venv/bin"
   ExecStart=/path/to/cursor-cli-to-api/.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
   Restart=always

   [Install]
   WantedBy=multi-user.target
   ```

   Activer le service:
   ```bash
   sudo systemctl enable cursor-api
   sudo systemctl start cursor-api
   sudo systemctl status cursor-api
   ```

5. **Ou utiliser un gestionnaire de processus:**

   Avec PM2:
   ```bash
   npm install -g pm2
   pm2 start "uv run uvicorn main:app --host 0.0.0.0 --port 8000" --name cursor-api
   pm2 save
   pm2 startup
   ```

## D?ploiement avec Nginx (reverse proxy)

### Configuration Nginx

Cr?er `/etc/nginx/sites-available/cursor-api`:

```nginx
server {
    listen 80;
    server_name api.votredomaine.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Pour le streaming
        proxy_buffering off;
        proxy_cache off;
    }
}
```

Activer:
```bash
sudo ln -s /etc/nginx/sites-available/cursor-api /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### HTTPS avec Let's Encrypt

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d api.votredomaine.com
```

## Variables d'environnement importantes

### Production

```env
# S?curit?
API_KEY=your-secret-api-key-here
LOG_LEVEL=INFO

# Performance
CURSOR_AGENT_TIMEOUT=60
RELOAD=false

# Cursor Agent
CURSOR_AGENT_MODE=http
CURSOR_AGENT_HTTP_URL=https://cursor-agent.example.com/api
```

## Monitoring

### Health checks

L'endpoint `/health` peut ?tre utilis? pour les health checks:

```bash
# V?rification simple
curl http://localhost:8000/health

# Avec le script de test
./scripts/test_integration.sh
```

### Logs

Les logs sont envoy?s vers stdout/stderr. Pour les capturer:

```bash
# Avec Docker
docker-compose logs -f

# Avec systemd
journalctl -u cursor-api -f

# Avec PM2
pm2 logs cursor-api
```

## S?curit? en production

1. **Activer l'authentification:**
   ```env
   API_KEY=your-strong-random-key-here
   ```

2. **Utiliser HTTPS:**
   - Configurer Nginx avec SSL/TLS
   - Rediriger HTTP vers HTTPS

3. **Rate limiting:**
   - D?commenter `RateLimitMiddleware` dans `main.py`
   - Ou utiliser un reverse proxy avec rate limiting (Nginx, Cloudflare)

4. **Firewall:**
   ```bash
   # Autoriser uniquement les ports n?cessaires
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw enable
   ```

5. **Mettre ? jour r?guli?rement:**
   ```bash
   # Mettre ? jour les d?pendances
   uv sync --upgrade
   
   # Rebuild Docker
   docker-compose build --no-cache
   ```

## Scaling

### Horizontal scaling

Pour g?rer plusieurs instances:

1. Utiliser un load balancer (Nginx, HAProxy)
2. Configurer plusieurs instances avec Docker Compose:
   ```yaml
   services:
     api:
       # ...
       deploy:
         replicas: 3
   ```

3. Utiliser Kubernetes pour un scaling avanc?

### Vertical scaling

Augmenter les ressources du serveur selon la charge.

## Backup et recovery

### Configuration

Sauvegarder r?guli?rement:
- Le fichier `.env`
- Les logs importants
- La configuration Nginx/Docker

### Recovery

En cas de probl?me:
```bash
# Voir les logs
docker-compose logs

# Red?marrer
docker-compose restart

# Ou rebuild complet
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

## Troubleshooting

### Le service ne d?marre pas

1. V?rifier les logs: `docker-compose logs` ou `journalctl -u cursor-api`
2. V?rifier la configuration `.env`
3. V?rifier que cursor-agent est accessible

### Erreurs 500

1. V?rifier les logs de l'application
2. V?rifier la connectivit? avec cursor-agent
3. V?rifier les timeouts

### Performance lente

1. Augmenter `CURSOR_AGENT_TIMEOUT` si n?cessaire
2. V?rifier les ressources du serveur
3. Consid?rer le caching si appropri?
