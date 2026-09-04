# 🛠️ Commande & Service : cron / crontab

## 1. Description rapide (Rôle et cas d'usage)

`cron` est le **démon** (service en arrière-plan) responsable de l'exécution périodique de tâches planifiées sous Linux. `crontab` (**cron** **tab**le) est l'utilitaire en ligne de commande permettant de **gérer la table de planification propre à chaque utilisateur**, sans avoir à manipuler directement les fichiers système sous-jacents.

**Principaux cas d'usage :**

- **Automatisation de sauvegardes** régulières (bases de données, fichiers, configurations).
- **Rotation et nettoyage de logs** (suppression de fichiers anciens, compression périodique).
- **Exécution de scripts de maintenance** (vérifications système, purges temporaires, health-checks).
- **Synchronisation de bases de données** ou de fichiers entre serveurs, à intervalles réguliers.
- **Persistance et tâches programmées en post-exploitation (pentest)** : `cron` est une technique classique de maintien d'accès (persistence) documentée dans le framework MITRE ATT&CK.

---

## 2. Syntaxe de la Crontab & Structure des 5 Étoiles

Chaque ligne d'une crontab est composée de **5 champs temporels**, suivis de la commande à exécuter :

```text
┌───────────── minute (0 - 59)
│ ┌─────────── heure (0 - 23)
│ │ ┌───────── jour du mois (1 - 31)
│ │ │ ┌────── mois (1 - 12)
│ │ │ │ ┌──── jour de la semaine (0 - 6) (0=Dimanche)
│ │ │ │ │
* * * * * commande_a_executer
```

**Caractères spéciaux :**

| Caractère | Signification | Exemple |
|---|---|---|
| `*` | Toutes les valeurs possibles du champ. | `* * * * *` = chaque minute |
| `,` | Liste de valeurs discrètes. | `0,15,30,45 * * * *` |
| `-` | Plage de valeurs continue. | `1-5` (lundi à vendredi) |
| `/` | Pas / intervalle de répétition. | `*/15` (toutes les 15 unités) |

**Mots-clés raccourcis (raccourcis `@`) :**

| Raccourci | Équivalent | Fréquence |
|---|---|---|
| `@reboot` | — | Exécuté une fois au démarrage du système. |
| `@hourly` | `0 * * * *` | Toutes les heures. |
| `@daily` / `@midnight` | `0 0 * * *` | Une fois par jour, à minuit. |
| `@weekly` | `0 0 * * 0` | Une fois par semaine (dimanche à minuit). |
| `@monthly` | `0 0 1 * *` | Une fois par mois (le 1er à minuit). |
| `@yearly` | `0 0 1 1 *` | Une fois par an (1er janvier à minuit). |

---

## 3. Options et fanions de la commande crontab

| Option | Description |
|---|---|
| `crontab -e` | Édite la table crontab de l'utilisateur courant (ouvre l'éditeur défini par `$EDITOR`). |
| `crontab -l` | Liste les tâches planifiées de l'utilisateur courant. |
| `crontab -r` | Supprime intégralement la table crontab courante. |
| `crontab -u USER` | Gère la crontab d'un utilisateur spécifique (nécessite les droits `sudo`/root). |
| `crontab -i` | Demande une confirmation interactive avant toute suppression avec `-r`. |

!!! tip "Astuce mémo"
    Combiner `-i` avec `-r` pour éviter une suppression accidentelle : `crontab -ir`. Sans `-i`, `crontab -r` supprime **immédiatement et sans confirmation**.

---

## 4. Exemples pratiques & Cas d'usage concrets

### 1. Sauvegarde quotidienne à heure fixe

Exécute un script tous les jours à 02h30 du matin :

```cron
30 2 * * * /scripts/backup.sh
```

### 2. Nettoyage toutes les X minutes/heures

Toutes les 15 minutes :

```cron
*/15 * * * * /scripts/verifier_espace_disque.sh
```

Toutes les 6 heures :

```cron
0 */6 * * * /scripts/rotation_logs.sh
```

### 3. Exécution au démarrage du système (`@reboot`)

Lance un agent ou un tunnel SSH persistant à chaque redémarrage du système :

```cron
@reboot /usr/local/bin/agent.sh
```

### 4. Gestion stricte de la sortie / Redirections

Redirige STDOUT et STDERR vers un fichier de log dédié, ou les supprime intégralement pour éviter tout bruit :

