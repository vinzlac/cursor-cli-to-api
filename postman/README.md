# Collection Postman pour Cursor API Proxy

Cette collection Postman permet de tester facilement tous les endpoints de l'API cursor-openai-proxy.

## 📥 Installation

### Méthode 1 : Import direct dans Postman

1. Ouvrez Postman
2. Cliquez sur **Import** (en haut à gauche)
3. Sélectionnez le fichier `Cursor-API-Proxy.postman_collection.json`
4. La collection apparaîtra dans votre workspace

### Méthode 2 : Import depuis l'URL (si hébergé)

1. Dans Postman, cliquez sur **Import**
2. Cliquez sur l'onglet **Link**
3. Collez l'URL de la collection
4. Cliquez sur **Continue** puis **Import**

## ⚙️ Configuration

### Variables d'environnement

La collection utilise deux variables :

1. **`base_url`** : URL de base de votre API
   - Par défaut : `http://localhost:8001`
   - Pour Docker : `http://localhost:8001`
   - Pour production : `https://votre-domaine.com`

2. **`api_key`** : Clé API pour l'authentification (optionnel)
   - Si l'authentification est activée, définissez cette variable
   - Si l'authentification est désactivée, laissez-la vide

### Comment configurer les variables

#### Option A : Variables de collection (recommandé)

1. Cliquez sur la collection **Cursor API Proxy**
2. Allez dans l'onglet **Variables**
3. Modifiez les valeurs :
   - `base_url` : `http://localhost:8001`
   - `api_key` : Votre clé API (depuis `.env`)

#### Option B : Environnement Postman

1. Créez un nouvel environnement dans Postman
2. Ajoutez les variables :
   - `base_url` = `http://localhost:8001`
   - `api_key` = Votre clé API
3. Sélectionnez cet environnement dans le menu déroulant en haut à droite

## 🧪 Utilisation

### Endpoints disponibles

#### 1. Health Check
- **GET** `/health`
- Vérifie que le serveur est accessible
- Pas d'authentification requise

#### 2. List Models
- **GET** `/v1/models`
- Liste tous les modèles disponibles
- Compatible avec l'API OpenAI

#### 3. Chat Completions
Plusieurs exemples de requêtes :

- **Simple Chat** : Chat basique avec le modèle `auto`
- **Chat with System Message** : Avec message système et paramètres
- **Chat with GPT-4o alias** : Utilise l'alias GPT-4o (mappé vers gpt-5)
- **Chat with Claude Sonnet** : Utilise Claude via l'alias Anthropic
- **Multi-turn Conversation** : Conversation avec historique
- **Chat with All Parameters** : Tous les paramètres disponibles

#### 4. Streaming
- **Chat Completions Stream** : Chat avec streaming (Server-Sent Events)

#### 5. Authentication Tests
- Tests pour vérifier que l'authentification fonctionne correctement

## 🔐 Authentification

### Si l'authentification est activée

1. Configurez la variable `api_key` avec votre clé API
2. Les headers d'authentification sont automatiquement ajoutés aux requêtes
3. Vous pouvez activer/désactiver l'authentification par requête en modifiant le header

### Si l'authentification est désactivée

1. Laissez `api_key` vide
2. Les headers d'authentification sont désactivés par défaut
3. Vous pouvez les activer manuellement si nécessaire

## 📝 Exemples de requêtes

### Chat simple

```json
{
  "model": "auto",
  "messages": [
    {
      "role": "user",
      "content": "Bonjour, comment ça va ?"
    }
  ]
}
```

### Chat avec paramètres

```json
{
  "model": "gpt-5",
  "messages": [
    {
      "role": "system",
      "content": "Tu es un assistant Python expert."
    },
    {
      "role": "user",
      "content": "Explique-moi FastAPI"
    }
  ],
  "temperature": 0.7,
  "max_tokens": 500
}
```

## 🚀 Tests rapides

1. **Test Health Check** : Vérifiez que le serveur répond
2. **Test List Models** : Vérifiez que les modèles sont disponibles
3. **Test Simple Chat** : Testez un chat basique
4. **Test Authentication** : Vérifiez que l'authentification fonctionne (si activée)

## 💡 Astuces

- Utilisez **Ctrl+Enter** pour envoyer une requête
- Utilisez **Ctrl+B** pour formater le JSON
- Utilisez les **Tests** dans Postman pour automatiser les vérifications
- Utilisez les **Pre-request Scripts** pour générer des données dynamiques

## 🔧 Dépannage

### Erreur 401/403
- Vérifiez que `api_key` est correctement configurée
- Vérifiez que l'authentification est activée sur le serveur

### Erreur de connexion
- Vérifiez que `base_url` est correct
- Vérifiez que le serveur est démarré
- Vérifiez les logs Docker : `docker logs <container_id>`

### Erreur 500
- Vérifiez que `CURSOR_API_KEY` est configurée dans `.env`
- Vérifiez que cursor-agent est accessible
- Vérifiez les logs du serveur

## 📚 Ressources

- [Documentation API](http://localhost:8001/docs)
- [README principal](../README.md)
- [Guide de configuration](../doc/CONFIGURATION.md)

