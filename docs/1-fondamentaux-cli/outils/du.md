# 🛠️ du — Analyse de la taille des fichiers et dossiers

## 1. Description rapide

`du` (*Disk Usage*) parcourt récursivement une arborescence de fichiers et calcule l'espace disque **réellement consommé** par chaque élément. Contrairement à `df` qui lit les métadonnées du système de fichiers, `du` descend dans les répertoires et additionne la taille de chaque fichier.

**Cas d'usage :** identifier les répertoires ou fichiers consommant le plus d'espace, diagnostiquer une saturation disque, auditer la taille de logs ou de données applicatives, nettoyer un serveur.

---

## 2. Syntaxe de base

```bash
du [options] [chemin...]
```

```bash
du                           # Taille de chaque sous-répertoire du répertoire courant (en blocs)
du -sh /var                  # Taille totale de /var en format lisible
du -sh *                     # Taille de chaque élément du répertoire courant
du -h --max-depth=1 /var     # Taille des sous-répertoires de premier niveau de /var
```

---

## 3. Options et fanions principaux

| Option | Signification |
|---|---|
| `-s` | Summary — affiche uniquement le total, pas les sous-répertoires |
| `-h` | Human-readable : Ko, Mo, Go, To |
| `-a` | Affiche la taille de chaque **fichier** individuellement (pas uniquement les dossiers) |
| `--max-depth=N` | Limite la récursion à N niveaux de profondeur |
| `-d N` | Alias court de `--max-depth=N` |
| `-c` | Affiche un total cumulé en dernière ligne |
| `--exclude=<motif>` | Exclut les fichiers/dossiers correspondant au motif |
| `-x` | Limite à un seul système de fichiers (n'entre pas dans les montages NFS, tmpfs...) |
| `--time` | Affiche la date de dernière modification de chaque entrée |
| `--apparent-size` | Affiche la taille apparente (déclarée) et non les blocs alloués |

---

## 4. Exemples pratiques

```bash
# Taille totale d'un répertoire
du -sh /var/log

# Taille de chaque élément dans le répertoire courant, trié par taille décroissante
du -sh * | sort -hr

# Top 10 des plus gros sous-répertoires dans /var (profondeur 1)
du -h --max-depth=1 /var | sort -hr | head -10

# Trouver les 20 plus gros fichiers individuels dans /var/log
du -ah /var/log | sort -hr | head -20

# Analyser /home avec profondeur 2 et exclure les fichiers cachés
du -h --max-depth=2 /home --exclude=".*"

# Avec total cumulé à la fin
du -sh /var/log /var/cache /var/lib -c

# Exclure un type de fichier — ignorer les fichiers de log
du -sh /var --exclude="*.log"

# Rester dans le même système de fichiers (ne pas traverser les montages)
du -sh -x /

# Identifier les fichiers les plus récemment modifiés et volumineux
du -ah --time /var/log | sort -hr | head -10

# Nettoyer : trouver les répertoires vides (taille 0)
find /var -type d -empty
```

```bash
# One-liner complet : top 15 des plus gros consommateurs dans /
du -h --max-depth=2 / 2>/dev/null | sort -hr | head -15
# 2>/dev/null supprime les erreurs de permission (répertoires non accessibles)
```

---

## 5. Astuces & Pièges à éviter

!!! tip "Combiner du et sort correctement"
    ```bash
    du -sh * | sort -hr
    # -h : tri alphanumérique sur les tailles human-readable (Go > Mo > Ko)
    # -r : ordre décroissant (plus grand en premier)
    # Sans -h dans sort, "9M" serait trié après "100K" (tri lexicographique)
    ```

!!! warning "du sur NFS peut être très lent"
    `du` sur un point de montage réseau (NFS, CIFS) génère une lecture de chaque fichier via le réseau — extrêmement lent sur des volumes volumineux. Utiliser `-x` pour rester dans le système de fichiers local et exclure les montages réseau :
    ```bash
    du -sh -x /
    ```

!!! warning "Fichiers supprimés mais encore ouverts n'apparaissent pas dans du"
    `du` ne voit que les fichiers ayant encore un lien dans le système de fichiers. Un fichier supprimé mais encore ouvert par un processus consomme de l'espace (visible dans `df`) mais n'apparaît pas dans `du`. Détecter avec :
    ```bash
    lsof | grep "(deleted)"
    ```

!!! tip "Chercher les fichiers volumineux avec find comme alternative"
    ```bash
    find /var -type f -size +100M -exec du -sh {} \;
    # Cible directement les fichiers dépassant 100 Mo, plus rapide que du -a sur une arborescence entière

    find /var/log -type f -size +50M | sort
    # Liste rapide des logs dépassant 50 Mo
    ```

!!! tip "Audit rapide d'un répertoire /home en sysadmin"
    ```bash
    du -sh /home/* | sort -hr
    # Qui consomme le plus dans /home ?
    # Révèle rapidement un utilisateur dont le répertoire a explosé
    ```
