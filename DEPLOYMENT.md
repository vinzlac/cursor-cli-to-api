# Guide de déploiement

Ce guide explique comment déployer cursor-openai-proxy en production.

## 🐳 Déploiement avec Docker

### Prérequis

- Docker et Docker Compose installés
- Fichier `.env` configuré

### Déploiement rapide

```bash
# Construire et démarrer
docker-compose up -d

# Vérifier les logs
docker-compose logs -f

# Arrêter
docker-compose down
```

### Déploiement avec le script

```bash
# Déploiement automatique
./scripts/deploy.sh

# Ou sans build Docker
DOCKER_BUILD=false ./scripts/deploy.sh
```

## 💻 Déploiement manuel

### Sur un serveur Linux

1. **Installer les dépendances système:**
   ```bash
   # Installer uv
   curl -LsSf https://astral.sh/uv/install.sh | sh
   
   # Installer just (optionnel mais recommandé)
   curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash
   ```

2. **Cloner et configurer:**
   ```bash
   git clone <repository>
   cd cursor-openai-proxy
   cp .env.example .env
   # éditer .env
   ```

3. **Installer les dépendances:**
   ```bash
   just install
   ```

4. **Démarrer avec systemd (recommandé):**

   Créer `/etc/systemd/system/cursor-api.service`:
   ```ini
   [Unit]
   Description=Cursor Agent API Proxy
   After=network.target

   [Service]
   Type=simple
   User=www-data
   WorkingDirectory=/path/to/cursor-openai-proxy
   Environment="PATH=/path/to/cursor-openai-proxy/.venv/bin"
   ExecStart=/path/to/cursor-openai-proxy/.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
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

## 🌐 Déploiement avec Nginx (reverse proxy)

### Configuration Nginx

Créer `/etc/nginx/sites-available/cursor-api`:

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
# Sécurité
API_KEY=your-secret-api-key-here
LOG_LEVEL=INFO

# Performance
CURSOR_AGENT_TIMEOUT=60
RELOAD=false

# Cursor Agent
CURSOR_AGENT_MODE=http
CURSOR_AGENT_HTTP_URL=https://cursor-agent.example.com/api
```

## 📊 Monitoring

### Health checks

L'endpoint `/health` peut être utilisé pour les health checks:

```bash
# Vérification simple
curl http://localhost:8000/health

# Avec le script de test
./scripts/test_integration.sh
```

### Logs

Les logs sont envoyés vers stdout/stderr. Pour les capturer:

```bash
# Avec Docker
docker-compose logs -f

# Avec systemd
journalctl -u cursor-api -f

# Avec PM2
pm2 logs cursor-api
```

## 🔒 Sécurité en production

1. **Activer l'authentification:**
   ```env
   API_KEY=your-strong-random-key-here
   ```

2. **Utiliser HTTPS:**
   - Configurer Nginx avec SSL/TLS
   - Rediriger HTTP vers HTTPS

3. **Rate limiting:**
   - Décommenter `RateLimitMiddleware` dans `main.py`
   - Ou utiliser un reverse proxy avec rate limiting (Nginx, Cloudflare)

4. **Firewall:**
   ```bash
   # Autoriser uniquement les ports nécessaires
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw enable
   ```

5. **Mettre à jour régulièrement:**
   ```bash
   # Mettre à jour les dépendances
   uv sync --upgrade
   
   # Rebuild Docker
   docker-compose build --no-cache
   ```

## 📈 Scaling

### Horizontal scaling

Pour gérer plusieurs instances:

1. Utiliser un load balancer (Nginx, HAProxy)
2. Configurer plusieurs instances avec Docker Compose:
   ```yaml
   services:
     api:
       # ...
       deploy:
         replicas: 3
   ```

3. Utiliser Kubernetes pour un scaling avancé

### Vertical scaling

Augmenter les ressources du serveur selon la charge.

## Backup et recovery

### Configuration

Sauvegarder régulièrement:
- Le fichier `.env`
- Les logs importants
- La configuration Nginx/Docker

### Recovery

En cas de problème:
```bash
# Voir les logs
docker-compose logs

# Redémarrer
docker-compose restart

# Ou rebuild complet
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

## 🔧 Troubleshooting

### Le service ne démarre pas

1. Vérifier les logs: `docker-compose logs` ou `journalctl -u cursor-api`
2. Vérifier la configuration `.env`
3. Vérifier que cursor-agent est accessible

### Erreurs 500

1. Vérifier les logs de l'application
2. Vérifier la connectivité avec cursor-agent
3. Vérifier les timeouts

### Performance lente

1. Augmenter `CURSOR_AGENT_TIMEOUT` si nécessaire
2. Vérifier les ressources du serveur
3. Considérer le caching si approprié
