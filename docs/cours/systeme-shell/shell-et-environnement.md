# Cheat Sheet : Shell & Environnement — Flux, variables, historique, documentation

!!! tip "Usage principal"
    Tout ce qui structure une session shell efficace : contrôle des flux I/O, variables d'environnement, productivité (historique/alias) et recherche d'aide rapide — également riche en pièges d'évasion de shells restreints.

## 1. Syntaxe de base

```bash
# Structure générale des éléments couverts
commande > fichier 2>&1 | tee -a log.txt
export VAR=valeur
history | grep motif
man commande | apropos motclé
```

---

## 2. Redirections & Flux I/O

### Rappel des descripteurs
| Descripteur | Nom | Rôle |
| --- | --- | --- |
| `0` | `stdin` | Entrée de données de la commande |
| `1` | `stdout` | Sortie standard (résultat normal) |
| `2` | `stderr` | Sortie d'erreur |

### Rediriger la sortie standard
```bash
commande > resultat.txt    # écrase le contenu du fichier
commande >> resultat.txt   # ajoute à la fin du fichier
```

### Rediriger les erreurs
```bash
commande 2> erreurs.txt   # n'envoie que stderr dans le fichier
commande 2> /dev/null     # jette les erreurs dans le "trou noir"
```

### Fusionner stdout et stderr
```bash
# 1) l'ordre compte : rediriger stdout AVANT de faire pointer stderr dessus
commande > tout.log 2>&1
```

```bash
# 2) syntaxe raccourcie équivalente, plus lisible
commande &> tout.log
```

### Rediriger l'entrée standard
```bash
# Le contenu de fichier.txt devient l'entrée de la commande
commande < fichier.txt
```

### Pipe et duplication de sortie avec `tee`
```bash
# La sortie de commande1 devient l'entrée de commande2
commande1 | commande2
```

```bash
# tee affiche à l'écran ET enregistre dans un fichier (écrase par défaut)
commande | tee sortie.txt
```

```bash
# -a ajoute à la fin du fichier au lieu de l'écraser
commande | tee -a log_cumule.txt
```

```bash
# |& fait passer stdout ET stderr dans le pipe
commande |& grep "erreur"
```

!!! warning "Pièges Redirections"
    - `commande 2>&1 > fichier` **ne fonctionne pas** comme attendu : `stderr` est dupliqué vers la destination actuelle de `stdout` (le terminal) avant que `stdout` ne soit lui-même redirigé. Toujours écrire `commande > fichier 2>&1`.
    - `>` **écrase silencieusement** le contenu existant d'un fichier sans avertissement ; `>>` ajoute à la fin. Une confusion entre les deux est une cause fréquente de perte de données (ex: écraser un fichier de config ou un log important par erreur).
    - `2> /dev/null` masque les erreurs à l'écran mais elles **ne sont stockées nulle part** : pratique en usage volontaire, mais peut cacher un vrai problème en debug.

---

## 3. Variables d'environnement

### Consulter des variables clés
```bash
echo $PATH    # dossiers où le shell cherche les exécutables
echo $USER    # utilisateur courant
echo $SHELL   # shell par défaut de l'utilisateur
echo $PWD     # répertoire de travail courant
```

### Lister toutes les variables
```bash
# Affiche l'intégralité des variables d'environnement de la session
env
```

### Créer / modifier une variable
```bash
# Disponible pour la session courante et ses sous-processus
export API_KEY=abcd1234
```

### Supprimer une variable
```bash
# Retire la variable de l'environnement courant
unset API_KEY
```

### Modifier l'environnement pour une seule commande
```bash
# La variable n'existe que le temps de cette commande, sans affecter la session
MODE=debug commande
```

```bash
# Exécuter avec un environnement totalement vidé (dépannage isolé)
env -i bash
```

## Synthèse — Tableau des commandes

| Commande | Rôle | Exemple |
| --- | --- | --- |
| `echo $VAR` | Affiche une variable | `echo $HOME` |
| `env` | Liste toutes les variables | `env` |
| `export VAR=val` | Crée/modifie une variable, visible des sous-processus | `export EDITOR=vim` |
| `unset VAR` | Supprime une variable | `unset API_KEY` |
| `VAR=val cmd` | Variable temporaire pour une seule commande | `DEBUG=1 script.sh` |

!!! warning "Piège Variables"
    Une variable `export`ée est **temporaire** : elle disparaît à la fermeture du terminal. Pour la rendre persistante, il faut l'ajouter au fichier de config du shell (`~/.bashrc`) puis recharger avec `source ~/.bashrc`. Par ailleurs, un `PATH` modifiable en tête de liste (ex: `.:/usr/bin`) est une faille classique d'escalade de privilèges.

