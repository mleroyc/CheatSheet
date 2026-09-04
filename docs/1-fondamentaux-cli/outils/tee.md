# 🛠️ Commande : tee

## 1. Description rapide (Rôle et cas d'usage)

`tee` est un utilitaire Unix/Linux qui lit les données depuis l'entrée standard (STDIN) et les **duplique** simultanément vers :

- la **sortie standard** (STDOUT), pour affichage à l'écran ou transmission à la suite d'un pipeline ;
- un ou plusieurs **fichiers** passés en argument.

Le nom vient de la forme en "T" d'un raccord de plomberie : le flux de données est scindé en deux (ou plusieurs) directions sans être interrompu, ce qui permet d'observer un flux tout en le persistant.

**Principaux cas d'usage :**

- **Journalisation de scripts** : conserver une trace (log) de l'exécution d'un script tout en affichant la sortie en temps réel dans le terminal.
- **Débogage de pipelines** : insérer un point d'inspection intermédiaire dans une chaîne de commandes (`cmd1 | tee debug.txt | cmd2`) sans casser le flux.
- **Écriture dans des fichiers protégés** : contourner les limitations de la redirection shell classique (`>`) lorsqu'une élévation de privilèges (`sudo`) est nécessaire, car la redirection est interprétée par le shell **avant** l'exécution de `sudo`.

---

## 2. Syntaxe de base

```bash
commande | tee [options] fichier...
```

- `commande` : la commande dont on souhaite capturer la sortie.
- `tee` : reçoit le flux via un pipe (`|`) sur son entrée standard.
- `fichier...` : un ou plusieurs fichiers cibles où écrire une copie du flux (facultatif — sans fichier, `tee` se comporte comme `cat`).

**Fonctionnement des descripteurs de fichier (STDOUT / STDERR) :**

Par défaut, `tee` ne capture que ce qui lui est explicitement transmis via le pipe, c'est-à-dire le descripteur **STDOUT (fd 1)** de la commande précédente. Le descripteur **STDERR (fd 2)** n'est **pas** intercepté par un pipe simple (`|`), car ce dernier ne redirige que STDOUT.

Pour que `tee` capture aussi les erreurs, il faut fusionner STDERR dans STDOUT **avant** le pipe :

```bash
commande 2>&1 | tee fichier.log
```

Ici, `2>&1` redirige le descripteur 2 (STDERR) vers la même destination que le descripteur 1 (STDOUT), de sorte que les deux flux arrivent mélangés dans le pipe lu par `tee`.

En interne, `tee` écrit sur chaque fichier de destination avec les mêmes octets qu'il reçoit sur STDIN, tout en les répercutant intégralement sur STDOUT — d'où la possibilité de le chaîner indéfiniment dans un pipeline.

---

## 3. Options et fanions principaux

| Option | Forme longue | Description |
|---|---|---|
| `-a` | `--append` | Ajoute les données à la fin du/des fichier(s) au lieu de l'/les écraser (comportement par défaut). |
| `-i` | `--ignore-interrupts` | Ignore les signaux d'interruption (`SIGINT`, ex. `Ctrl+C`), permettant à `tee` de terminer proprement l'écriture en cours. |
| `-p` | — | Diagnostique les erreurs d'écriture lorsque la sortie n'est pas un pipe (utile en combinaison avec `--output-error` pour éviter que `tee` ne se termine sur `SIGPIPE`). |
| — | `--output-error[=MODE]` | Définit le comportement en cas d'erreur d'écriture sur une sortie. Modes possibles : `warn` (avertit et continue), `warn-nopipe` (avertit sauf sur erreur de pipe), `exit` (arrête immédiatement), `exit-nopipe` (arrête sauf sur erreur de pipe). |
| — | `--help` | Affiche l'aide-mémoire des options disponibles. |
| — | `--version` | Affiche la version de `tee` installée. |

