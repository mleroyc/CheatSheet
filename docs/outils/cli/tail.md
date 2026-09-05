# 🛠️ Commande : tail

## 1. Description rapide (Rôle et cas d'usage)

`tail` affiche les dernières lignes (10 par défaut) d'un fichier ou d'un flux. C'est l'outil de référence pour le suivi de logs en temps réel grâce à l'option `-f`, omniprésent en administration système et en analyse d'incidents de sécurité.

## 2. Syntaxe de base

```bash
tail [OPTIONS] fichier
commande | tail
```

## 3. Options et fanions principaux

| Option | Effet |
|---|---|
| `-n N` | Affiche les N dernières lignes |
| `-n +N` | Affiche à partir de la ligne N jusqu'à la fin |
| `-f` | Suit le fichier en temps réel (suit le descripteur de fichier) |
| `-F` | Suit en temps réel + gère la rotation/recréation du fichier |
| `-f -q` | Suit plusieurs fichiers simultanément sans répéter les en-têtes |
| `-c N` | Affiche les N derniers octets |

## 4. Exemples pratiques & Cas d'usage

**Suivre un log applicatif en direct**
```bash
tail -f /var/log/app/production.log
```

**Suivre plusieurs logs simultanément (front + back)**
```bash
tail -f -q /var/log/nginx/access.log /var/log/app/error.log
```

**Surveiller les tentatives d'authentification en temps réel**
```bash
tail -f /var/log/auth.log | grep --line-buffered "Failed password"
```

**Extraire les 100 dernières lignes pour un rapport d'incident**
```bash
tail -n 100 /var/log/syslog > extrait_incident.log
```

**Reprendre la lecture d'un fichier à partir d'une ligne connue**
```bash
tail -n +500 export.csv
```

**Top des erreurs récentes dans un log (one-liner classique)**
```bash
tail -n 1000 error.log | grep ERROR | sort | uniq -c | sort -nr
```

## 5. Astuces & Pièges à éviter

!!! warning "tail -f vs tail -F lors d'une rotation logrotate"
    `tail -f` suit le descripteur de fichier ouvert : si `logrotate` renomme ou supprime le fichier, `tail -f` continue de lire l'ancien fichier (devenu orphelin) et n'affiche plus rien de nouveau. `tail -F` (majuscule) détecte la recréation du fichier et se réattache automatiquement au nouveau. **Sur un serveur avec logrotate actif, privilégiez toujours `-F`.**

!!! tip "Bufferiser correctement dans un pipe"
    Lors d'un `tail -f | grep`, ajoutez `--line-buffered` à `grep` pour éviter que la sortie ne s'affiche que par blocs bufferisés au lieu d'être immédiate.

!!! tip "One-liner d'analyse de fréquence"
    Le pattern `tail -n N fichier | sort | uniq -c | sort -nr` est l'un des plus utilisés en analyse de logs pour faire ressortir les occurrences les plus fréquentes (IP, codes erreur, user-agents).
