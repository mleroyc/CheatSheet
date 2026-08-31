# 🛠️ Commande : ssh

## 1. Description rapide (Rôle et cas d'usage)

`ssh` (*Secure Shell*) établit une connexion shell chiffrée vers une machine distante. C'est l'outil central de l'administration système à distance, et il sert aussi de socle de transport sécurisé pour `scp`, `rsync`, ainsi que pour le tunneling réseau (pivotement en pentest, contournement de pare-feu).

## 2. Syntaxe de base

```bash
ssh [OPTIONS] utilisateur@hote [commande]
```

## 3. Options et fanions principaux

| Option | Effet |
|---|---|
| `-p PORT` | Spécifie le port SSH distant (défaut : 22) |
| `-i FICHIER` | Spécifie la clé privée à utiliser pour l'authentification |
| `-L LOCAL:HOTE:DISTANT` | Tunnel local : redirige un port local vers une ressource distante |
| `-R DISTANT:HOTE:LOCAL` | Tunnel distant : expose un service local sur la machine distante |
| `-D PORT` | Crée un proxy SOCKS dynamique (pivotement réseau) |
| `-v` | Mode verbeux, utile pour déboguer une connexion qui échoue |
| `-N` | N'exécute aucune commande distante (utile pour un tunnel pur) |

## 4. Exemples pratiques & Cas d'usage

**Connexion standard à un serveur distant**
```bash
ssh admin@203.0.113.10
```

**Connexion sur un port SSH non standard avec une clé spécifique**
```bash
ssh -i ~/.ssh/id_ed25519_prod -p 2222 deploy@server.example.com
```

**Exécuter une commande distante sans ouvrir de shell interactif (scripting)**
```bash
ssh admin@server.example.com "df -h && uptime"
```

**Rediriger un port de base de données distante vers le poste local (accès sécurisé)**
```bash
ssh -L 5432:localhost:5432 admin@db.internal.example.com
```

**Exposer un service local à un serveur distant (démo, webhook temporaire)**
```bash
ssh -R 8080:localhost:3000 admin@server.example.com
```

**Créer un proxy SOCKS pour pivoter à travers un serveur compromis/autorisé (pentest)**
```bash
ssh -D 1080 -N admin@pivot.internal.example.com
```

## 5. Astuces & Pièges à éviter

!!! warning "Toujours vérifier l'empreinte du serveur lors d'une première connexion"
    Un message `The authenticity of host '...' can't be established` doit être vérifié (empreinte connue) avant d'accepter — accepter aveuglément expose à une attaque de type Machine-in-the-Middle sur des réseaux non fiables.

!!! tip "-D pour le pivotement réseau en test d'intrusion"
    L'option `-D` (proxy SOCKS dynamique) permet de router le trafic d'un navigateur ou d'un outil (via `proxychains`) à travers la machine distante, un usage central en pivotement réseau lors d'un pentest interne.

!!! tip "Automatiser une commande distante en toute sécurité"
    `ssh hote "commande"` exécute la commande et referme la connexion automatiquement — idéal dans des scripts de supervision ou de déploiement sans laisser de session interactive ouverte inutilement.
