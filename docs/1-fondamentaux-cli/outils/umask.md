# 🛠️ Commande & Concept : umask

## 1. Description rapide (Rôle et cas d'usage)

`umask` (**U**ser file creation **Mask**) est à la fois une commande shell interne (builtin) et un concept fondamental du modèle de permissions Unix/Linux. Il ne s'agit pas de modifier des permissions existantes, mais de définir un **masque appliqué automatiquement à chaque création** de fichier ou de répertoire.

**Principe fondamental :** `umask` définit les permissions **retirées par défaut** lors de la création d'un nouveau fichier ou répertoire — il ne s'ajoute jamais aux droits, il ne fait que les **soustraire** d'une base maximale théorique.

**Différence essentielle entre fichiers et répertoires :**

- **Répertoires** : la base de départ est `777` (`rwxrwxrwx`), car un répertoire a naturellement besoin du bit d'exécution (`x`) pour être traversé (`cd`).
- **Fichiers** : la base de départ est `666` (`rw-rw-rw-`), **sans** bit d'exécution — un fichier ordinaire n'est jamais rendu exécutable par la seule création, quel que soit le masque appliqué.

**Principaux cas d'usage :**

- **Sécurisation des nouveaux fichiers** sur des serveurs Web ou des dossiers partagés (empêcher la lecture par des tiers non autorisés).
- **Durcissement système (hardening)** : imposer un masque restrictif par défaut sur des systèmes sensibles.
- **Isolation multi-utilisateurs** : garantir que les fichiers créés par un utilisateur ne soient pas accessibles en écriture (voire en lecture) par les autres comptes du système.

---

## 2. Syntaxe & Calcul de Masque

**Syntaxe générale :**

```bash
umask [options] [MASQUE]
```

**Calcul mathématique (opération bitwise, pas une soustraction arithmétique) :**

Le calcul réel effectué par le noyau n'est **pas** une soustraction décimale, mais une opération bit à bit : `permissions_de_base AND (NOT masque)`. Formulé de façon plus intuitive pour un usage courant :

- **Répertoires :** `777 - umask = permissions_résultantes`
- **Fichiers :** `666 - umask = permissions_résultantes`, avec **écrêtage systématique des bits d'exécution** (un fichier ne reçoit jamais le bit `x` via la création, indépendamment du masque).

**Tableau des correspondances octales (par tranche Utilisateur / Groupe / Autres) :**

| Valeur octale | Droits retirés | Signification |
|---|---|---|
| `0` | Aucun | Lecture, écriture, exécution conservées (`rwx`) |
| `1` | Exécution | Retire `x` |
| `2` | Écriture | Retire `w` |
| `3` | Écriture + Exécution | Retire `wx` |
| `4` | Lecture | Retire `r` |
| `5` | Lecture + Exécution | Retire `rx` |
| `6` | Lecture + Écriture | Retire `rw` |
| `7` | Lecture + Écriture + Exécution | Retire `rwx` (aucun droit restant) |

---

## 3. Options et modes d'affichage

| Commande / Option | Description |
|---|---|
| `umask` | Affiche la valeur octale du masque courant (ex. `0022`). |
| `-S`, `--symbolic` | Affiche ou définit le masque sous forme symbolique lisible, exprimant les droits **conservés** (ex. `u=rwx,g=rx,o=rx`). |
| `umask NNNN` | Définit un nouveau masque (en octal) pour la session shell courante uniquement — non persistant après fermeture du terminal. |

!!! tip "Astuce mémo"
    En mode octal (`umask 022`), la valeur représente les droits **retirés**. En mode symbolique (`umask -S`), la sortie représente au contraire les droits **conservés** — ne pas confondre les deux logiques lors de la lecture.

---

## 4. Exemples pratiques & Cas d'usage concrets

### 1. Masque par défaut standard (`0022` ou `022`)

Configuration la plus répandue sur les systèmes Linux (utilisateur standard) :

```bash
umask 022
```

- Répertoires : `777 - 022 = 755` (`rwxr-xr-x`)
- Fichiers : `666 - 022 = 644` (`rw-r--r--`)

### 2. Masque sécurisé / Restreint (`0077` ou `077`)

Recommandé pour des répertoires contenant des données sensibles (clés privées, secrets, données personnelles), retirant tout accès au groupe et aux autres :

