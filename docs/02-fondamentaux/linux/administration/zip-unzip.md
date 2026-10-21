# 🛠️ Commande : zip / unzip

## 1. Description rapide (Rôle et cas d'usage)

`zip` et `unzip` créent et extraient des archives au format `.zip`, le format de compression le plus répandu en interopérabilité avec Windows et macOS. Contrairement à `tar`, `zip` compresse et archive en une seule étape et son format est nativement reconnu par la majorité des systèmes d'exploitation sans outil additionnel.

## 2. Syntaxe de base

```bash
zip [OPTIONS] archive.zip fichiers/dossiers
unzip [OPTIONS] archive.zip
```

## 3. Options et fanions principaux

| Option | Commande | Effet |
|---|---|---|
| `-r` | `zip` | Compression récursive d'un dossier |
| `-e` | `zip` | Chiffre l'archive avec un mot de passe |
| `-9` | `zip` | Niveau de compression maximal |
| `-d DIR` | `unzip` | Extrait dans un dossier cible spécifique |
| `-l` | `unzip` | Liste le contenu sans extraire |
| `-o` | `unzip` | Écrase les fichiers existants sans confirmation |
| `-x MOTIF` | `unzip` | Exclut des fichiers de l'extraction |

## 4. Exemples pratiques & Cas d'usage

**Compresser récursivement un dossier de projet**
```bash
zip -r projet_final.zip /home/user/projet/
```

**Extraire une archive dans un dossier de destination précis**
```bash
unzip archive.zip -d /var/www/deploiement/
```

**Lister le contenu d'une archive avant extraction (vérification sécurité)**
```bash
unzip -l archive_recue.zip
```

**Créer une archive protégée par mot de passe pour un transfert de données sensibles**
```bash
zip -er donnees_confidentielles.zip /data/rapports/
```

**Préparer un livrable interopérable Windows/macOS pour un client**
```bash
zip -r livrable_client.zip build/ README.md
```

**Extraire en écrasant les fichiers existants sans confirmation (script automatisé)**
```bash
unzip -o deploy.zip -d /opt/app/
```

## 5. Astuces & Pièges à éviter

!!! tip "Format universel pour l'interopérabilité"
    Contrairement à `.tar.gz` qui nécessite un outil dédié sous Windows, le format `.zip` est nativement supporté par l'explorateur de fichiers Windows et macOS Finder — à privilégier pour les livrables destinés à des utilisateurs non-Linux.

!!! warning "unzip -l avant extraction pour éviter les surprises"
    Toujours vérifier le contenu avec `unzip -l archive.zip` avant extraction, surtout pour une archive reçue d'une source externe : une archive malveillante peut contenir des chemins absolus ou des `../` visant à écrire hors du dossier cible (zip slip).

!!! tip "Chiffrement -e limité en sécurité"
    Le chiffrement natif de `zip -e` utilise un algorithme faible (ZipCrypto), cassable rapidement. Pour un besoin de confidentialité réel, préférez `gpg` ou une archive `tar` chiffrée via `openssl`/`age` plutôt que le mot de passe intégré à `zip`.
