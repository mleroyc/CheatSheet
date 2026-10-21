# Windows Event Logs — CLI

## 1. Extraction et Analyse via CLI Windows

### `wevtutil`

```cmd
:: Lister tous les journaux disponibles
wevtutil el

:: Infos sur un journal (taille, rétention, chemin)
wevtutil gl Security

:: Exporter un journal complet (format .evtx, préserve l'intégrité)
wevtutil epl Security C:\evidence\Security.evtx

:: Exporter avec filtre XPath (ex: uniquement Event ID 4624)
wevtutil epl Security C:\evidence\Security_4624.evtx /q:"*[System[(EventID=4624)]]"

:: Lecture directe avec requête XPath (sortie texte)
wevtutil qe Security /q:"*[System[(EventID=4625)]]" /f:text /c:20

:: Effacer un journal (a des fins de test uniquement — jamais en IR réel)
wevtutil cl Application

:: Copier un journal exporté vers un nouveau fichier local pour analyse hors ligne
wevtutil epl "Microsoft-Windows-Sysmon/Operational" C:\evidence\Sysmon.evtx
```

### PowerShell `Get-WinEvent` — `-FilterHashtable`

```powershell
# Filtrage simple par ID et journal
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4624}

# Filtrage par plage temporelle
Get-WinEvent -FilterHashtable @{
    LogName   = 'Security'
    ID        = 4625
    StartTime = (Get-Date).AddHours(-24)
    EndTime   = Get-Date
}

# Filtrage multi-ID + niveau
Get-WinEvent -FilterHashtable @{
    LogName = 'Microsoft-Windows-Sysmon/Operational'
    ID      = 1,3,11
    Level   = 4  # Information
}

# Filtrage sur fichier .evtx exporté (analyse hors ligne)
Get-WinEvent -FilterHashtable @{Path='C:\evidence\Security.evtx'; ID=4688}

# Filtrage par ProviderName
Get-WinEvent -FilterHashtable @{ProviderName='Microsoft-Windows-Sysmon'; ID=1}
```

### PowerShell `Get-WinEvent` — `-FilterXPath`

```powershell
# Équivalent XPath du filtre par ID
Get-WinEvent -LogName Security -FilterXPath "*[System[(EventID=4624)]]"

# Filtre combiné : EventID + heure supérieure à une date UTC donnée
Get-WinEvent -LogName Security -FilterXPath `
  "*[System[(EventID=4624) and TimeCreated[@SystemTime>='2026-08-29T00:00:00.000Z']]]"

# Filtre sur une donnée spécifique (EventData/Data Name)
Get-WinEvent -LogName Security -FilterXPath `
  "*[System[EventID=4625]] and *[EventData[Data[@Name='TargetUserName']='administrateur']]"

# Filtre sur fichier exporté avec XPath
Get-WinEvent -Path "C:\evidence\Sysmon.evtx" -FilterXPath "*[System[(EventID=1)]]"
```

!!! tip "Hashtable vs XPath"
    `-FilterHashtable` est plus lisible et suffisant pour 90 % des cas (ID, temps, provider). `-FilterXPath` est indispensable dès qu'on doit filtrer sur le **contenu** des champs `EventData` (ex: nom d'utilisateur, IP source précise).

!!! warning "Performance"
    Éviter `Get-EventLog` (obsolète, lent). Toujours préférer `Get-WinEvent`, plus rapide et compatible avec les journaux ETW/Sysmon.

---

## 2. Event IDs de Sécurité Clés

| Event ID | Journal | Signification | Champs clés à examiner |
|---|---|---|---|
| 4624 | Security | Connexion réussie | `TargetUserName`, `LogonType`, `IpAddress`, `WorkstationName` |
| 4625 | Security | Échec de connexion | `TargetUserName`, `FailureReason`, `IpAddress`, `Status`/`SubStatus` |
| 4688 | Security | Création de processus | `NewProcessName`, `CommandLine` (si audit CLI activé), `ParentProcessName` |
| Sysmon ID 1 | Sysmon/Operational | Création de processus (détaillé) | `Image`, `CommandLine`, `ParentImage`, `Hashes`, `User` |
| 4672 | Security | Attribution de privilèges spéciaux (logon admin) | `SubjectUserName`, `PrivilegeList` |
| 1102 | Security | Effacement du journal d'audit (anti-forensics) | `SubjectUserName`, heure de l'action |

### Table des `LogonType` (Event 4624/4625)

| Code | Type | Contexte |
|---|---|---|
| 2 | Interactive | Connexion locale au clavier |
| 3 | Network | Accès réseau (partage SMB, etc.) |
| 4 | Batch | Tâche planifiée |
| 5 | Service | Démarrage d'un service |
| 7 | Unlock | Déverrouillage de session |
| 8 | NetworkCleartext | Authentification réseau en clair |
| 9 | NewCredentials | `RunAs /netonly` |
| 10 | RemoteInteractive | RDP |
| 11 | CachedInteractive | Logon avec creds mis en cache (pas de contact DC) |

!!! danger "Event ID 1102 — Alerte critique"
    La présence d'un `1102` (nettoyage du journal de sécurité) est un indicateur fort d'anti-forensics / couverture de traces. Corréler immédiatement avec l'utilisateur `SubjectUserName` et les événements juste avant l'effacement.

