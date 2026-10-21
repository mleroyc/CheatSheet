---
title: "La commande Telnet : Outil de diagnostic réseau et interaction brute"
description: "Guide pratique de la commande CLI telnet : test de connectivité TCP, grabbing de bannières, commandes interactives, séquences d'échappement et alternatives (nc, curl, PowerShell)."
tags:
  - telnet
  - cli
  - network
  - troubleshooting
  - banner-grabbing
  - tools
---

# La commande Telnet : Outil de diagnostic réseau et interaction brute

!!! note "Complément à la fiche protocole"
    Cette fiche traite exclusivement de l'**outil CLI** `telnet` en tant qu'utilitaire de diagnostic et d'interaction manuelle. Pour l'analyse du **protocole** Telnet lui-même (architecture NVT, négociation d'options, risques de sécurité intrinsèques), voir la fiche dédiée `docs/protocoles/telnet.md`.

---

## 1. Résumé exécutif & usage contemporain

Le client CLI `telnet` a été historiquement conçu comme outil d'**administration à distance**, dialoguant nativement avec un serveur Telnet sur le port 23/TCP. Son usage contemporain a toutefois largement dérivé : il est aujourd'hui principalement réutilisé par les administrateurs et auditeurs comme une **sonde TCP universelle**.

!!! tip "Ce que fait réellement telnet sous le capot"
    La commande `telnet <HOST> <PORT>` ouvre un **socket TCP brut** vers l'hôte et le port spécifiés, puis affiche tel quel tout ce que le service distant renvoie sur ce socket. Elle ne nécessite aucunement que le service en écoute sur ce port parle le protocole Telnet — `telnet` fonctionne identiquement pour sonder un serveur HTTP (port 80), SMTP (port 25), POP3 (port 110) ou tout autre service texte brut, précisément parce que l'établissement de la connexion TCP est indépendant du protocole applicatif qui s'exécute ensuite au-dessus.

C'est cette propriété — et non une quelconque compatibilité protocolaire particulière — qui explique la popularité durable de `telnet` comme premier réflexe de diagnostic réseau, malgré l'obsolescence du protocole Telnet lui-même en tant que moyen d'administration sécurisé.

---

## 2. Utilisation pratique pour le diagnostic réseau

### Syntaxe de base

```bash
telnet <HOST> [PORT]
```

Si le port est omis, `telnet` tente par défaut une connexion sur le port 23/TCP (port de service Telnet standard).

```bash
# Connexion au port Telnet par défaut (23)
telnet 192.168.1.1

# Connexion explicite à un port arbitraire
telnet 192.168.1.1 8080
```

### Test de port TCP ouvert

Le message retourné par `telnet` immédiatement après la tentative de connexion constitue un diagnostic fiable de l'état du port, sans qu'aucune interaction applicative supplémentaire ne soit nécessaire :

```bash
telnet 192.168.1.1 80
```

```text
Trying 192.168.1.1...
Connected to 192.168.1.1.
Escape character is '^]'.
```

| Message retourné | Signification |
|---|---|
| `Connected to <HOST>` | Le port est **ouvert** : le handshake TCP (SYN/SYN-ACK/ACK) s'est terminé avec succès |
| `Connection refused` | Le port est **fermé** : la machine cible est joignable, mais aucun service n'écoute sur ce port — un paquet **RST** a été reçu en retour |
| `Connection timed out` | Aucune réponse reçue dans le délai imparti : généralement révélateur d'un **filtrage par pare-feu** (paquet silencieusement abandonné — *drop*), ou d'une machine réellement inaccessible sur le réseau |

!!! warning "Ne pas confondre port fermé et port filtré"
    Un `Connection refused` confirme que l'hôte a bien répondu (rien n'écoute sur ce port précis, mais la machine est active et joignable). Un `Connection timed out` ne permet en revanche pas de distinguer un pare-feu qui filtre silencieusement le port d'une machine simplement éteinte ou inaccessible sur le réseau — un outil de scan plus riche (Nmap) est nécessaire pour lever cette ambiguïté avec certitude.

### Gestion de la session et séquence d'échappement

Une fois une session `telnet` établie, la combinaison **`Ctrl + ]`** permet de suspendre l'interaction avec le service distant et de basculer vers le **prompt interactif local** du client, sans fermer la connexion sous-jacente :

```text
^]
telnet>
```

**Commandes disponibles depuis le prompt `telnet>` :**

