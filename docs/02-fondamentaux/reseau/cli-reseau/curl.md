# 🛠️ curl — Requêtes & Transferts HTTP/HTTPS CLI

## 1. Description rapide

**curl** (*Client URL*) effectue des transferts de données via de nombreux protocoles (HTTP, HTTPS, FTP, SFTP, SCP...). En administration et pentest, c'est l'outil de référence pour inspecter les réponses HTTP, tester des APIs REST, exfiltrer/récupérer des fichiers, et interagir avec des services web sans navigateur.

---

## 2. Syntaxe de base

```bash
curl [options] URL
```

---

## 3. Options et fanions principaux

| Flag | Rôle |
| --- | --- |
| `-I` | Récupère uniquement les headers HTTP (méthode HEAD) |
| `-v` | Mode verbeux : affiche la requête + réponse complètes |
| `-s` | Mode silencieux : supprime la barre de progression |
| `-o FILE` | Sauvegarde la réponse dans un fichier nommé |
| `-O` | Sauvegarde avec le nom de fichier de l'URL |
| `-L` | Suit les redirections HTTP (301, 302...) |
| `-X METHOD` | Spécifie la méthode HTTP (GET, POST, PUT, DELETE...) |
| `-d DATA` | Envoie un corps de requête POST |
| `-H "Header: val"` | Ajoute un en-tête HTTP personnalisé |
| `-b "cookie=val"` | Envoie un cookie |
| `-c FILE` | Sauvegarde les cookies reçus dans un fichier |
| `-u user:pass` | Authentification HTTP Basic |
| `-k` | Ignore les erreurs de certificat SSL/TLS |
| `--proxy URL` | Utilise un proxy HTTP (ex: Burp Suite) |
| `--max-time N` | Timeout global de la requête en secondes |

---

## 4. Exemples pratiques

```bash
# Inspecter les headers HTTP de réponse (détecte Server, X-Powered-By, HSTS...)
curl -sI https://example.com
```

```bash
# Requête POST avec données JSON et header Content-Type
curl -s -X POST https://api.example.com/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"secret"}'
```

```bash
# Requête authentifiée avec token Bearer (API REST)
curl -s -H "Authorization: Bearer eyJhbGc..." https://api.example.com/users
```

```bash
# Télécharger un fichier en gardant le nom d'origine, en suivant les redirections
curl -sLO https://example.com/tool.tar.gz
```

```bash
# Router toutes les requêtes via Burp Suite (interception et analyse)
curl -sk -x http://127.0.0.1:8080 https://target.com/admin
```

```bash
# Test de formulaire de connexion web et gestion des cookies de session
curl -s -c cookies.txt -b cookies.txt \
  -d "user=admin&pass=admin" \
  -L http://target.com/login.php
```

---

## 5. Astuces & Pièges à éviter

!!! tip "-v pour le débogage, -s pour les scripts"
    En débogage, `curl -v URL` affiche les headers envoyés et reçus, le handshake TLS, et les redirections. En script, `curl -s URL` supprime tout le bruit et ne retourne que le corps de la réponse.

!!! tip "Tester une API CRUD complète"
    ```bash
    curl -X GET    https://api/resource/1
    curl -X POST   https://api/resource -d '{"name":"test"}' -H "Content-Type: application/json"
    curl -X PUT    https://api/resource/1 -d '{"name":"modif"}'
    curl -X DELETE https://api/resource/1
    ```

!!! warning "-k désactive toute vérification TLS"
    `--insecure` / `-k` est utile pour les certs auto-signés en lab, mais en production il rend curl vulnérable aux attaques MitM. Ne jamais l'utiliser dans des scripts d'automatisation qui manipulent des données sensibles en environnement réel.

!!! warning "Attention aux guillemets et aux espaces dans -d"
    `curl -d "param=valeur avec espaces"` encode correctement si guillemets doubles. Pour des données URL-encodées complexes, préférer `--data-urlencode "param=valeur avec espaces"` qui gère automatiquement l'encodage.
