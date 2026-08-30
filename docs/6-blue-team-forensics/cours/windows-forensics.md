# Windows Forensics — Artefacts

## 1. Artefacts d'Exécution de Fichiers

| Artefact | Chemin | Preuve apportée | Outil d'extraction (EZ Tools) |
|---|---|---|---|
| Prefetch | `C:\Windows\Prefetch\*.pf` | Exécution d'un binaire, nb. d'exécutions, timestamps, fichiers chargés | `PECmd.exe` |
| Shimcache (AppCompatCache) | `SYSTEM` hive → `ControlSet00X\Control\Session Manager\AppCompatCache` | Présence d'un fichier exécutable sur le disque (pas forcément exécuté) | `AppCompatCacheParser.exe` |
| Amcache | `C:\Windows\AppCompat\Programs\Amcache.hve` | Métadonnées riches (SHA1, chemin, date install, PE compile time) | `AmcacheParser.exe` |
| UserAssist | `NTUSER.DAT` → `Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist\{GUID}\Count` (valeurs ROT13) | Exécution GUI, compteur, dernier lancement | `RECmd.exe` (map `UserAssist.reb`) |
| BAM / DAM | `SYSTEM` hive → `ControlSet00X\Services\bam\State\UserSettings\{SID}` | Dernière exécution d'un programme par utilisateur (précision горaire) | `RECmd.exe` (map `BAM_DAM.reb`) |

```powershell
# Prefetch
PECmd.exe -d "C:\Windows\Prefetch" --csv "C:\out\prefetch"

# Shimcache
AppCompatCacheParser.exe -f "C:\evidence\SYSTEM" --csv "C:\out\shimcache"

# Amcache
AmcacheParser.exe -f "C:\evidence\Amcache.hve" --csv "C:\out\amcache" -i

# UserAssist (via RECmd batch)
RECmd.exe -f "C:\evidence\NTUSER.DAT" --bn "BatchExamples\UserAssist.reb" --csv "C:\out\userassist"

# BAM/DAM (via RECmd batch)
RECmd.exe -f "C:\evidence\SYSTEM" --bn "BatchExamples\BAM_DAM.reb" --csv "C:\out\bam"
```

!!! note "Prefetch désactivé sur SSD"
    Windows désactive parfois Prefetch sur les systèmes équipés d'un SSD (selon la version d'OS). Vérifier `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters\EnablePrefetcher`.

---

## 2. Artefacts du Système de Fichiers

| Artefact | Emplacement | Contenu |
|---|---|---|
| MFT | `C:\$MFT` | Table de tous les fichiers/dossiers NTFS, timestamps (SI & FN), taille, résident/non-résident |
| $LogFile | `C:\$LogFile` | Journal de transactions NTFS (opérations récentes sur fichiers) |
| $UsnJrnl | `C:\$Extend\$UsnJrnl:$J` | Journal des changements (création, suppression, renommage, écriture) |
| ADS | Tout fichier NTFS (`fichier.txt:stream`) | Flux de données caché associé à un fichier légitime |

```powershell
# Extraction MFT (nécessite accès brut, via FTK Imager ou raw copy)
MFTECmd.exe -f "C:\evidence\$MFT" --csv "C:\out\mft" --csvf mft_output.csv

# Extraction $LogFile
MFTECmd.exe -f "C:\evidence\$LogFile" --csv "C:\out\logfile" --csvf logfile_output.csv

# Extraction $UsnJrnl (fichier $J extrait au préalable)
MFTECmd.exe -f "C:\evidence\$J" --csv "C:\out\usnjrnl" --csvf usn_output.csv
```

```cmd
:: Détection d'ADS (natif Windows)
dir /r C:\suspect_folder

:: Détection via PowerShell
Get-Item -Path "C:\suspect_folder\*" -Stream * | Where-Object Stream -ne ':$DATA'

:: Lecture d'un ADS spécifique
Get-Content -Path "C:\suspect_folder\fichier.txt" -Stream "hidden_stream"
```