---

## 4. Navigation & Productivité Shell

### Historique des commandes
```bash
history          # liste tout l'historique avec numéros
!!                # exécute la dernière commande
!102              # exécute la commande numéro 102
!cat              # exécute la dernière commande commençant par "cat"
```

```bash
# CTRL+R : recherche interactive inversée dans l'historique
# retaper CTRL+R affiche des résultats plus anciens ; Entrée exécute, flèches pour éditer
```

```bash
# Effacer l'historique de la session courante
history -c
```

### Alias : raccourcis de commandes
```bash
alias ll='ls -la'          # création temporaire (session courante)
alias                       # liste tous les alias actifs
unalias ll                  # suppression temporaire
```

```bash
# Rendre un alias permanent : ajouter au fichier de config puis recharger
echo "alias ll='ls -la'" >> ~/.bashrc
source ~/.bashrc
```

```bash
# Contourner un alias pour exécuter la vraie commande sous-jacente
\ls -la
```

### Fermer une session
```bash
exit       # ferme le shell courant (fonctionne partout)
exit 1     # ferme en signalant un code d'erreur
logout     # ferme une session de connexion (login shell uniquement)
```

## Synthèse — Tableau des commandes

| Commande | Rôle | Exemple |
| --- | --- | --- |
| `!!` | Rejoue la dernière commande | `sudo !!` |
| `!N` | Rejoue la commande numéro N | `!45` |
| `CTRL+R` | Recherche interactive dans l'historique | `CTRL+R` puis un motif |
| `history -c` | Efface l'historique de la session | `history -c` |
| `history -w` | Sauvegarde l'historique dans un fichier | `history -w` |
| `\commande` | Exécute la commande réelle en ignorant tout alias du même nom | `\rm fichier` |
| `type commande` | Vérifie si un nom est un alias, une fonction ou un binaire | `type ll` |

!!! warning "Pièges Historique & Alias"
    - `history -c` efface l'historique **en mémoire de la session courante**, mais pas forcément le fichier `~/.bash_history` déjà écrit sur disque : un attaquant (ou un audit) peut toujours le retrouver après coup.
    - Un alias malveillant peut **masquer une commande système** (ex: `alias ls='rm -rf ~'` dans un `.bashrc` compromis) : en cas de doute sur une commande, vérifiez avec `type commande`, ou forcez la commande réelle avec le préfixe `\`.
    - L'historique contient souvent des **secrets tapés en clair** (mots de passe en argument, tokens) : ne jamais taper de secret directement en ligne de commande.

---

## 5. Recherche d'aide & Documentation

### Manuel complet (`man`)
```bash
man chmod         # ouvre la page de manuel de chmod
man 5 passwd      # force la section 5 (format de fichier) en cas d'ambiguïté
```

Sections clés du manuel :

| Section | Contenu |
| --- | --- |
| `1` | Commandes utilisateur |
| `5` | Formats de fichiers |
| `8` | Commandes d'administration système |

Navigation dans `man` : `/motif` (recherche avant), `n`/`N` (occurrence suivante/précédente), `q` (quitter).

### Recherche par mot-clé
```bash
apropos copy      # cherche "copy" dans toutes les descriptions courtes du man
man -k copy       # strictement équivalent à apropos
```

### Description ultra-courte
```bash
# Une seule ligne de résumé, sans ouvrir le manuel complet
whatis ls
```

### Aide rapide selon le type de commande
```bash
help cd           # pour les built-ins du shell (cd, export, alias...)
grep --help       # pour les exécutables externes
```

## Synthèse — Tableau des commandes

| Commande | Rôle | Exemple |
| --- | --- | --- |
| `man cmd` | Manuel complet | `man find` |
| `apropos motclé` / `man -k motclé` | Recherche par mot-clé dans les descriptions | `apropos encrypt` |
| `whatis cmd` | Description en une ligne | `whatis chmod` |
| `help cmd` | Aide pour une built-in Bash | `help export` |
| `cmd --help` | Aide rapide pour un exécutable | `chmod --help` |

!!! warning "Piège majeur : évasion de shell restreint via man/less"
    `man` et `less` (son pager par défaut) permettent d'invoquer un **shell externe** depuis leur interface, ce qui constitue une technique connue d'évasion de shells restreints ou de comptes à privilèges limités : depuis `man` ou `less`, la commande `!bash` (ou `!sh`) ouvre un shell interactif hérité des droits du processus en cours. Sur un système où l'accès `man`/`less` est autorisé mais le shell est censé être restreint, cela permet de retrouver un accès shell complet. En administration, restreindre l'accès à `man`/`less`/`vim` sur les comptes à privilèges limités est aussi important que restreindre `sudo -l`.