| Commande | Effet |
|---|---|
| `status` | Affiche l'état actuel de la connexion (hôte, port, options négociées) |
| `close` | Ferme la connexion en cours et revient à l'invite système |
| `quit` | Quitte immédiatement le client `telnet`, fermant toute connexion active |
| `help` (ou `?`) | Liste l'ensemble des commandes disponibles depuis ce prompt |

```text
telnet> status
Connected to 192.168.1.1.
Operating in single character mode
Escape character is '^]'.

telnet> close
Connection closed.

telnet> quit
```

!!! tip "Revenir à la session active"
    Depuis le prompt `telnet>`, appuyer simplement sur `Entrée` sur une ligne vide (ou taper une commande non reconnue par le prompt) renvoie généralement à la session interactive avec le service distant, sans avoir à rouvrir la connexion.

---

## 3. Banner grabbing & interactions brutes

Une fois la connexion TCP établie vers un service texte brut, il est possible de dialoguer manuellement avec ce dernier en tapant directement les commandes attendues par son protocole applicatif.

### HTTP (port 80)

```bash
telnet exemple.com 80
```

```text
Trying 93.184.216.34...
Connected to exemple.com.
Escape character is '^]'.
GET / HTTP/1.1
Host: exemple.com

HTTP/1.1 200 OK
Server: nginx/1.24.0
Date: Wed, 09 Sep 2026 10:15:00 GMT
Content-Type: text/html; charset=UTF-8
Content-Length: 1256

<!DOCTYPE html>
<html>...
```

!!! note "Respecter la syntaxe HTTP exacte, y compris la ligne vide finale"
    La requête doit se terminer par une **ligne entièrement vide** (double retour à la ligne) après l'en-tête `Host:`, faute de quoi le serveur reste en attente indéfinie du reste de la requête. La ligne vide signale la fin des en-têtes de requête, conformément à la spécification HTTP.

### SMTP (port 25)

```bash
telnet mail.exemple.com 25
```

```text
Trying 203.0.113.10...
Connected to mail.exemple.com.
Escape character is '^]'.
220 mail.exemple.com ESMTP Postfix
EHLO test.com
250-mail.exemple.com Hello test.com
250 STARTTLS
MAIL FROM:<test@test.com>
250 OK
RCPT TO:<destinataire@exemple.com>
250 OK
```

### POP3 (port 110)

```bash
telnet mail.exemple.com 110
```

```text
Trying 203.0.113.10...
Connected to mail.exemple.com.
Escape character is '^]'.
+OK POP3 server ready
USER utilisateur
+OK
PASS motdepasse
+OK Logged in.
```

!!! danger "Rappel de sécurité"
    Ces interactions manuelles via `telnet` transitent **en clair** sur le réseau, exactement comme le ferait un client dédié non chiffré. Toute tentative d'authentification (`USER`/`PASS`, `MAIL FROM`/`RCPT TO` avec des identifiants réels) via une session `telnet` non protégée expose ces informations à quiconque intercepte le trafic — voir les fiches protocolaires dédiées pour le détail des risques associés à chaque service.

### Limites de la commande

!!! warning "Deux limites structurelles à connaître"
    - **Incapacité native à gérer TLS/SSL** : `telnet` ouvre uniquement un socket TCP brut, sans aucune couche de négociation cryptographique. Il est donc **impossible d'interagir directement** avec un port intrinsèquement chiffré (HTTPS/443, IMAPS/993, SMTPS/465) sans passer par un wrapper externe (`openssl s_client`, voir section 5) qui prend en charge la négociation TLS avant de restituer un flux texte clair exploitable.
    - **Gestion imprécise des fins de ligne (`CRLF`)** : selon le système d'exploitation et le terminal utilisés, `telnet` peut envoyer des fins de ligne `LF` seules plutôt que la séquence `CRLF` (`\r\n`) strictement attendue par de nombreux protocoles texte (HTTP, SMTP). Certains serveurs stricts peuvent alors mal interpréter la requête ou rester en attente, ce qu'un outil comme `curl` ou `nc` gère de façon plus fiable et prévisible.

---

## 4. Matrice d'installation par système d'exploitation

Le client `telnet` n'est plus installé par défaut sur la majorité des systèmes modernes, en cohérence avec la dépréciation générale du protocole.

| Système | Commande d'installation / activation |
|---|---|
| **Debian / Ubuntu** | `sudo apt install telnet` |
| **RHEL / Fedora / CentOS** | `sudo dnf install telnet` (ou `yum install telnet` sur les versions plus anciennes) |
| **Windows (10/11, Server)** | `Enable-WindowsOptionalFeature -Online -FeatureName TelnetClient` (PowerShell administrateur), ou activation manuelle via *Panneau de configuration → Programmes → Activer ou désactiver des fonctionnalités Windows → Client Telnet* |
| **macOS** | Non fourni nativement depuis plusieurs versions ; installation via Homebrew : `brew install telnet` |

