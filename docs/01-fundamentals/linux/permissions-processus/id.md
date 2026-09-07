# 🛠️ Commande : id

## 1. Description rapide

`id` affiche l'**identité complète** d'un utilisateur : UID (User ID), GID principal (Group ID) et l'ensemble des GIDs secondaires. Outil fondamental d'audit de privilèges en administration système et en post-exploitation. Permet de détecter en une commande les appartenances à des groupes à hauts privilèges (`sudo`, `docker`, `wheel`, `adm`, `lxd`).

---

## 2. Syntaxe de base

```bash
id [options] [utilisateur]
```

Sans argument : affiche l'identité de l'utilisateur **courant**.  
Avec un nom d'utilisateur : affiche l'identité de **cet utilisateur** (pas besoin d'être root).

---

## 3. Options et fanions principaux

| Flag | Rôle |
| --- | --- |
| `-u` | Affiche uniquement l'UID numérique |
| `-un` | Affiche uniquement le nom d'utilisateur |
| `-g` | Affiche uniquement le GID principal numérique |
| `-gn` | Affiche uniquement le nom du groupe principal |
| `-G` | Affiche tous les GIDs secondaires (numériques) |
| `-Gn` | Affiche tous les noms des groupes secondaires |
| `-n` | Affiche les noms à la place des numéros (combiné à `-u`, `-g`, `-G`) |
| `-r` | Affiche les identifiants **réels** (pas effectifs) — utile avec SUID |
| `-Z` | Affiche le contexte SELinux |

---

## 4. Exemples pratiques & Cas d'usage

```bash
# Identité complète de l'utilisateur courant (affichage standard)
id
# uid=1001(alice) gid=1001(alice) groups=1001(alice),27(sudo),998(docker)
```

```bash
# Identité d'un utilisateur tiers sans être root
id www-data
# uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

```bash
# Extraire uniquement l'UID numérique (scriptable)
id -u
# → 1001
```

```bash
# Détecter les groupes à privilèges dangereux (audit rapide)
id | grep -Eo '(sudo|docker|wheel|adm|lxd|disk|shadow)'
# Toute sortie = vecteur d'élévation de privilèges potentiel
```

```bash
# Différence UID réel vs UID effectif dans un contexte SUID
id -u   # UID effectif (ce que voit le système pour les accès)
id -ru  # UID réel (l'utilisateur qui a lancé le processus)
# Si différents → exécution dans un contexte SUID ou sudo
```

```bash
# Lister tous les groupes d'un utilisateur en format épuré (pour les scripts)
id -Gn alice
# → alice sudo docker adm
```

---

## 5. Astuces & Pièges à éviter

!!! tip "Groupes à risque — Escalade de privilèges directe"
    La présence dans ces groupes offre une élévation de privilèges **quasi-immédiate** :

    | Groupe | Vecteur d'escalade |
    | --- | --- |
    | `sudo` | `sudo bash` ou `sudo -l` pour identifier les commandes permises |
    | `docker` | `docker run -v /:/mnt --rm -it alpine chroot /mnt sh` → root |
    | `lxd` | Montage du système hôte dans un container LXC |
    | `disk` | Accès direct aux périphériques blocs (`debugfs /dev/sda`) |
    | `shadow` | Lecture de `/etc/shadow` → crack de hashes offline |
    | `adm` | Lecture des logs système → informations sensibles |

!!! tip "id -u dans les conditions de script"
    ```bash
    if [ "$(id -u)" -ne 0 ]; then
        echo "Ce script doit être exécuté en root"
        exit 1
    fi
    ```
    Plus fiable que tester `$USER == root` car basé sur l'UID effectif réel.

!!! warning "Les groupes secondaires ne s'appliquent qu'aux nouveaux processus"
    Après avoir ajouté un utilisateur à un groupe (`usermod -aG docker alice`), le changement n'est **pas effectif dans la session courante**. L'utilisateur doit se déconnecter et se reconnecter (ou lancer `newgrp docker`) pour que le groupe apparaisse dans `id` et soit actif.

!!! warning "UID effectif vs UID réel en contexte SUID"
    Dans un binaire SUID root, `id -u` retourne `0` (root effectif) mais `id -ru` retourne l'UID de l'utilisateur qui l'a lancé. `whoami` et les permissions d'accès fichier utilisent l'UID **effectif** — c'est celui qui compte pour les accès système.
