# CheatSheet

Bienvenue sur la documentation de référence.

---

## 📌 Synthèse Globale

| Catégorie | Protocole | Port(s) | Transport | Chiffrement / Sécurité |
| :--- | :--- | :--- | :--- | :--- |
| **Administration** | Telnet | 23 | TCP | ❌ Non chiffré (À bannir) |
| | SSH / SFTP | 22 | TCP | **✅ Chiffré** |
| **Transfert & Partage** | FTP (Control) | 21 | TCP | ❌ Non chiffré |
| | FTP (Data - Actif) | 20 | TCP | ❌ Non chiffré |
| | TFTP | 69 | UDP | ❌ Non chiffré |
| | FTPS | 989, 990, 21 | TCP | **✅ Chiffré** (TLS) |
| | SMB | 445 (137-139) | TCP | ⚠️ Dépend de la version |
| | NFS | 2049 | TCP / UDP | ❌ Non chiffré (par défaut) |
| **Noms & Annuaires** | DNS | 53 | UDP / TCP | ❌ Non chiffré (par défaut) |
| | DoT | 853 | TCP | **✅ Chiffré** (TLS) |
| | DoH | 443 | TCP | **✅ Chiffré** (HTTPS) |
| | DHCP | 67, 68 | UDP | ❌ Non chiffré |
| | LDAP | 389 | TCP / UDP | ❌ Non chiffré |
| | LDAPS | 636 | TCP / UDP | **✅ Chiffré** (TLS) |
| **Messagerie** | SMTP | 25 | TCP | ❌ Non chiffré |
| | SMTP Submission | 587 | TCP | ⚠️ Souvent STARTTLS |
| | SMTPS | 465 | TCP | **✅ Chiffré** (TLS) |
| | POP3 | 110 | TCP | ❌ Non chiffré |
| | POP3S | 995 | TCP | **✅ Chiffré** (TLS) |
| | IMAP | 143 | TCP | ❌ Non chiffré |
| | IMAPS | 993 | TCP | **✅ Chiffré** (TLS) |
| **Web** | HTTP | 80 | TCP | ❌ Non chiffré |
| | HTTPS | 443 | TCP | **✅ Chiffré** (TLS) |
| **Infrastructure** | NTP | 123 | UDP | ❌ Non chiffré |
| | SNMP | 161, 162 | UDP | ❌ v1/v2c / **✅ v3** |
| | Syslog | 514, 6514 | UDP / TCP | ⚠️ 6514 pour TLS |
| **Bases de Données** | MySQL / MariaDB | 3306 | TCP | ⚠️ Selon configuration |
| | PostgreSQL | 5432 | TCP | ⚠️ Selon configuration |
| | MSSQL | 1433 | TCP | ⚠️ Selon configuration |
| | Oracle DB | 1521 | TCP | ⚠️ Selon configuration |
| | Redis | 6379 | TCP | ❌ Souvent sans auth |
| | MongoDB | 27017 | TCP | ⚠️ Selon configuration |