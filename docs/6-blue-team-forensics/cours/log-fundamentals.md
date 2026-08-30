# Log Fundamentals

## 1. Standard Syslog & Niveaux de Log

### Structure RFC 5424

```text
<PRI>VERSION TIMESTAMP HOSTNAME APP-NAME PROCID MSGID STRUCTURED-DATA MSG

Exemple :
<34>1 2026-08-30T10:15:23.003Z host01 sshd 1234 ID47 [exampleSDID@32473 iut="3"] Failed password for root
```

| Élément | Description |
|---|---|
| `PRI` | Priority = `(Facility × 8) + Severity`, encodé entre `<` et `>` |
| `VERSION` | Version du protocole syslog (toujours `1` pour RFC 5424) |
| `TIMESTAMP` | Format ISO 8601 avec fraction de seconde et timezone |
| `HOSTNAME` | FQDN, adresse IP ou nom de l'hôte émetteur |
| `APP-NAME` | Nom du processus/application |
| `PROCID` | PID du processus émetteur |
| `MSGID` | Identifiant de type de message (optionnel) |
| `STRUCTURED-DATA` | Paires clé=valeur entre crochets (optionnel) |

### Facilities (extrait)

| Code | Facility |
|---|---|
| 0 | kern (noyau) |
| 3 | daemon |
| 4 | security/auth (auth.log) |
| 10 | authpriv |
| 16–23 | local0 – local7 (usage custom) |

### Severities

| Code | Niveau | Usage |
|---|---|---|
| 0 | Emergency | Système inutilisable |
| 1 | Alert | Action immédiate requise |
| 2 | Critical | Condition critique |
| 3 | Error | Erreur applicative |
| 4 | Warning | Avertissement |
| 5 | Notice | Événement normal mais significatif |
| 6 | Informational | Information |
| 7 | Debug | Détails de débogage |

```bash
# Calcul PRI : auth (facility 4) + Error (severity 3) = 4*8+3 = 35
echo "<35>1 2026-08-30T10:00:00Z host01 sshd - - - test message" | logger -u /dev/log
```

### Formats structurés — JSON vs CEF/LEEF

```json
// Format JSON (SIEM moderne, ELK/Splunk)
{
  "timestamp": "2026-08-30T10:15:23Z",
  "host": "web01",
  "src_ip": "203.0.113.42",
  "event_type": "auth_failure",
  "severity": "warning",
  "user": "admin"
}
```

```text
# Format CEF (ArcSight) — CEF:Version|Vendor|Product|Version|SignatureID|Name|Severity|Extension
CEF:0|Acme|WebGateway|2.1|100|SQL Injection Detected|8|src=203.0.113.42 dst=10.0.0.5 spt=443 request=/login.php?id=1' OR '1'='1

# Format LEEF (QRadar) — LEEF:Version|Vendor|Product|Version|EventID|Extension
LEEF:2.0|Acme|WebGateway|2.1|SQLi_Detect|src=203.0.113.42	dst=10.0.0.5	sev=8
```

!!! note "Choix du format"
    JSON favorise l'ingestion moderne (Elastic, Splunk HEC). CEF/LEEF restent des standards d'interopérabilité entre SIEM historiques (ArcSight, QRadar) — privilégier ces formats en environnement multi-fournisseurs.

---

## 2. Logs Web & Reverse Proxies

### Formats de logs

```text
# Apache Common Log Format (CLF)
127.0.0.1 - frank [30/Aug/2026:10:15:23 +0200] "GET /index.html HTTP/1.1" 200 2326

# Apache Combined Log Format (+ Referer, User-Agent)
127.0.0.1 - frank [30/Aug/2026:10:15:23 +0200] "GET /index.html HTTP/1.1" 200 2326 "http://ref.com" "Mozilla/5.0"

# Nginx (format par défaut, proche du Combined)
203.0.113.42 - - [30/Aug/2026:10:15:23 +0200] "POST /login.php HTTP/1.1" 401 512 "-" "curl/8.4.0"

# IIS (W3C Extended Log Format)
2026-08-30 10:15:23 W3SVC1 WEBSRV01 10.0.0.5 GET /default.asp - 80 - 203.0.113.42 Mozilla/5.0 - 200 0 0
```

| Champ | CLF/Combined | IIS W3C |
|---|---|---|
| IP client | 1er champ | `c-ip` |
| Date/heure | `[dd/Mon/yyyy:HH:mm:ss +tz]` | `date time` séparés |
| Méthode + URI | dans `"..."` | `cs-method`, `cs-uri-stem`, `cs-uri-query` |
| Code retour | après `"..."` | `sc-status` |
| User-Agent | dernier champ (Combined) | `cs(User-Agent)` |

### Détection de requêtes suspectes

```bash
# SQL Injection — Apache/Nginx
grep -Ei "(union.*select|or 1=1|' or '|sleep\(|benchmark\(|information_schema)" access.log

# XSS
grep -Ei "(<script|onerror=|onload=|javascript:|%3Cscript)" access.log

# Path Traversal
grep -E "(\.\./|\.\.%2f|%2e%2e%2f|/etc/passwd|/etc/shadow|boot\.ini)" access.log

# Scan de vulnérabilités (outils connus dans User-Agent)
grep -Ei "(nikto|sqlmap|nmap|acunetix|dirbuster|gobuster|wpscan|masscan)" access.log

# Taux d'erreurs 4xx/5xx anormal par IP (scan/bruteforce d'endpoints)
awk '{print $1, $9}' access.log | grep -E " (4[0-9]{2}|5[0-9]{2})" | awk '{print $1}' | sort | uniq -c | sort -rn | head -20
```