```bash
umask 077
```

- Répertoires : `777 - 077 = 700` (`rwx------`)
- Fichiers : `666 - 077 = 600` (`rw-------`)

### 3. Masque pour travail collaboratif (`0002` ou `002`)

Conserve les droits d'écriture pour le groupe, adapté à des répertoires partagés entre membres d'une même équipe :

```bash
umask 002
```

- Répertoires : `777 - 002 = 775` (`rwxrwxr-x`)
- Fichiers : `666 - 002 = 664` (`rw-rw-r--`)

### 4. Définition temporaire dans un script

Modifie le masque au début d'un script sensible (backup, génération de clé) pour isoler les fichiers créés, puis restaure la valeur d'origine à la fin :

```bash
#!/bin/bash

masque_origine=$(umask)   # Sauvegarde du masque courant
umask 077                 # Masque restrictif pour la durée du script

ssh-keygen -t ed25519 -f /tmp/cle_temporaire -N ""
tar -czf backup_confidentiel.tar.gz /etc/secrets/

umask "$masque_origine"   # Restauration du masque d'origine
```

### 5. Vérification sous forme symbolique (`umask -S`)

Consulte et modifie les droits de façon lisible, en exprimant directement les permissions conservées par tranche :

```bash
umask -S
# u=rwx,g=rx,o=rx

umask u=rwx,g=,o=
# Retire tous les droits au groupe et aux autres
```

---

## 5. Configuration permanente, Astuces & Pièges à éviter

!!! tip "Persistance de la configuration"
    Un `umask` défini en ligne de commande n'est valable que pour la **session shell courante**. Pour une configuration persistante, définir la valeur dans les fichiers de démarrage appropriés :

    - **Globalement (tous les utilisateurs)** : `/etc/profile`, `/etc/bashrc` (ou `/etc/bash.bashrc` selon la distribution), voire `/etc/login.defs` (directive `UMASK`, appliquée aux connexions gérées par `login`).
    - **Par utilisateur** : `~/.bashrc` ou `~/.profile`, pour surcharger la valeur globale sur un compte spécifique.

    ```bash
    # Ajout dans ~/.bashrc
    umask 022
    ```

!!! warning "Comportement des services & Daemons (Systemd)"
    Le `umask` défini dans un shell utilisateur **n'affecte pas** les processus démarrés par `systemd` (services, daemons) — ceux-ci héritent d'un masque par défaut propre à `systemd` (généralement `0022`), indépendant de la configuration shell.

    Pour un service dont les fichiers créés doivent respecter un masque spécifique (ex. Nginx, Apache, serveur FTP), il faut définir explicitement la directive `UMask=` dans le fichier d'unité systemd :

    ```ini
    # /etc/systemd/system/mon-service.service (extrait)
    [Service]
    UMask=0027
    ```

    Puis recharger la configuration :

    ```bash
    sudo systemctl daemon-reload
    sudo systemctl restart mon-service
    ```

!!! danger "Le piège de la soustraction simple avec nombres impairs"
    Le calcul `base - umask` est une simplification pédagogique pratique, mais **ce n'est pas une véritable soustraction arithmétique** — c'est une opération bit à bit (`AND` du complément). Cette nuance devient visible avec des masques impairs appliqués aux fichiers.

    **Exemple piège :** `666 - 023` donnerait naïvement `643` par soustraction arithmétique classique. Or le résultat réel est `644` :

    ```bash
    umask 023
    touch test.txt
    ls -l test.txt
    # -rw-r--r--  (644, PAS 643)
    ```

    **Explication :** le masque `023` retire le bit `x` (valeur 1) sur le groupe et les bits `wx` (valeur 3) sur les autres. Mais les fichiers ordinaires n'ont **jamais** le bit d'exécution activé par défaut lors de leur création (base `666`, sans aucun `x`) — retirer un bit `x` qui n'existait déjà pas ne change rien au résultat final. La soustraction arithmétique naïve (`666 - 023 = 643`) est donc **trompeuse** pour toute composante du masque touchant le bit d'exécution sur des fichiers.

    **Réflexe recommandé :** toujours raisonner en **opération bit à bit** (quel droit est present dans la base, quel droit le masque retire-t-il réellement) plutôt qu'en soustraction décimale directe, surtout pour valider un masque avant déploiement en production.