```cron
# Journalisation complète dans un fichier
0 3 * * * /scripts/maintenance.sh >> /var/log/maintenance.log 2>&1

# Suppression totale de toute sortie (silence complet)
*/5 * * * * /scripts/heartbeat.sh >/dev/null 2>&1
```

### 5. Définition de variables dans la crontab

Configure l'environnement d'exécution en tête de fichier, car `cron` utilise par défaut un environnement minimal (voir section 5) :

```cron
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
MAILTO="admin@domain.com"

0 4 * * * /scripts/synchro_bdd.sh
```

### 6. Planification multi-jours

Lance un script uniquement du lundi au vendredi (jours ouvrés) à 08h00 :

```cron
0 8 * * 1-5 /scripts/rapport_quotidien.sh
```

---

## 5. Emplacements système, Sécurité & Pièges à éviter

!!! tip "Fichiers et répertoires système clés"
    `cron` s'appuie sur plusieurs emplacements distincts selon la portée de la planification :

    - **`/etc/crontab`** : crontab système globale, avec un champ supplémentaire pour spécifier l'utilisateur exécutant chaque tâche.
    - **`/etc/cron.d/`** : répertoire pour des fichiers crontab additionnels, souvent déposés par des paquets logiciels tiers.
    - **`/etc/cron.daily/`**, **`/etc/cron.hourly/`**, **`/etc/cron.weekly/`**, **`/etc/cron.monthly/`** : répertoires contenant des **scripts exécutables** (et non des lignes crontab), lancés automatiquement selon leur fréquence respective par `run-parts`.
    - **`/var/spool/cron/crontabs/`** : répertoire "spool" contenant les crontabs **individuelles par utilisateur**, créées et gérées via `crontab -e` — ne jamais éditer ces fichiers directement, toujours passer par la commande `crontab`.

!!! danger "Le piège classique du $PATH restreint"
    `cron` exécute les tâches dans un environnement **minimal**, très différent d'un shell interactif de connexion. Un script qui fonctionne parfaitement en terminal peut échouer silencieusement sous `cron`, typiquement à cause d'un `$PATH` restreint ne contenant pas les répertoires attendus (`/usr/local/bin`, chemins d'environnements virtuels, etc.).

    **Solutions :**

    ```cron
    # Solution 1 : utiliser des chemins absolus pour l'interpréteur et les binaires
    0 5 * * * /usr/bin/python3 /scripts/traitement.py

    # Solution 2 : définir explicitement PATH en tête de la crontab
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    0 5 * * * traitement.py
    ```

!!! warning "Gestion des droits (cron.allow / cron.deny)"
    L'accès à `crontab` peut être restreint via deux fichiers de contrôle (généralement dans `/etc/`) :

    - **`/etc/cron.allow`** : si présent, **seuls** les utilisateurs listés peuvent utiliser `crontab`.
    - **`/etc/cron.deny`** : si `cron.allow` est absent, les utilisateurs listés dans `cron.deny` se voient **refuser** l'accès (tous les autres sont autorisés).

    En l'absence des deux fichiers, le comportement par défaut dépend de la distribution (généralement, tous les utilisateurs sont autorisés). En contexte de durcissement (hardening) ou d'audit SecOps, vérifier systématiquement l'existence et le contenu de ces fichiers.

!!! warning "Envoi de mails intempestifs"
    Par défaut, `cron` envoie un e-mail local à l'utilisateur propriétaire de la tâche à chaque exécution produisant une sortie (STDOUT ou STDERR non vide). Sur des tâches fréquentes (`*/5 * * * *`), cela peut rapidement **saturer le spool mail local** (`/var/mail/user` ou `/var/spool/mail/user`).

    **Solution :** définir `MAILTO=""` en tête de crontab pour désactiver totalement cet envoi, ou rediriger explicitement les sorties vers `/dev/null` (voir exemple 4) :

    ```cron
    MAILTO=""
    */5 * * * * /scripts/verification_frequente.sh
    ```

!!! tip "Différence avec Systemd Timers"
    Sur les distributions Linux modernes basées sur `systemd`, les **`systemd.timer`** constituent une alternative plus riche à `cron` : gestion fine des dépendances entre services, journalisation centralisée via `journalctl`, rattrapage des tâches manquées (`Persistent=true`), et granularité de configuration supérieure. `cron` reste néanmoins largement utilisé pour sa **simplicité** et sa **portabilité** entre systèmes Unix/Linux hétérogènes, y compris ceux sans `systemd`.