```powershell
# IIS — recherche de patterns SQLi/XSS dans les logs W3C
Select-String -Path "C:\inetpub\logs\LogFiles\W3SVC1\*.log" -Pattern "union.*select|<script|\.\./" -CaseSensitive:$false
```

!!! warning "Faux positifs"
    Un grep brut sur `union select` ou `../` peut remonter du trafic légitime (recherche full-text, téléchargement de fichiers avec chemins relatifs). Toujours corréler avec le code de retour HTTP (`403`, `500`) et la fréquence par IP.

---

## 3. Logs d'Authentification Linux & SSH

| Distribution | Fichier |
|---|---|
| Debian/Ubuntu | `/var/log/auth.log` |
| RHEL/CentOS/Fedora | `/var/log/secure` |
| systemd (universel) | `journalctl -u sshd` |

```bash
# Connexions SSH réussies
grep "Accepted" /var/log/auth.log

# Échecs d'authentification
grep "Failed password" /var/log/auth.log

# Tentatives sur utilisateur invalide (souvent bruteforce automatisé)
grep "Invalid user" /var/log/auth.log

# Déconnexions / sessions fermées
grep "session closed" /var/log/auth.log

# Équivalent RHEL/CentOS
grep "Failed password" /var/log/secure

# Via journalctl (systemd)
journalctl -u sshd --since "2026-08-30 00:00:00" --until "2026-08-30 23:59:59"
journalctl -u sshd -p err
```

### Parsing avec `grep` / `awk` / `cut` / `uniq -c`

```bash
# Extraire les IPs des échecs de connexion
grep "Failed password" /var/log/auth.log | awk '{print $(NF-3)}'

# Extraire IP + utilisateur ciblé
grep "Failed password" /var/log/auth.log | awk '{print $(NF-5), $(NF-3)}'

# Compter les échecs par IP, triés par fréquence décroissante
grep "Failed password" /var/log/auth.log | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn

# Extraire uniquement le champ utilisateur avec cut (après isolement awk)
grep "Failed password" /var/log/auth.log | awk '{print $9}' | cut -d' ' -f1 | sort | uniq -c | sort -rn

# Connexions réussies par utilisateur
grep "Accepted" /var/log/auth.log | awk '{print $9}' | sort | uniq -c | sort -rn
```

!!! note "Position des champs `awk`"
    La position des champs (`$(NF-3)`, `$9`...) dépend du format exact de la ligne syslog (avec ou sans hostname, format rsyslog vs journald). Toujours valider avec `head -1 auth.log | cat -A` avant d'automatiser un script.

---

## 4. Pattern Parsing & Threat Hunting CLI

```bash
# IPs uniques ayant tenté une connexion SSH (succès + échec)
grep -E "Failed password|Accepted" /var/log/auth.log | \
    grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | sort -u

# Top 10 IPs par nombre d'échecs (détection bruteforce)
grep "Failed password" /var/log/auth.log | \
    grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | sort | uniq -c | sort -rn | head -10

# Détection de bruteforce : IP avec plus de N échecs sur la période du fichier
grep "Failed password" /var/log/auth.log | \
    grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | sort | uniq -c | \
    awk '$1 > 50 {print $2, "-", $1, "tentatives"}'

# Corrélation échec → succès pour la même IP (compromission après bruteforce)
FAILED_IPS=$(grep "Failed password" /var/log/auth.log | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | sort -u)
for ip in $FAILED_IPS; do
    if grep "Accepted" /var/log/auth.log | grep -q "$ip"; then
        echo "ALERTE : $ip a échoué puis réussi une connexion"
    fi
done

# Requêtes web anormales : URI les plus longues (souvent injection/obfuscation)
awk -F'"' '{print $2}' access.log | awk '{print length, $0}' | sort -rn | head -10

# Requêtes avec un taux de méthodes HTTP inhabituel (PUT/DELETE/TRACE rares en usage normal)
awk '{print $6}' access.log | tr -d '"' | sort | uniq -c | sort -rn

# Fenêtre temporelle resserrée (ex: activité entre 2h et 5h du matin, hors horaires normaux)
awk '$4 ~ /:0[2-4]:/' access.log | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | sort | uniq -c | sort -rn
```

```bash
# Détection bruteforce distribué (multiples IPs, même utilisateur ciblé)
grep "Failed password" /var/log/auth.log | \
    awk '{print $(NF-5)}' | sort | uniq -c | sort -rn | head -5

# Fréquence des tentatives par minute (pic = script automatisé)
grep "Failed password" /var/log/auth.log | \
    awk '{print $1, $2, $3}' | cut -d: -f1,2 | sort | uniq -c | sort -rn | head -10
```

!!! danger "Seuils de détection"
    Il n'existe pas de seuil universel de "bruteforce" — un serveur exposé sur Internet reçoit un bruit de fond permanent. Baser la détection sur une **déviation** par rapport à la baseline habituelle de l'hôte plutôt qu'un chiffre fixe.

!!! tip "Passage à l'échelle"
    Pour des volumes de logs importants, préférer un pipeline SIEM (Elastic, Splunk) avec ces mêmes logiques de requêtes exprimées en KQL/SPL plutôt que du grep/awk sur fichiers bruts multi-Go.
