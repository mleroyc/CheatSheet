# 🛠️ Commande : history

## 1. Description rapide (Rôle et cas d'usage)

`history` est la commande interne (builtin) de Bash/Zsh qui gère le mécanisme de **journalisation des commandes** saisies dans le terminal. Chaque commande exécutée dans une session interactive est conservée en mémoire, puis persistée dans un fichier d'historique (`~/.bash_history` par défaut pour Bash) à la fermeture ou à la synchronisation de la session.

**Principaux cas d'usage :**

- **Réexécution rapide de commandes complexes**, sans avoir à les retaper intégralement.
- **Audit d'actions passées** sur un système, à des fins de traçabilité ou de post-mortem.
- **Recherche interactive de syntaxe** déjà utilisée (recherche floue dans l'historique).
- **Automatisation d'actions répétitives** via les raccourcis d'expansion (`!!`, `!$`, etc.).
- **Sécurisation du stockage des secrets** : maîtriser ce qui est (ou n'est pas) journalisé pour éviter la persistance de mots de passe ou tokens en clair.

---

## 2. Syntaxe de base & Raccourcis Bang (`!`)

**Syntaxe générale :**

```bash
history [options] [N]
```

**Syntaxe de rappels rapides (Bang Expansion) :**

| Raccourci | Effet |
|---|---|
| `!!` | Rejoue exactement la dernière commande (ex. `sudo !!`). |
| `!$` | Réutilise le dernier argument de la commande précédente. |
| `!*` | Réutilise tous les arguments de la commande précédente. |
| `!N` | Rejoue la N-ième ligne de l'historique (numéro absolu). |
| `!-N` | Rejoue la N-ième commande en partant de la fin. |
| `!motif` | Rejoue la dernière commande dont l'intitulé commence par *motif*. |

---

## 3. Options et fanions principaux

| Option | Description |
|---|---|
| `history N` | Affiche seulement les `N` dernières lignes de l'historique. |
| `-c`, `--clear` | Efface l'historique de la session courante (en mémoire). |
| `-d OFFSET` | Supprime la ligne située à l'index `OFFSET` de l'historique. |
| `-w` | Écrit l'historique de la session courante dans le fichier `HISTFILE`. |
| `-r` | Lit le fichier `HISTFILE` et importe son contenu dans la session courante. |
| `-a` | Ajoute immédiatement les nouvelles lignes de la session courante dans `HISTFILE` (append), sans attendre la fermeture du terminal. |

!!! tip "Astuce mémo"
    Retenir le trio `-a` (append immédiat), `-r` (relire depuis le fichier), `-w` (écrire tout dans le fichier) : c'est la base de la synchronisation multi-terminal (voir section 5).

---

## 4. Exemples pratiques & Cas d'usage concrets

### 1. Élévation de privilèges express (`sudo !!`)

Rejoue immédiatement la commande précédente, précédée de `sudo`, lorsqu'elle a échoué faute de droits :

```bash
$ apt update
Permission denied

$ sudo !!
# Exécute : sudo apt update
```

### 2. Réutilisation du dernier argument (`!$`)

Réinjecte le dernier argument de la commande précédente, pratique pour enchaîner deux actions sur la même cible :

```bash
mkdir -p /var/www/mon_projet/logs && cd !$
# cd /var/www/mon_projet/logs

cat /etc/nginx/nginx.conf
vim !$
# vim /etc/nginx/nginx.conf
```

### 3. Recherche interactive (`CTRL+R`)

Recherche dynamique et incrémentale dans l'historique, sans passer par `history` explicitement :

```text
CTRL+R          # Démarre la recherche, taper les premiers caractères de la commande recherchée
CTRL+R (répété) # Fait défiler les résultats précédents correspondant au motif
CTRL+G           # Annule la recherche et restaure la ligne de commande vide
ENTRÉE           # Exécute la commande trouvée
```

### 4. Horodatage des commandes (`HISTTIMEFORMAT`)

Configure Bash pour enregistrer et afficher la date et l'heure exactes de chaque commande de l'historique :

```bash
export HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S "

history | tail -n 5
#   42  2026-09-03 10:15:02 systemctl restart nginx
#   43  2026-09-03 10:16:47 tail -f /var/log/nginx/error.log
```

Pour rendre ce réglage permanent, l'ajouter à `~/.bashrc`.

### 5. Nettoyage/Suppression d'une ligne sensible (`history -d`)

Supprime une entrée précise de l'historique en mémoire, par exemple après avoir tapé par erreur un mot de passe en clair :

```bash
history | grep -i "password"
#   87  curl -u admin:P@ssw0rd123 https://api.example.com

history -d 87    # Supprime la ligne 87 de l'historique en mémoire
history -w       # Écrit immédiatement l'historique nettoyé dans HISTFILE
```

### 6. Contournement de la journalisation (Espace initial)

Avec `HISTCONTROL=ignorespace`, toute commande précédée d'un **espace** n'est pas enregistrée dans l'historique :

```bash
export HISTCONTROL=ignorespace

 export API_KEY="sk-xxxxxxxxxxxxxxxx"
# Cette commande (notez l'espace initial) n'apparaît PAS dans history
```

---

## 5. Astuces & Pièges à éviter

!!! tip "Variables d'environnement clés"
    Trois variables contrôlent le comportement de l'historique et méritent d'être configurées explicitement dans `~/.bashrc` :

    - **`HISTSIZE`** : nombre de lignes conservées **en mémoire** pendant la session courante.
    - **`HISTFILESIZE`** : nombre de lignes conservées dans le **fichier** `~/.bash_history` sur le disque.
    - **`HISTCONTROL`** : contrôle le filtrage des entrées, avec les valeurs combinables suivantes :
        - `ignoredups` : ignore les commandes identiques consécutives.
        - `erasedups` : supprime toutes les occurrences précédentes d'une commande dupliquée.
        - `ignorespace` : ignore les commandes préfixées par un espace (voir exemple 6).

    ```bash
    export HISTSIZE=10000
    export HISTFILESIZE=20000
    export HISTCONTROL=ignoredups:erasedups:ignorespace
    ```

!!! warning "Comportement multi-sessions / multi-terminaux"
    Par défaut, Bash n'écrit l'historique d'une session dans `HISTFILE` **qu'à la fermeture propre du terminal**. Un terminal A ouvert ne voit donc **pas** en temps réel les commandes tapées dans un terminal B — chaque session maintient son propre tampon en mémoire jusqu'à sa fermeture.

    Pour synchroniser l'historique entre plusieurs sessions ouvertes simultanément, ajouter dans `~/.bashrc` :

    ```bash
    export PROMPT_COMMAND="history -a; history -n"
    ```

    - `history -a` : ajoute immédiatement les nouvelles commandes de la session courante dans `HISTFILE`, après chaque invite.
    - `history -n` : relit les nouvelles lignes ajoutées par d'autres sessions depuis `HISTFILE`, sans dupliquer l'historique déjà chargé.

!!! danger "Sécurité et fuite de secrets"
    Saisir un mot de passe, une clé API ou un token **directement en argument** d'une commande (`curl -u user:motdepasse`, `mysql -ppassword`, `export TOKEN=xxx`) expose ce secret en clair dans `~/.bash_history`, potentiellement lisible par tout utilisateur ayant accès au fichier ou à une sauvegarde de celui-ci.

    **Bons réflexes à adopter :**

    - Utiliser `ignorespace` (voir exemple 6) pour les commandes contenant des secrets ponctuels.
    - Préférer les invites interactives masquées (`mysql -p` puis saisie masquée) plutôt que les arguments en ligne de commande.
    - Privilégier des gestionnaires de secrets (variables d'environnement chargées depuis un fichier `.env` non versionné, `pass`, `vault`, `aws-vault`) plutôt qu'une saisie manuelle répétée.
    - En cas de fuite avérée, purger la ligne concernée avec `history -d OFFSET` **et** considérer le secret comme compromis — il doit être régénéré, pas seulement effacé de l'historique.
