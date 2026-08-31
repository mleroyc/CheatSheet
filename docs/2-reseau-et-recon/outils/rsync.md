# 🛠️ Commande : rsync

## 1. Description rapide (Rôle et cas d'usage)

`rsync` synchronise des fichiers et dossiers en ne transférant que les différences entre la source et la destination (transfert delta), ce qui le rend nettement plus rapide et économe en bande passante que `scp` pour les sauvegardes récurrentes, les mises en miroir et les déploiements incrémentaux. Il fonctionne en local ou à travers SSH pour des transferts distants sécurisés.

## 2. Syntaxe de base

```bash
rsync [OPTIONS] source destination
rsync -avz source/ utilisateur@hote:/chemin/distant/
```

## 3. Options et fanions principaux

| Option | Effet |
|---|---|
| `-a` | Mode archive : préserve permissions, dates, liens, récursif (quasi indispensable) |
| `-v` | Mode verbeux |
| `-z` | Compresse les données pendant le transfert |
| `--delete` | Supprime dans la destination les fichiers absents de la source |
| `-P` / `--partial --progress` | Affiche la progression et permet la reprise d'un transfert interrompu |
| `--exclude=MOTIF` | Exclut les fichiers/dossiers correspondant au motif |
| `-e 'ssh -p PORT'` | Spécifie un port SSH personnalisé comme protocole de transport |
| `-n` / `--dry-run` | Simule l'opération sans rien modifier |

## 4. Exemples pratiques & Cas d'usage

**Sauvegarde standard d'un dossier vers un serveur distant**
```bash
rsync -avz /var/www/ admin@backup.example.com:/backups/www/
```

**Synchronisation miroir stricte (supprime ce qui n'existe plus côté source)**
```bash
rsync -avz --delete /data/production/ admin@backup.example.com:/data/mirror/
```

**Reprendre un transfert de gros fichier interrompu sur une connexion instable**
```bash
rsync -avzP grosse_archive.tar.gz admin@server.example.com:/backups/
```

**Déploiement incrémental en excluant les fichiers de développement**
```bash
rsync -avz --exclude='.git' --exclude='node_modules' ./app/ deploy@server.example.com:/var/www/app/
```

**Simuler une synchronisation pour vérifier ce qui serait transféré/supprimé**
```bash
rsync -avz --delete --dry-run /data/ admin@backup.example.com:/data/mirror/
```

**Synchroniser via un port SSH personnalisé**
```bash
rsync -avz -e 'ssh -p 2222' ./projet/ admin@server.example.com:/home/admin/projet/
```

## 5. Astuces & Pièges à éviter

!!! warning "Le slash final change radicalement le comportement"
    `rsync -avz src/ dest/` copie le **contenu** de `src` dans `dest`. `rsync -avz src dest/` copie le dossier `src` lui-même à l'intérieur de `dest` (créant `dest/src/`). Cette différence de syntaxe est la source d'erreur la plus fréquente avec `rsync` — toujours vérifier avec `--dry-run` en cas de doute.

!!! warning "--delete est destructif : toujours tester avec --dry-run d'abord"
    `--delete` supprime définitivement côté destination tout ce qui n'existe plus côté source. Une inversion accidentelle des chemins source/destination avec cette option peut effacer des données de production. Testez systématiquement avec `-n --dry-run` avant une exécution réelle.

!!! tip "rsync -avz : le trio quasi systématique"
    `-a` (archive, préserve tout), `-v` (verbeux, pour voir ce qui se passe) et `-z` (compression réseau) forment la combinaison de base utilisée dans la quasi-totalité des scripts de sauvegarde `rsync` en production.
