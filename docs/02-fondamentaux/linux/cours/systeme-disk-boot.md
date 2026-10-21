# Cheat Sheet : Système Linux — Boot, Disques & Processus

!!! tip "Usage principal"
    Comprendre et inspecter le cycle de vie complet d'un système Linux : démarrage, matériel, systèmes de fichiers et processus — essentiel en administration comme en forensic/pentest.

---

## 1. Processus de Démarrage (Boot Sequence)

### Les grandes étapes
```bash
# Ordre chronologique du boot, à connaître par cœur :
# BIOS/UEFI -> MBR/GPT -> Bootloader GRUB2 -> Noyau + Initrd -> Systemd (PID 1) -> Cibles (targets)
```

| Étape | Rôle |
| --- | --- |
| BIOS / UEFI | Firmware initial, POST matériel, sélectionne le disque de boot |
| MBR / GPT | Table de partitions + code de démarrage (secteur de boot) |
| GRUB2 | Bootloader : charge le noyau Linux choisi et son initrd |
| Noyau + Initrd | Noyau Linux démarré avec une image RAM temporaire (pilotes essentiels) |
| Systemd (PID 1) | Premier processus utilisateur, orchestre le reste du démarrage (services, cibles) |

### Inspecter le démarrage
```bash
# Affiche les messages du noyau depuis le dernier boot (pilotes, matériel détecté)
dmesg
```

```bash
# Journal complet du démarrage actuel (-b) via systemd
journalctl -b
```

```bash
# Journal du boot précédent (utile après un crash)
journalctl -b -1
```

### Gestion des modules du noyau
```bash
lsmod                # liste les modules noyau actuellement chargés
modprobe nom_module  # charge un module (résout aussi ses dépendances)
modprobe -r nom_module  # décharge un module (et ses dépendances si inutilisées)
insmod module.ko     # charge un module directement depuis un fichier .ko (sans gestion de dépendances)
rmmod nom_module     # décharge un module (échoue si encore utilisé)
```

!!! note "modprobe vs insmod/rmmod"
    `modprobe` résout automatiquement les dépendances entre modules — à privilégier en usage courant. `insmod`/`rmmod` travaillent sans gestion de dépendances, utiles pour du dépannage fin.

---

## 2. Gestion des Périphériques & Matériel (Devices)

### Inspection du matériel
```bash
lsusb          # liste les périphériques USB connectés
lspci          # liste les périphériques PCI (cartes réseau, GPU, contrôleurs...)
lsscsi         # liste les périphériques de stockage SCSI/SATA
lsblk          # liste les périphériques blocs (disques, partitions) en arborescence
fdisk -l       # liste détaillée des disques et de leurs tables de partitions
```

### Copie bloc et manipulation de disques avec `dd`
```bash
# Sauvegarde du MBR (512 premiers octets) avant toute manipulation risquée
dd if=/dev/sda of=mbr_backup.img bs=512 count=1
```

```bash
# Restauration du MBR depuis une sauvegarde
dd if=mbr_backup.img of=/dev/sda bs=512 count=1
```

```bash
# Création d'une image complète d'un disque (forensic, clonage)
dd if=/dev/sdb of=disque_complet.img bs=4M status=progress
```

```bash
# Effacement sécurisé d'un disque (zeroing) avant réutilisation/destruction
dd if=/dev/zero of=/dev/sdb bs=4M status=progress
```

### Rôle de `/dev`, `/sys` et `udev`
| Répertoire / Outil | Rôle |
| --- | --- |
| `/dev` | Fichiers spéciaux représentant les périphériques (disques, terminaux, null...) |
| `/sys` | Interface virtuelle exposant l'état du noyau et du matériel (pilotes, devices) |
| `udev` | Démon qui crée/supprime dynamiquement les entrées `/dev` selon les événements matériel (règles dans `/etc/udev/rules.d/`) |

!!! warning "Manipulation destructive avec `dd`"
    `dd` ne demande **aucune confirmation** et écrit directement sur le périphérique cible : inverser `if=` (source) et `of=` (destination), ou cibler le mauvais disque (`/dev/sda` au lieu de `/dev/sdb`), **détruit irréversiblement des données**. Toujours vérifier deux fois la sortie de `lsblk` avant d'exécuter une commande `dd` destructive.

---

## 3. Systèmes de Fichiers, Disk Anatomy & Inodes

