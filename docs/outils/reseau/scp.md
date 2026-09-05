# 🛠️ Commande : scp

## 1. Description rapide (Rôle et cas d'usage)

`scp` (*secure copy*) copie des fichiers ou dossiers entre machines à travers une connexion SSH chiffrée. Sa syntaxe simple et proche de `cp` en fait l'outil de premier réflexe pour des transferts ponctuels, mais il reste limité face à `rsync` pour les gros volumes ou les synchronisations répétées.

## 2. Syntaxe de base

```bash
scp [OPTIONS] source destination
# Local vers distant
scp fichier utilisateur@hote:/chemin/distant/
# Distant vers local
scp utilisateur@hote:/chemin/distant/fichier /chemin/local/
```

## 3. Options et fanions principaux

| Option | Effet |
|---|---|
| `-r` | Copie récursive (dossiers entiers) |
| `-P PORT` | Spécifie le port SSH (majuscule, contrairement à `ssh -p`) |
| `-i FICHIER` | Spécifie la clé privée à utiliser |
| `-C` | Compresse les données pendant le transfert |
| `-p` | Préserve les dates de modification et permissions |
| `-v` | Mode verbeux pour déboguer un transfert qui échoue |

## 4. Exemples pratiques & Cas d'usage

**Copier un fichier local vers un serveur distant**
```bash
scp rapport.pdf admin@server.example.com:/home/admin/
```

**Récupérer un fichier de log distant pour analyse locale**
```bash
scp admin@server.example.com:/var/log/app/error.log ./logs_analyse/
```

**Copier récursivement un dossier complet de déploiement**
```bash
scp -r ./build/ deploy@server.example.com:/var/www/app/
```

**Transférer via un port SSH non standard avec une clé dédiée**
```bash
scp -P 2222 -i ~/.ssh/id_deploy backup.tar.gz admin@server.example.com:/backups/
```

**Copier un fichier entre deux serveurs distants directement**
```bash
scp admin@serveurA:/data/export.csv admin@serveurB:/import/
```

**Exfiltrer rapidement des artefacts collectés lors d'un test d'intrusion (usage légitime autorisé)**
```bash
scp -C pentester@target-jumphost:/tmp/collecte.tar.gz ./resultats/
```

## 5. Astuces & Pièges à éviter

!!! warning "scp ne reprend pas un transfert interrompu"
    Contrairement à `rsync`, si un transfert `scp` est interrompu (coupure réseau), il faut le relancer intégralement depuis le début — aucune reprise partielle n'est possible. Pour de gros fichiers sur une connexion instable, préférez `rsync`.

!!! warning "scp -P (majuscule) vs ssh -p (minuscule)"
    Piège classique : `ssh` utilise `-p` (minuscule) pour le port, tandis que `scp` utilise `-P` (majuscule). Une confusion entre les deux est une source fréquente d'erreurs "Connection refused" en script.

!!! tip "Pas de synchronisation différentielle"
    `scp` recopie l'intégralité des fichiers à chaque exécution, même si seule une petite partie a changé. Pour des sauvegardes régulières ou des déploiements incrémentaux, `rsync` est nettement plus efficace en bande passante et en temps.