```powershell
# Windows — activation via PowerShell (session administrateur requise)
Enable-WindowsOptionalFeature -Online -FeatureName TelnetClient
```

```bash
# macOS — installation via Homebrew
brew install telnet
```

!!! tip "Vérifier rapidement la disponibilité du client"
    Sur Linux/macOS, `which telnet` (ou `command -v telnet`) confirme immédiatement la présence du binaire dans le `PATH`. Sur Windows, `Get-WindowsOptionalFeature -Online -FeatureName TelnetClient` indique si la fonctionnalité est déjà activée.

---

## 5. Alternatives modernes recommandées

Pour les scripts automatisés comme pour le diagnostic quotidien, plusieurs outils offrent des capacités supérieures à `telnet`, en particulier pour la gestion du chiffrement, la rapidité de test et la clarté des retours.

### Netcat (`nc`)

```bash
# Test rapide d'un port unique, avec retour explicite (verbose) et sans interaction manuelle
nc -zv 192.168.1.1 80

# Test d'une plage de ports en une seule commande
nc -zv 192.168.1.1 20-25
```

```text
Connection to 192.168.1.1 80 port [tcp/http] succeeded!
```

!!! tip "Pourquoi nc est généralement préféré pour un simple test de port"
    Le flag `-z` (*zero-I/O mode*) referme immédiatement la connexion après le test, sans nécessiter de fermeture manuelle, et `-v` (verbose) affiche un résultat structuré et sans ambiguïté — contrairement à `telnet`, qui reste en attente d'une saisie manuelle même pour un simple test binaire ouvert/fermé.

### cURL

```bash
# Test verbeux d'une connexion HTTP, affichant la négociation complète
curl -v http://exemple.com:80

# Récupération des seuls en-têtes de réponse (HEAD implicite)
curl -I https://exemple.com
```

### OpenSSL — pour les services chiffrés TLS/SSL

```bash
# Connexion directe à un port intrinsèquement chiffré (HTTPS)
openssl s_client -connect exemple.com:443

# Élévation STARTTLS pour un service qui négocie le chiffrement dynamiquement (ex : SMTP)
openssl s_client -starttls smtp -connect mail.exemple.com:25
```

!!! note "Le complément indispensable là où telnet échoue"
    Comme rappelé en section 3, `telnet` ne sait pas négocier TLS. `openssl s_client` comble exactement cette limite : il établit la couche chiffrée (implicite ou via `-starttls`), puis restitue un flux texte clair sur lequel il devient possible de taper des commandes applicatives manuelles, exactement comme on le ferait avec `telnet` sur un port non chiffré.

### PowerShell (Windows)

```powershell
# Test de connectivité structuré, avec résultat booléen explicite et détails de route
Test-NetConnection -ComputerName exemple.com -Port 443
```

```text
ComputerName     : exemple.com
RemoteAddress    : 93.184.216.34
RemotePort       : 443
TcpTestSucceeded : True
```

---

## 6. Tableau synthétique & aide-mémoire (Cheat Sheet)

| Besoin | Commande |
|---|---|
| Ouvrir une connexion Telnet classique | `telnet <HOST> 23` |
| Tester un port TCP arbitraire | `telnet <HOST> <PORT>` |
| Passer au prompt interactif local | `Ctrl + ]` |
| Fermer la connexion depuis le prompt local | `telnet> close` |
| Quitter le client entièrement | `telnet> quit` |
| Équivalent rapide et verbeux via `nc` | `nc -zv <HOST> <PORT>` |
| Équivalent sur une plage de ports via `nc` | `nc -zv <HOST> <PORT_DEBUT>-<PORT_FIN>` |
| Équivalent HTTP verbeux via `curl` | `curl -v http://<HOST>:<PORT>` |
| Équivalent pour un service chiffré via `openssl` | `openssl s_client -connect <HOST>:<PORT>` |
| Équivalent STARTTLS via `openssl` | `openssl s_client -starttls <proto> -connect <HOST>:<PORT>` |
| Équivalent PowerShell (Windows) | `Test-NetConnection -ComputerName <HOST> -Port <PORT>` |

---

## 7. Références

- Manuel `telnet(1)` : `man telnet` (documentation locale spécifique à chaque distribution/implémentation)
- RFC 854 — *Telnet Protocol Specification* : [https://www.rfc-editor.org/rfc/rfc854](https://www.rfc-editor.org/rfc/rfc854)