### Concepts fondamentaux
| Concept | Définition |
| --- | --- |
| Inode | Structure stockant les métadonnées d'un fichier (permissions, propriétaire, taille, pointeurs vers les blocs) — pas le nom |
| Bloc | Unité de stockage physique où sont écrites les données réelles du fichier |
| Superblock | Métadonnées du système de fichiers lui-même (taille, état, nombre d'inodes libres) |
| Hard link | Second nom pointant vers le **même inode** : suppression de l'original n'efface pas les données tant qu'un lien existe |
| Symlink | Fichier séparé (inode propre) qui **pointe vers un chemin** : cassé si la cible est supprimée |

```bash
ln fichier.txt lien_dur       # crée un hard link (même inode)
ln -s fichier.txt lien_sym    # crée un lien symbolique (chemin vers le fichier)
```

### Analyse d'espace disque et d'inodes
```bash
df -h       # espace disque utilisé/disponible par partition, lisible (Go/Mo)
df -i       # nombre d'inodes utilisés/disponibles par partition
du -sh *    # taille de chaque fichier/dossier du répertoire courant
ncdu        # explorateur d'espace disque interactif (alternative conviviale à du)
```

!!! note "Disque plein malgré `df -h` OK"
    Erreur "No space left on device" avec espace libre visible ? Vérifiez `df -i` : les **inodes** peuvent être épuisés (souvent causé par des millions de petits fichiers).

### Types de systèmes de fichiers courants
| Type | Particularité |
| --- | --- |
| `ext4` | Système de fichiers Linux standard, journalisé, très répandu |
| `xfs` | Journalisé, performant sur gros volumes et fichiers volumineux |
| `btrfs` | Snapshots natifs, sous-volumes, vérification d'intégrité intégrée |
| `vfat` / `exfat` | Compatibilité Windows/multi-OS, sans permissions Unix natives |

### Création, réparation et montage
```bash
mkfs.ext4 /dev/sdb1    # formate une partition en ext4
mkfs.xfs /dev/sdb1     # formate une partition en xfs
```

```bash
fsck /dev/sdb1         # vérifie et répare un système de fichiers (à froid, démonté)
e2fsck -f /dev/sdb1    # vérification forcée spécifique aux systèmes ext
```

```bash
mount /dev/sdb1 /mnt/data   # monte une partition sur un point de montage
umount /mnt/data            # démonte proprement une partition
```

### Configuration permanente via `/etc/fstab`
```bash
# Format : <périphérique/UUID> <point de montage> <type FS> <options> <dump> <fsck order>
UUID=1234-5678  /data  ext4  defaults  0  2
```

| Champ | Rôle |
| --- | --- |
| Périphérique / UUID | Identifie la partition (UUID recommandé, stable même si `/dev/sdX` change) |
| Point de montage | Répertoire où la partition sera accessible |
| Type FS | `ext4`, `xfs`, `swap`... |
| Options | `defaults`, `ro` (lecture seule), `noexec`, `nosuid`... |
| Dump | Sauvegarde par `dump` (0 = désactivé, quasi toujours 0 aujourd'hui) |
| Fsck order | Ordre de vérification au boot (0 = jamais, 1 = racine, 2 = autres partitions) |

### Gestion du Swap
```bash
mkswap /dev/sdb2   # prépare une partition comme espace de swap
swapon /dev/sdb2   # active le swap
swapoff /dev/sdb2  # désactive le swap
```

!!! warning "fsck et mkfs sont destructifs par nature"
    `mkfs.*` **efface toutes les données** de la partition ciblée en la reformatant. `fsck` doit toujours être exécuté sur un système de fichiers **démonté** (sauf lecture seule) : lancé sur une partition montée en écriture, il peut corrompre davantage les données au lieu de les réparer.

---

## 4. Gestion des Processus & Noyau

### Inspection des processus
```bash
ps aux       # tous les processus, format BSD (utilisateur, %CPU, %MEM...)
ps -ef       # tous les processus, format Unix standard (PPID visible)
top          # vue dynamique temps réel des processus
htop         # équivalent interactif et plus lisible de top
pstree       # affiche les processus sous forme d'arborescence parent/enfant
```

### Terminer des processus
```bash
kill PID           # envoie SIGTERM (15, arrêt propre demandé) au PID donné
kill -9 PID        # envoie SIGKILL (9, arrêt immédiat et forcé, non interceptable)
pkill nom_process  # termine tous les processus correspondant au nom
killall nom_process # équivalent de pkill, cible par nom exact
```

### Signaux `kill` courants
| Signal | Numéro | Rôle |
| --- | --- | --- |
| `SIGHUP` | 1 | Redémarrage/rechargement de config (souvent utilisé par les daemons) |
| `SIGINT` | 2 | Interruption (équivalent `CTRL+C`) |
| `SIGKILL` | 9 | Arrêt immédiat et forcé, non interceptable ni ignorable |
| `SIGTERM` | 15 | Demande d'arrêt propre (défaut de `kill`), interceptable par le processus |
| `SIGSTOP` | 19 | Suspend le processus (non interceptable) |
| `SIGCONT` | 18 | Reprend un processus suspendu |

### États des processus
| État | Symbole | Signification |
| --- | --- | --- |
| Running | `R` | En cours d'exécution ou prêt à s'exécuter |
| Sleeping | `S` | En attente d'un événement (interruptible) |
| Disk sleep | `D` | En attente d'E/S disque (non interruptible) |
| Zombie | `Z` | Terminé mais dont le parent n'a pas encore récupéré le code de sortie |
| Stopped | `T` | Suspendu (via `SIGSTOP` ou `CTRL+Z`) |

### Priorités des processus
```bash
nice -n 10 commande     # lance une commande avec une priorité plus basse (10, plage -20 à 19)
renice -n -5 -p PID     # change la priorité d'un processus déjà lancé (nécessite root pour descendre sous 0)
```

!!! note "Zombie ≠ processus bloqué"
    Un `Z` ne consomme ni CPU ni mémoire significative : il ne reste que son entrée en attente que le parent lise son code de sortie. Beaucoup de zombies = bug côté parent, pas une charge système réelle.

### Niveaux de privilèges et appels système
```bash
# Ring 0 (mode noyau, accès matériel total) vs Ring 3 (mode utilisateur, accès restreint via appels système)
strace commande     # trace tous les appels système effectués par une commande
ltrace commande     # trace les appels aux fonctions de bibliothèques partagées
```

!!! tip "strace en dépannage et en pentest"
    `strace -f -e trace=open,openat commande` isole rapidement les tentatives d'accès fichier d'un programme qui échoue silencieusement. Utile aussi en pentest pour identifier les fichiers/configs réellement chargés par un binaire SUID.