!!! tip "Astuce mémo"
    `-a` = **A**ppend (ajout), `-i` = **I**gnore les interruptions. Les deux sont combinables : `tee -ai fichier.log`.

---

## 4. Exemples pratiques & Cas d'usage concrets

### 1. Sauvegarde simple d'un pipeline

Affiche la sortie de `ls -la` à l'écran **et** l'enregistre dans un fichier :

```bash
ls -la | tee listing.txt
```

### 2. Écriture dans un fichier système / protégé

Contourne la limite de la redirection shell classique en déléguant l'écriture à `tee` exécuté avec `sudo` :

```bash
echo "options timeout:2" | sudo tee -a /etc/resolv.conf
```

### 3. Mode Append (Ajout)

Ajoute une ligne de log à la fin d'un fichier existant, sans écraser son contenu :

```bash
echo "$(date) - Tâche terminée avec succès" | tee -a app.log
```

### 4. Écriture simultanée dans plusieurs fichiers

`tee` accepte une liste de fichiers en arguments, écrits en parallèle :

```bash
ps aux | tee rapport_local.log rapport_backup.log /mnt/nas/rapport_distant.log
```

### 5. Capture des erreurs STDERR

Fusionne STDOUT et STDERR avant le pipe pour que `tee` capture l'intégralité de la sortie d'une commande, y compris ses erreurs :

```bash
./deploiement.sh 2>&1 | tee deploiement.log
```

Alternative avec la syntaxe bash `|&` (raccourci équivalent à `2>&1 |`) :

```bash
./deploiement.sh |& tee deploiement.log
```

### 6. Utilisation avancée avec Process Substitution

Envoie un même flux vers deux commandes différentes exécutées en parallèle, grâce à la substitution de processus `>(...)` :

```bash
cat access.log | tee >(grep "ERROR" > erreurs.txt) >(grep "WARN" > avertissements.txt) > /dev/null
```

Ici, `tee` duplique le flux vers deux sous-shells filtrant respectivement les erreurs et les avertissements, tout en évitant l'affichage redondant sur le terminal grâce à `> /dev/null`.

---

## 5. Astuces & Pièges à éviter

!!! danger "Piège de permission avec sudo"
    La commande `sudo echo "..." > /etc/file` **échoue** avec une erreur `Permission denied`, car la redirection (`>`) est interprétée par le **shell courant** (non privilégié) **avant** même que `sudo` n'exécute `echo`. Seule la commande `echo` s'exécute avec les droits root, pas la redirection.

    La solution consiste à déléguer l'écriture elle-même à un processus privilégié via `tee` :

    ```bash
    echo "nouvelle_config=true" | sudo tee /etc/config
    ```

    Ici, c'est `tee` (et non le shell) qui ouvre le fichier en écriture, avec les droits de `sudo`.

!!! warning "Écrasement involontaire (Ressources / Performance)"
    Par défaut, `tee` **écrase** le contenu du fichier cible à chaque exécution. Oublier l'option `-a` (`--append`) dans un script exécuté périodiquement (cron, boucle de supervision) entraîne la perte de tout l'historique précédent à chaque passage.

    ```bash
    # Écrase le fichier à chaque exécution
    monitoring.sh | tee status.log

    # Conserve l'historique
    monitoring.sh | tee -a status.log
    ```

!!! warning "Saturation de l'espace disque"
    Utiliser `tee` en mode `-a` dans une boucle infinie ou sur un flux à très haut débit (ex. supervision réseau, logs applicatifs verbeux) peut rapidement saturer l'espace disque disponible, en particulier sur des partitions systèmes critiques (`/var`, `/`).

    !!! tip "Bonnes pratiques"
        - Mettre en place une rotation de logs (`logrotate`) sur les fichiers alimentés par `tee`.
        - Surveiller la taille des fichiers cibles avec des alertes (`du`, `df`, outils de monitoring).
        - Envisager de limiter le volume via un filtrage en amont (`grep`, `awk`) avant l'écriture dans `tee`.