!!! warning "MFT timestamps"
    Chaque entrée MFT possède deux jeux de timestamps : `$STANDARD_INFORMATION` (modifiable par API, souvent altéré par les attaquants) et `$FILE_NAME` (plus difficile à falsifier). Toujours comparer les deux pour détecter un **timestomping**.

---

## 3. Artefacts du Registre Windows

| Ruche | Chemin disque | Contenu clé |
|---|---|---|
| SAM | `C:\Windows\System32\config\SAM` | Comptes locaux, hashs NTLM |
| SYSTEM | `C:\Windows\System32\config\SYSTEM` | Services, config réseau, BAM/DAM, Shimcache, USB |
| SOFTWARE | `C:\Windows\System32\config\SOFTWARE` | Logiciels installés, config OS, Run keys machine |
| NTUSER.DAT | `C:\Users\<user>\NTUSER.DAT` | Préférences utilisateur, MRU, UserAssist, Run keys user |
| USRCLASS.DAT | `C:\Users\<user>\AppData\Local\Microsoft\Windows\USRCLASS.DAT` | Shellbags |

### Clés d'autostart (persistance)

```text
HKLM\Software\Microsoft\Windows\CurrentVersion\Run
HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce
HKCU\Software\Microsoft\Windows\CurrentVersion\Run
HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce
HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders
HKLM\System\CurrentControlSet\Services  (services suspects)
```

### MRU (Most Recently Used)

```text
NTUSER.DAT\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU
NTUSER.DAT\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU
NTUSER.DAT\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\LastVisitedPidlMRU
NTUSER.DAT\Software\Microsoft\Office\<version>\<App>\File MRU
```

### Périphériques USB

```text
SYSTEM\CurrentControlSet\Enum\USBSTOR          → VID/PID, numéro de série, 1ère/dernière connexion
SYSTEM\CurrentControlSet\Enum\USB               → détails device
SOFTWARE\Microsoft\Windows Portable Devices\Devices → nom convivial du volume
NTUSER.DAT\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2 → lettre de lecteur montée par user
```

```powershell
# Extraction automatisée toutes ruches avec RECmd (règles prédéfinies)
RECmd.exe -f "C:\evidence\SYSTEM" --bn "BatchExamples\Kroll_Batch.reb" --csv "C:\out\registry"
RECmd.exe -f "C:\evidence\NTUSER.DAT" --bn "BatchExamples\Kroll_Batch.reb" --csv "C:\out\registry"

# Extraction USB via RECmd
RECmd.exe -f "C:\evidence\SYSTEM" --bn "BatchExamples\USB_Devices.reb" --csv "C:\out\usb"
```

!!! danger "Copie des ruches à froid"
    Les ruches sont verrouillées par l'OS pendant qu'il tourne. Utiliser un outil d'export à froid (`reg save`) ou copier depuis une image montée hors-ligne :
    ```cmd
    reg save HKLM\SAM C:\evidence\SAM
    reg save HKLM\SYSTEM C:\evidence\SYSTEM
    reg save HKLM\SOFTWARE C:\evidence\SOFTWARE
    ```

---

## 4. Artefacts Navigation & Activités Utilisateur

| Artefact | Chemin | Contenu |
|---|---|---|
| Jump Lists (AutomaticDestinations) | `C:\Users\<user>\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations\*.automaticDestinations-ms` | Fichiers/apps récemment accédés, épinglés |
| Jump Lists (CustomDestinations) | `...\Recent\CustomDestinations\*.customDestinations-ms` | Items épinglés manuellement |
| Shellbags | `USRCLASS.DAT` (`Local Settings\Software\...\Shell\Bags`) + `NTUSER.DAT` | Historique de navigation dans l'Explorateur (dossiers vus, même supprimés) |
| Corbeille | `C:\$Recycle.Bin\<SID>\$Ixxxxxx` (métadonnées) et `$Rxxxxxx` (contenu) | Fichier supprimé, chemin d'origine, date suppression |
| Chrome/Edge | `C:\Users\<user>\AppData\Local\{Google\Chrome|Microsoft\Edge}\User Data\Default\History` (SQLite) | Historique, téléchargements, mots-clés recherchés |
| Firefox | `C:\Users\<user>\AppData\Roaming\Mozilla\Firefox\Profiles\<profile>\places.sqlite` | Historique, favoris, téléchargements |

