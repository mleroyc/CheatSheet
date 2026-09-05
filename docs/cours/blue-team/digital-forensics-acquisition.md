# Digital Forensics — Acquisition

## 1. Ordre de Volatilité (RFC 3227)

| Ordre | Source | Volatilité |
|---|---|---|
| 1 | Registres CPU, cache | Secondes |
| 2 | Table de routage, cache ARP, table de process, kernel stats | Secondes → minutes |
| 3 | Mémoire RAM | Minutes |
| 4 | Systèmes de fichiers temporaires (`/tmp`, swap) | Minutes → heures |
| 5 | Disque dur / SSD | Heures → jours |
| 6 | Logs distants / journaux de supervision | Jours → mois |
| 7 | Topologie physique, câblage réseau | Stable |
| 8 | Support d'archivage (bande, sauvegarde offline) | Années |

!!! warning "Règle d'or"
    Toujours acquérir du plus volatile vers le moins volatile. Une acquisition disque avant RAM fait perdre des preuves irremplaçables.

!!! note "Chaîne de traçabilité (Chain of Custody)"
    Pour chaque preuve, documenter :

    - Qui a collecté (nom, matricule)
    - Quand (date/heure UTC précise)
    - Où (localisation physique, n° de poste)
    - Comment (outil, version, ligne de commande exacte)
    - Hash immédiat après acquisition (MD5 **et** SHA256)
    - Chaque transfert de main (signature + horodatage)

!!! danger "Préservation des preuves"
    - Ne **jamais** travailler sur le média original : cloner puis analyser la copie.
    - Isoler la machine (mode avion / débrancher réseau) **sauf** si l'acquisition RAM ou une analyse live est en cours.
    - Utiliser un support de destination **stérile** (wipé et vérifié avant usage).
    - Photographier l'état physique de la scène (écran, câblage, ports USB) avant toute manipulation.

---

## 2. Acquisition de la Mémoire RAM

### WinPmem (Windows)

```powershell
# Acquisition simple
winpmem_mini_x64_rc2.exe C:\evidence\ram_capture.raw

# Avec format AFF4 (recommandé, inclut métadonnées + hash)
winpmem_mini_x64_rc2.exe -o C:\evidence\ram_capture.aff4

# Vérification du format de sortie
winpmem_mini_x64_rc2.exe --format raw C:\evidence\ram_capture.raw
```

### LiME (Linux Memory Extractor)

```bash
# Compilation du module (depuis les sources du kernel cible)
cd LiME/src
make

# Chargement du module et dump vers fichier local
sudo insmod lime-$(uname -r).ko "path=/mnt/evidence/ram_capture.lime format=lime"

# Dump vers un hôte distant via TCP (évite d'écrire sur le disque local suspect)
sudo insmod lime.ko "path=tcp:4444 format=lime"
# Côté récepteur :
nc -l -p 4444 > ram_capture.lime

# Déchargement du module après capture
sudo rmmod lime
```

### FTK Imager — GUI

```
File > Capture Memory...
  → Destination path : sélectionner support externe
  → Cocher "Include pagefile"
  → Cocher "Create AD1 file" (optionnel, image logique associée)
  → Capture Memory
```

### FTK Imager — CLI (`ftkimager`)

```bash
# FTK Imager CLI ne capture pas la RAM directement (fonction GUI uniquement)
# Utiliser ftkimager pour l'acquisition disque (voir section 3)
```

### DumpIt (Windows, portable)

```cmd
:: Exécution simple (double-clic ou CLI), génère un .DMP horodaté
DumpIt.exe /Q /O C:\evidence\ram_dumpit.dmp

:: /Q = mode silencieux, pas de confirmation
:: /O = chemin de sortie
```

!!! tip "Ordre de priorité RAM"
    1. Outil natif au format le plus riche (AFF4 / LiME) si le temps le permet.
    2. Format RAW en cas d'urgence — universellement compatible avec Volatility/Rekall.
    3. Toujours capturer vers un support externe, **jamais** sur le disque système à analyser.

---

## 3. Acquisition de Disque & Image Forensics

### Formats d'image

| Format | Extension | Compression | Métadonnées intégrées | Usage typique |
|---|---|---|---|---|
| RAW (dd) | `.raw` / `.img` / `.dd` | Non | Non | Universel, compatible tous outils |
| E01 (EWF) | `.E01` | Oui (optionnelle) | Oui (hash, case info) | Standard légal (EnCase/FTK) |
| AFF / AFF4 | `.aff` / `.aff4` | Oui | Oui (extensible) | Open source, RAM + disque |

### `dd` (basique, sans vérification)

```bash
# Identifier le disque source
lsblk
sudo fdisk -l

# Acquisition brute avec bloc de 4M et log de progression
sudo dd if=/dev/sdb of=/mnt/evidence/disk.raw bs=4M conv=noerror,sync status=progress
```

### `dcfldd` (dd forensique, hash à la volée)

