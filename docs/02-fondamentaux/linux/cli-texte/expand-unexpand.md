# 🛠️ Commande : expand / unexpand

## 1. Description rapide (Rôle et cas d'usage)

`expand` convertit les tabulations d'un fichier en espaces, tandis que `unexpand` fait l'inverse (espaces en tabulations). Ces outils servent principalement à nettoyer et normaliser des scripts, fichiers de configuration ou dumps de bases de données dont l'indentation mélange tabulations et espaces — une source classique de bugs et de diffs illisibles.

## 2. Syntaxe de base

```bash
expand [OPTIONS] fichier
unexpand [OPTIONS] fichier
```

## 3. Options et fanions principaux

| Option | Commande | Effet |
|---|---|---|
| `-t N` | `expand` / `unexpand` | Définit la largeur de tabulation (défaut : 8) |
| `-i` | `expand` | Ne convertit que les tabulations en début de ligne |
| `-a` | `unexpand` | Convertit aussi les espaces internes (pas seulement en début de ligne) |
| `--first-only` | `unexpand` | Ne convertit que la première séquence d'espaces de chaque ligne |

## 4. Exemples pratiques & Cas d'usage

**Normaliser un script mélangeant tabulations et espaces**
```bash
expand -t 4 script.sh > script_propre.sh
```

**Convertir les tabulations d'un fichier de config en 2 espaces**
```bash
expand -t 2 nginx.conf.tabs > nginx.conf
```

**Nettoyer un export de base de données avant import CSV**
```bash
expand dump_brut.sql > dump_propre.sql
```

**Reconvertir un fichier indenté en espaces vers des tabulations (norme Makefile)**
```bash
unexpand -a --first-only Makefile.txt > Makefile
```

**Comparer deux versions d'un fichier en ignorant les différences d'indentation**
```bash
diff <(expand fichier_v1.sh) <(expand fichier_v2.sh)
```

**Vérifier visuellement la présence de tabulations avant nettoyage**
```bash
cat -A fichier.conf | grep '\^I'
```

## 5. Astuces & Pièges à éviter

!!! warning "Makefile exige des tabulations strictes"
    Un `Makefile` nécessite des tabulations réelles (pas des espaces) pour indenter les recettes. Un éditeur qui convertit automatiquement les tabs en espaces peut casser le fichier — utilisez `unexpand` pour restaurer les tabulations avant de committer.

!!! tip "Toujours vérifier avant/après avec cat -A"
    Avant et après une conversion `expand`/`unexpand`, utilisez `cat -A` pour visualiser précisément les caractères invisibles (`^I` pour tab, `$` pour fin de ligne) et confirmer que la conversion a bien eu l'effet attendu.

!!! tip "Utiliser diff avec expand pour ignorer l'indentation"
    Combiner `expand` avec `diff` via une substitution de processus permet de comparer deux fichiers en neutralisant les différences purement liées au type d'indentation (tabs vs espaces).