```powershell
# Jump Lists
JLECmd.exe -d "C:\Users\<user>\AppData\Roaming\Microsoft\Windows\Recent" --csv "C:\out\jumplists"

# Shellbags
SBECmd.exe -d "C:\evidence" --csv "C:\out\shellbags"
# (nécessite NTUSER.DAT + USRCLASS.DAT dans le même dossier)

# Corbeille
RBCmd.exe -d "C:\evidence\$Recycle.Bin" --csv "C:\out\recyclebin"

# Historique navigateur (SQLite, hors ligne — copier le fichier avant, DB verrouillée si navigateur ouvert)
Copy-Item "C:\Users\<user>\AppData\Local\Google\Chrome\User Data\Default\History" -Destination "C:\evidence\chrome_history.sqlite"
```

```bash
# Lecture SQLite Chrome (Linux/analyse)
sqlite3 chrome_history.sqlite "SELECT url, title, datetime(last_visit_time/1000000-11644473600,'unixepoch') FROM urls ORDER BY last_visit_time DESC;"
```

!!! tip "Shellbags = preuve de dossiers supprimés"
    Les Shellbags conservent la trace de dossiers/volumes même après suppression du disque ou éjection d'un support amovible — précieux pour prouver l'existence passée d'un chemin.

---

## 5. Outils CLI & Scripts d'Extraction Rapide

### KAPE (Kroll Artifact Parser and Extractor)

```cmd
:: Collecte ciblée (Targets) + traitement automatique (Modules)
kape.exe --tsource C: --tdest C:\out\triage --target KapeTriage ^
         --mdest C:\out\processed --module !EZParser

:: Collecte uniquement (sans parsing), utile en réponse à incident rapide
kape.exe --tsource C: --tdest E:\triage --target !SANS_Triage

:: Lister les targets disponibles
kape.exe --tlist

:: Lister les modules disponibles
kape.exe --mlist
```

### MFTECmd

```powershell
MFTECmd.exe -f "C:\evidence\$MFT" --csv "C:\out" --csvf mft.csv --at
# --at : inclut les timestamps ADS
```

### PECmd

```powershell
PECmd.exe -f "C:\Windows\Prefetch\NOTEPAD.EXE-A1B2C3D4.pf"
PECmd.exe -d "C:\Windows\Prefetch" --csv "C:\out" -q
```

### RECmd

```powershell
# Mode batch (recommandé, applique un ensemble de règles connues)
RECmd.exe --bn "BatchExamples\Kroll_Batch.reb" -d "C:\evidence" --csv "C:\out\registry"

# Recherche ciblée par clé
RECmd.exe -f "C:\evidence\NTUSER.DAT" --kn "Software\Microsoft\Windows\CurrentVersion\Run"

# Recherche par valeur (mot-clé)
RECmd.exe -d "C:\evidence" --sv "powershell" --csv "C:\out\search_results"
```

| Outil | Rôle | Entrée | Sortie |
|---|---|---|---|
| KAPE | Orchestrateur collecte + parsing | Disque live / image montée | Dossier triage + CSV/JSON |
| MFTECmd | Parse `$MFT`, `$LogFile`, `$J` | Fichier NTFS brut | CSV |
| PECmd | Parse fichiers `.pf` | Dossier Prefetch | CSV |
| RECmd | Parse ruches registre | Fichier `.hve`/`NTUSER.DAT` | CSV |

!!! note "Ordre d'exécution recommandé sur scène live"
    1. `KAPE` avec target `!SANS_Triage` ou `KapeTriage` pour collecte rapide (avant extinction).
    2. Acquisition RAM (voir fiche *digital-forensics-acquisition*).
    3. Acquisition disque complète si nécessaire.
    4. Traitement offline avec les modules EZ Tools (`--module !EZParser`) sur le triage collecté.
