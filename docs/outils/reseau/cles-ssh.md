# 🛠️ Notion : Clés SSH (authentification par clé)

## 1. Description rapide (Rôle et cas d'usage)

L'authentification par clé SSH remplace le mot de passe par une paire de clés cryptographiques (privée/publique), bien plus sécurisée et indispensable pour l'automatisation (déploiement, scripts, CI/CD). La clé privée reste secrète sur la machine cliente, la clé publique est déposée sur les serveurs auxquels on souhaite se connecter.

## 2. Syntaxe de base

```bash
ssh-keygen -t TYPE [-b BITS] [-f FICHIER]
ssh-copy-id [-i FICHIER.pub] utilisateur@hote
```

## 3. Options et fanions principaux

| Option / Commande | Effet |
|---|---|
| `ssh-keygen -t ed25519` | Génère une paire de clés au format Ed25519 (recommandé, rapide et sûr) |
| `ssh-keygen -t rsa -b 4096` | Génère une paire de clés RSA de 4096 bits (compatibilité maximale) |
| `-f FICHIER` | Spécifie le nom/emplacement du fichier de clé généré |
| `-C "commentaire"` | Ajoute un commentaire (souvent un email) à la clé publique |
| `ssh-copy-id user@host` | Copie automatiquement la clé publique dans `authorized_keys` du serveur |
| `chmod 700 ~/.ssh` | Restreint les permissions du dossier `.ssh` |
| `chmod 600 clé_privée` | Restreint les permissions de la clé privée |

## 4. Exemples pratiques & Cas d'usage

**Générer une paire de clés moderne pour un poste d'administration**
```bash
ssh-keygen -t ed25519 -C "admin@poste-travail"
```

**Générer une clé RSA pour compatibilité avec un vieux serveur**
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_legacy
```

**Déployer la clé publique vers un serveur pour supprimer l'authentification par mot de passe**
```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub deploy@server.example.com
```

**Générer une clé dédiée à un pipeline CI/CD sans phrase de passe**
```bash
ssh-keygen -t ed25519 -f ~/.ssh/ci_deploy_key -N ""
```

**Corriger des permissions trop permissives qui bloquent SSH**
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

**Vérifier quelles clés sont autorisées sur un serveur (audit de sécurité)**
```bash
cat ~/.ssh/authorized_keys
```

## 5. Astuces & Pièges à éviter

!!! warning "Des permissions trop ouvertes font échouer silencieusement l'authentification"
    SSH refuse d'utiliser une clé privée ou un dossier `.ssh` accessible en écriture à d'autres utilisateurs (`chmod` supérieur à `600`/`700`). L'erreur `Permissions 0644 for 'id_rsa' are too open` est un des blocages les plus fréquents en dépannage SSH.

!!! tip "Ed25519 plutôt que RSA par défaut"
    `ed25519` offre une sécurité équivalente ou supérieure à RSA 4096 bits avec des clés bien plus courtes et des opérations plus rapides. Ne conservez `rsa -b 4096` que pour compatibilité avec des équipements anciens qui ne supportent pas Ed25519.

!!! tip "Comprendre le rôle de chaque fichier"
    `id_ed25519`/`id_rsa` (clé privée, **jamais partagée**), `.pub` (clé publique, à distribuer), `known_hosts` (empreintes des serveurs déjà validés côté client), `authorized_keys` (liste des clés publiques autorisées à se connecter, côté serveur).