```powershell
# Détection rapide des 1102
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=1102}

# Détection des logons avec privilèges (4672) suivis de suppression de logs
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4672,1102} |
    Sort-Object TimeCreated |
    Select-Object TimeCreated, Id, @{N='User';E={$_.Properties[1].Value}}
```

---

## 3. Analyse des Logs Sysmon

| Event ID | Nom | Contenu | Cas d'usage |
|---|---|---|---|
| 1 | Process Creation | `Image`, `CommandLine`, `ParentImage`, `Hashes`, `User`, `IntegrityLevel` | Détection exécution malveillante, LOLBins |
| 3 | Network Connection | `Image`, `DestinationIp`, `DestinationPort`, `Protocol` | C2, exfiltration, scan réseau |
| 7 | Image Loaded | `Image`, `ImageLoaded`, `Signed`, `Hashes` | DLL sideloading, injection de code |
| 11 | FileCreate | `Image`, `TargetFilename`, `CreationUtcTime` | Dropper, persistance, staging fichiers |
| 13 | RawAccessRead | `Image`, `Device` | Lecture brute disque (dump SAM, contournement ACL) |

```powershell
# Sysmon ID 1 — Process Creation, top commandes
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Sysmon/Operational'; ID=1} |
    ForEach-Object {
        [PSCustomObject]@{
            Time    = $_.TimeCreated
            Image   = ($_.Properties[4].Value)
            CmdLine = ($_.Properties[10].Value)
            Parent  = ($_.Properties[21].Value)
        }
    } | Format-Table -AutoSize

# Sysmon ID 3 — Connexions réseau sortantes vers un port suspect
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Sysmon/Operational'; ID=3} |
    Where-Object { $_.Message -match "DestinationPort: (4444|8080|1337)" }

# Sysmon ID 7 — DLL non signées chargées
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Sysmon/Operational'; ID=7} |
    Where-Object { $_.Message -match "Signed: false" }

# Sysmon ID 11 — Créations de fichiers dans un dossier sensible
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Sysmon/Operational'; ID=11} |
    Where-Object { $_.Message -match "AppData\\Roaming" }

# Sysmon ID 13 — Accès disque brut (souvent outils de dump credentials)
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Sysmon/Operational'; ID=13}
```

!!! note "Prérequis Sysmon"
    Sysmon doit être installé avec une configuration adaptée (ex: config SwiftOnSecurity ou Olaf Hartong) pour générer ces événements. Le journal se trouve sous `Applications and Services Logs > Microsoft > Windows > Sysmon > Operational`.

---

## 4. One-liners PowerShell pour l'IR

```powershell
# Toutes connexions échouées des dernières 24h, groupées par IP source
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4625; StartTime=(Get-Date).AddHours(-24)} |
    ForEach-Object { $_.Properties[19].Value } |
    Group-Object | Sort-Object Count -Descending

# Recherche par utilisateur cible sur une plage de temps précise
Get-WinEvent -FilterHashtable @{
    LogName   = 'Security'
    ID        = 4624,4625
    StartTime = "2026-08-29 00:00:00"
    EndTime   = "2026-08-30 23:59:59"
} | Where-Object { $_.Properties[5].Value -eq 'jdupont' } |
    Select-Object TimeCreated, Id, @{N='LogonType';E={$_.Properties[8].Value}}

# Recherche par IP source spécifique (via XPath, plus rapide)
Get-WinEvent -LogName Security -FilterXPath `
  "*[EventData[Data[@Name='IpAddress']='203.0.113.42']]"

# Corrélation logon suspect (Type 10 = RDP) + heure hors plage horaire
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4624} |
    Where-Object {
        ($_.Properties[8].Value -eq 10) -and
        ($_.TimeCreated.Hour -lt 6 -or $_.TimeCreated.Hour -gt 20)
    }

# Extraction rapide de toutes les lignes de commande (Sysmon 1) contenant un mot-clé
Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Sysmon/Operational'; ID=1} |
    Where-Object { $_.Message -match 'powershell.*-enc' }

# Export CSV consolidé pour rapport / partage
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4624,4625,4672,1102} |
    Select-Object TimeCreated, Id, LevelDisplayName, Message |
    Export-Csv -Path C:\evidence\security_timeline.csv -NoTypeInformation -Encoding UTF8

# Requête multi-journaux combinée (Security + Sysmon) triée chronologiquement
Get-WinEvent -FilterHashtable @{
    LogName = 'Security','Microsoft-Windows-Sysmon/Operational'
    StartTime = (Get-Date).AddDays(-1)
} | Sort-Object TimeCreated | Select-Object TimeCreated, LogName, Id
```

!!! warning "Comptage `.Properties[]`"
    L'index des `Properties[]` correspond à l'ordre des champs `<Data Name=...>` dans le schéma XML de l'événement — il varie selon l'Event ID et la version d'OS/Sysmon. Toujours vérifier via :
    ```powershell
    ($event.ToXml())
    ```
    avant de coder un script basé sur un index fixe.

!!! tip "Performance sur gros volumes"
    Toujours combiner `-FilterHashtable`/`-FilterXPath` avec `StartTime`/`EndTime` pour éviter de charger l'intégralité d'un journal volumineux en mémoire.