```bash
sudo dcfldd if=/dev/sdb of=/mnt/evidence/disk.raw \
  bs=4M hash=md5,sha256 \
  hashlog=/mnt/evidence/disk_hash.log \
  hashwindow=1G \
  hashconv=after \
  conv=noerror,sync \
  statusinterval=10
```

### `ftkimager` — Linux CLI

```bash
# Image RAW simple avec vérification intégrée
sudo ftkimager /dev/sdb /mnt/evidence/disk_image \
  --e01 \
  --case-number "2026-001" \
  --evidence-number "DISK-01" \
  --examiner "Nom Prenom" \
  --description "Poste utilisateur X" \
  --compress 6 \
  --verify

# Format RAW (dd-style) sans compression
sudo ftkimager /dev/sdb /mnt/evidence/disk_image --dd --verify
```

### `ftkimager` — Windows CLI

```cmd
ftkimager.exe \\.\PhysicalDrive1 D:\evidence\disk_image --e01 ^
  --case-number "2026-001" --evidence-number "DISK-01" ^
  --examiner "Nom Prenom" --compress 6 --verify
```

!!! warning "Secteurs défectueux"
    Toujours utiliser `conv=noerror,sync` (dd/dcfldd) pour continuer l'acquisition malgré des erreurs de lecture, en comblant les secteurs illisibles par des zéros afin de préserver l'alignement des offsets.

---

## 4. Intégrité & Validation des Hashs

### Linux — `sha256sum` / `md5sum`

```bash
# Génération
sha256sum /mnt/evidence/disk.raw > disk.raw.sha256
md5sum /mnt/evidence/disk.raw > disk.raw.md5

# Vérification
sha256sum -c disk.raw.sha256
# Sortie attendue : disk.raw: OK
```

### PowerShell — `Get-FileHash`

```powershell
# Génération SHA256
Get-FileHash -Path C:\evidence\disk_image.E01 -Algorithm SHA256 |
    Tee-Object -FilePath C:\evidence\disk_image.sha256

# Génération MD5
Get-FileHash -Path C:\evidence\disk_image.E01 -Algorithm MD5

# Vérification par comparaison
$original = "A1B2C3..."
$current  = (Get-FileHash -Path C:\evidence\disk_image.E01 -Algorithm SHA256).Hash
if ($current -eq $original) { "MATCH" } else { "MISMATCH — INTEGRITE COMPROMISE" }
```

!!! danger "Double hashing obligatoire"
    Toujours calculer **avant** (sur le média source si possible) **et après** acquisition. Consigner les deux valeurs dans le rapport. Un seul mismatch invalide juridiquement la preuve.

| Algorithme | Usage recommandé |
|---|---|
| MD5 | Rapide, legacy, collisions possibles — jamais seul en preuve légale |
| SHA256 | Standard actuel, à utiliser systématiquement en preuve principale |
| SHA1 | Déprécié, éviter sauf compatibilité outil ancien |

---

## 5. Écriture Sécurisée & Write-Blockers

### Matériel

| Type | Exemple | Interface |
|---|---|---|
| Bridge USB | Tableau Forensic USB Bridge | USB → USB |
| Bridge SATA/IDE | Tableau T35689iu | SATA/IDE → USB |
| Bridge NVMe | CRU WiebeTech Forensic UltraDock | NVMe/SATA → USB/eSATA |

!!! note "Principe"
    Le write-blocker intercepte toute commande d'écriture entre l'hôte et le média source et la rejette au niveau matériel, indépendamment de l'OS utilisé.

### Logiciel — Windows (registre)

```powershell
# Activer la protection en écriture USB (clé StorageDevicePolicies)
New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\StorageDevicePolicies" -Force
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\StorageDevicePolicies" `
    -Name "WriteProtect" -Value 1 -PropertyType DWORD -Force

# Vérification
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\StorageDevicePolicies"

# Désactivation (après acquisition terminée)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\StorageDevicePolicies" -Name "WriteProtect" -Value 0
```

### Logiciel — Linux

```bash
# Monter en lecture seule explicite
sudo mount -o ro,noload /dev/sdb1 /mnt/analyse

# Forcer le mode lecture seule au niveau bloc (protection renforcée)
sudo blockdev --setro /dev/sdb
blockdev --getro /dev/sdb   # doit retourner 1

# Vérifier qu'aucun montage en écriture n'existe
mount | grep /dev/sdb
```

!!! danger "Piège fréquent"
    `mount -o ro` seul n'empêche pas des écritures directes sur le périphérique bloc (`dd of=/dev/sdb`). Toujours combiner avec `blockdev --setro` ou un bloqueur matériel physique pour une garantie complète.

!!! tip "Checklist rapide avant toute acquisition"
    - [ ] Write-blocker matériel en place et vérifié
    - [ ] Support de destination stérile et vérifié (wipe + hash à blanc)
    - [ ] Hash pré-acquisition documenté (si source accessible)
    - [ ] Acquisition RAM effectuée avant coupure d'alimentation
    - [ ] Hash post-acquisition calculé et comparé
    - [ ] Chaîne de traçabilité renseignée et signée
