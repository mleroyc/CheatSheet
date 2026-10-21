# 🛠️ Commande : cat

## 1. Description rapide (Rôle et cas d'usage)

`cat` (*concatenate*) affiche le contenu d'un ou plusieurs fichiers sur la sortie standard. C'est l'outil le plus simple pour lire un fichier texte, concaténer plusieurs fichiers en un seul, ou injecter du contenu dans un pipe. Contrairement à `less`, `cat` charge et affiche tout le contenu d'un coup, sans pagination.

## 2. Syntaxe de base

```bash
cat [OPTIONS] fichier1 [fichier2 ...]
```

Sans fichier en argument, `cat` lit depuis l'entrée standard (`stdin`) jusqu'à `Ctrl+D`.

## 3. Options et fanions principaux

| Option | Effet |
|---|---|
| `-n` | Numérote toutes les lignes de sortie |
| `-b` | Numérote uniquement les lignes non vides |
| `-A` | Affiche tous les caractères invisibles (`$` fin de ligne, `^I` tabulation, etc.) |
| `-s` | Compresse les lignes vides multiples en une seule |
| `-E` | Affiche `$` en fin de chaque ligne |
| `-T` | Affiche les tabulations sous forme de `^I` |

## 4. Exemples pratiques & Cas d'usage

**Lire rapidement un petit fichier**
```bash
cat /etc/hostname
```

**Concaténer plusieurs fragments en un seul fichier**
```bash
cat part_aa part_ab part_ac > total.log
```

**Numéroter les lignes d'un fichier de configuration pour le débogage**
```bash
cat -n /etc/ssh/sshd_config
```

**Détecter des caractères invisibles suspects dans un fichier (fins de ligne Windows, tabulations)**
```bash
cat -A script.sh | grep '\^M'
```

**Créer rapidement un fichier depuis le terminal (heredoc-like)**
```bash
cat > notes.txt
```

**Injecter le contenu d'un fichier dans un pipe d'analyse**
```bash
cat access.log | grep "500" | wc -l
```

## 5. Astuces & Pièges à éviter

!!! warning "Ne pas utiliser cat sur de gros fichiers"
    `cat` charge l'intégralité du fichier en sortie sans pagination. Sur un fichier de plusieurs Go (ex: un log volumineux), préférez `less` ou `tail -f` pour éviter de saturer le terminal.

!!! tip "Useless Use of Cat (UUOC)"
    `cat fichier | grep motif` est redondant : `grep motif fichier` fait la même chose, plus vite, sans processus supplémentaire. Réservez `cat` en début de pipe aux cas où plusieurs fichiers doivent être concaténés avant traitement.

!!! tip "Vérifier l'ordre de concaténation"
    Lors de la reconstruction de fichiers découpés (`split`), assurez-vous que le glob (`part_*`) trie les fragments dans le bon ordre alphabétique/numérique avant de les concaténer avec `cat`.
