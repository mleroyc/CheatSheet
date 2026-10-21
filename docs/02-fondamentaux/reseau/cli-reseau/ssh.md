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

## 6. Génération et gestion des clés SSH (Privées / Publiques)

L'authentification par paire de clés (asymétrique) est la méthode recommandée en remplacement de l'authentification par mot de passe : elle est à la fois plus robuste face au brute-force et plus pratique à l'usage une fois combinée à un agent SSH.

### 6.1 Génération de paires de clés (`ssh-keygen`)

**Génération moderne recommandée (Ed25519)**

L'algorithme **Ed25519** (courbe elliptique) est aujourd'hui recommandé par défaut : clés courtes, génération et vérification rapides, et niveau de sécurité élevé.

```bash
ssh-keygen -t ed25519 -C "admin@domaine.com"
```

**Génération RSA (legacy/fallback, taille minimale 4096 bits)**

RSA reste utile pour la compatibilité avec des systèmes anciens ne supportant pas Ed25519. Dans ce cas, une taille de clé de **4096 bits minimum** est requise.

```bash
ssh-keygen -t rsa -b 4096 -C "admin@domaine.com"
```

**Options clés de `ssh-keygen`**

| Option | Effet |
|---|---|
| `-t` | Type d'algorithme de clé (`ed25519`, `rsa`, `ecdsa`, ...) |
| `-b` | Taille de la clé en bits (pertinent pour RSA, ex : `4096`) |
| `-C` | Commentaire associé à la clé (généralement un identifiant/email) |
| `-f` | Chemin et nom du fichier de sortie pour la clé générée |
| `-N` | Définit la passphrase directement en ligne de commande (utile en scripting) |

!!! warning "Imposer une passphrase robuste"
    Lors de la génération, `ssh-keygen` propose de définir une **passphrase** protégeant la clé privée. Cette étape ne doit **jamais** être court-circuitée (passphrase vide) sur un poste de travail ou un compte à privilèges : sans passphrase, le simple vol du fichier de clé privée suffit à usurper l'identité de son propriétaire.

### 6.2 Anatomie et sécurité des fichiers de clés

Une paire de clés générée par `ssh-keygen` produit deux fichiers aux rôles strictement distincts :

- **`id_ed25519`** (sans extension) : la **clé privée**, strictement confidentielle, ne doit **jamais** quitter la machine sur laquelle elle a été générée ni être partagée, copiée sur un support non chiffré, ou envoyée par un canal non sécurisé.
- **`id_ed25519.pub`** : la **clé publique**, destinée à être **distribuée** et déposée dans le fichier `~/.ssh/authorized_keys` de chaque serveur distant auquel on souhaite se connecter.

**Permissions POSIX obligatoires (principe du moindre privilège)**

| Élément | Permissions | Représentation |
|---|---|---|
| Répertoire `~/.ssh` | `700` | `drwx------` |
| Clé privée (`id_ed25519`) | `600` | `-rw-------` |
| Clé publique (`id_ed25519.pub`) et `authorized_keys` | `644` (ou `600`) | `-rw-r--r--` |

!!! danger "Refus de connexion et exposition en cas de permissions trop ouvertes"
    La plupart des implémentations SSH (OpenSSH en tête) **refusent d'utiliser une clé privée** dont les permissions sont trop permissives (ex : lisible par le groupe ou par tous), et affichent une erreur du type `UNPROTECTED PRIVATE KEY FILE!`. Au-delà du blocage fonctionnel, des permissions trop larges sur une clé **sans passphrase** exposent directement l'identité associée à quiconque obtient un accès local, même non privilégié, à la machine.

**Commandes de correction rapide des permissions**

```bash
chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_ed25519 && chmod 644 ~/.ssh/authorized_keys
```

### 6.3 Déploiement et opérations sur les clés

**Copie automatisée de la clé publique vers le serveur distant**

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@remote-host
```

**Extraction/Régénération manuelle de la clé publique à partir d'une clé privée existante**

Utile si le fichier `.pub` a été perdu alors que la clé privée est toujours disponible :

```bash
ssh-keygen -y -f ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.pub
```

**Changement ou ajout de passphrase sur une clé privée existante sans régénérer la paire**

```bash
ssh-keygen -p -f ~/.ssh/id_ed25519
```

**Affichage de l'empreinte (fingerprint) et du visuel ASCII d'une clé**

L'empreinte permet de vérifier rapidement l'identité d'une clé sans comparer l'intégralité du blob, notamment pour valider une clé hôte lors d'une première connexion.

```bash
ssh-keygen -l -f ~/.ssh/id_ed25519.pub
ssh-keygen -lv -f ~/.ssh/id_ed25519.pub
```

### 6.4 Utilisation de l'Agent SSH (`ssh-agent`)

`ssh-agent` permet de charger une clé privée déchiffrée en mémoire (après saisie unique de la passphrase), afin d'éviter de la resaisir à chaque connexion durant la session.

**Démarrage de l'agent et chargement d'une clé privée**

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

**Gestion des clés chargées en mémoire**

```bash
# Lister les clés actuellement chargées dans l'agent
ssh-add -l

# Vider l'agent (supprime toutes les clés de la mémoire)
ssh-add -D
```

!!! tip "Confort et sécurité au quotidien"
    Combiner `ssh-agent` avec des clés Ed25519 protégées par passphrase offre le meilleur compromis : la clé privée reste chiffrée sur le disque, et la passphrase n'est saisie qu'une fois par session, sans jamais transiter en clair sur le réseau.

!!! danger "Portée de l'agent lors d'un rebond SSH (agent forwarding)"
    L'option `-A` (agent forwarding) expose l'agent local — et donc la capacité de signer des authentifications avec la clé privée — à chaque serveur intermédiaire sur lequel on rebondit. Un serveur distant compromis peut alors utiliser cet agent forwardé pour s'authentifier ailleurs au nom de l'utilisateur. À réserver aux environnements de confiance, ou à remplacer par du `ProxyJump` (`-J`) qui ne partage pas l'agent avec les hôtes intermédiaires.
