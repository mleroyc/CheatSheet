# 🛠️ Commande : split

## 1. Description rapide (Rôle et cas d'usage)

`split` découpe un gros fichier en plusieurs fragments plus petits, selon un nombre de lignes ou une taille en octets/Mo/Go. Très utile pour transférer un fichier volumineux par des canaux limités en taille, paralléliser un traitement, ou respecter des contraintes d'upload (email, stockage cloud).

## 2. Syntaxe de base

```bash
split [OPTIONS] fichier [prefixe]
```

## 3. Options et fanions principaux

| Option | Effet |
|---|---|
| `-l N` | Découpe par nombre de lignes (N lignes par fragment) |
| `-b TAILLE` | Découpe par taille (ex: `100M`, `1G`) |
| `-d` | Utilise des suffixes numériques (`00`, `01`...) au lieu de lettres |
| `-a N` | Longueur du suffixe généré (défaut : 2 caractères) |
| `--additional-suffix=EXT` | Ajoute une extension aux fichiers générés |

## 4. Exemples pratiques & Cas d'usage

**Découper un gros log en fragments de 10000 lignes**
```bash
split -l 10000 gros_fichier.log fragment_
```

**Découper un fichier en morceaux de 100 Mo pour un envoi par email**
```bash
split -b 100M archive.tar.gz archive_part_
```

**Utiliser des suffixes numériques pour un tri prévisible**
```bash
split -d -a 3 -l 5000 export.csv export_part_
```

**Découper un fichier en gardant l'extension .log sur chaque fragment**
```bash
split -l 5000 --additional-suffix=.log big.log chunk_
```

**Réassembler les fragments après transfert**
```bash
cat fragment_* > gros_fichier_reconstruit.log
```

**Vérifier l'intégrité après réassemblage via checksum**
```bash
sha256sum gros_fichier.log gros_fichier_reconstruit.log
```

## 5. Astuces & Pièges à éviter

!!! warning "L'ordre de réassemblage dépend du tri des noms de fragments"
    `cat fragment_*` s'appuie sur l'ordre alphabétique du shell. Avec des suffixes alphabétiques par défaut (`aa`, `ab`, ...) ou numériques via `-d`, l'ordre reste correct jusqu'à 26/100 fragments — au-delà, augmentez la longueur du suffixe avec `-a` pour éviter un tri incorrect (`part_9` après `part_10`).

!!! tip "Toujours vérifier l'intégrité après réassemblage"
    Comparez un checksum (`sha256sum` ou `md5sum`) du fichier original et du fichier reconstruit après `cat` pour garantir qu'aucun fragment n'a été perdu ou corrompu pendant le transfert.

!!! tip "-d pour un tri numérique plus lisible"
    Par défaut, `split` utilise des suffixes alphabétiques (`aa`, `ab`, `ac`...). L'option `-d` génère des suffixes numériques (`00`, `01`, `02`...), souvent plus intuitifs pour scripter le traitement des fragments un par un.
