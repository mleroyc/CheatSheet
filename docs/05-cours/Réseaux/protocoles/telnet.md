---
title: "Protocole Telnet : Fonctionnement, Risques et Usages de Diagnostic"
description: "Anatomie du protocole Telnet (port 23/TCP), absence de sécurité, interception de trafic, alternatives sécurisées (SSH) et utilisation comme sonde réseau."
tags:
  - telnet
  - network
  - legacy
  - security
  - protocoles
  - banner-grabbing
  - ssh
---

# Protocole Telnet : Fonctionnement, Risques et Usages de Diagnostic

!!! warning "Cadre légal"
    Les techniques d'audit et d'exploitation décrites dans ce document (énumération, sniffing, brute-force d'identifiants) ne doivent être mises en œuvre que dans un cadre légal explicite : laboratoire, CTF, ou test d'intrusion couvert par une autorisation écrite.

---

## 1. Résumé exécutif & définition

**Telnet** (*Teletype Network*, RFC 854) est un protocole de communication réseau historique opérant sur le **port 23/TCP**, conçu à l'origine pour permettre l'**administration à distance** et le **contrôle par ligne de commande** d'équipements ou de serveurs via une session de terminal texte interactive.

!!! danger "Constat de sécurité contemporain"
    Telnet est aujourd'hui considéré comme un protocole **obsolète et hautement critique** du point de vue de la sécurité, en raison de l'**absence totale de chiffrement** : identifiants, frappes clavier et sorties affichées circulent intégralement en **texte brut** sur le réseau, sans aucune protection de confidentialité ni d'intégrité.

Son usage en administration système est aujourd'hui proscrit par la quasi-totalité des référentiels de sécurité (ANSSI, PCI DSS, CIS Benchmarks) au profit de SSH. Il subsiste néanmoins, à la marge, comme outil ponctuel de diagnostic réseau bas niveau — usage détaillé en section 4.

---

## 2. Anatomie détaillée & mécanismes de fonctionnement

### Architecture NVT (Network Virtual Terminal)

Telnet repose sur le concept de **terminal virtuel réseau (NVT)** : une abstraction intermédiaire standardisée qui permet à des systèmes hétérogènes (terminaux, systèmes d'exploitation, jeux de caractères différents) de communiquer sans avoir à connaître les spécificités matérielles ou logicielles de l'autre extrémité. Le client et le serveur négocient dynamiquement, au démarrage de la session, un ensemble de paramètres partagés (jeu de caractères, mode d'écho, dimensions du terminal) traduits ensuite vers/depuis les conventions locales de chaque système.

```text
Client Telnet (terminal local) ←→ [Représentation NVT commune] ←→ Serveur Telnet (système distant)
```

### Commandes in-band & négociation d'options

Une particularité structurelle de Telnet est que ses **commandes de contrôle circulent dans le même flux que les données utilisateur** (in-band), distinguées par un octet spécial :

- **IAC** (*Interpret As Command*, valeur `255` / `0xFF`) : préfixe signalant que l'octet suivant doit être interprété comme une commande de négociation, et non comme un caractère de donnée normal.

La négociation d'options utilise quatre verbes formant les paires de propositions/réponses possibles :

| Verbe | Signification |
|---|---|
| `WILL` | L'émetteur propose ou confirme qu'il **activera** une option donnée de son côté |
| `WONT` | L'émetteur refuse ou désactive une option de son côté |
| `DO` | L'émetteur demande à son interlocuteur d'**activer** une option de son côté |
| `DONT` | L'émetteur demande à son interlocuteur de désactiver une option de son côté |

```text
# Exemple de négociation brute (représentation hexadécimale simplifiée)
Client → Serveur : IAC DO ECHO           (FF FD 01)  — "active l'écho serveur, je veux voir mes frappes renvoyées"
Serveur → Client : IAC WILL ECHO         (FF FB 01)  — "j'accepte, je gère l'écho de ton côté"

Client → Serveur : IAC WILL TERMINAL-TYPE (FF FB 18) — "je propose de t'indiquer mon type de terminal"
Serveur → Client : IAC DO TERMINAL-TYPE   (FF FD 18) — "j'accepte, envoie-moi cette information"
```

Ces échanges de négociation (taille de fenêtre, type de terminal, mode d'écho, gestion de la fin de ligne) se produisent au tout début de la session et peuvent se répéter ponctuellement, entièrement **en clair**, mêlées au flux de données lui-même.

### Absence de sécurité native

!!! danger "Trois défauts structurels cumulés"
    - **Aucun chiffrement** de la session : mots de passe, frappes clavier et sorties affichées circulent en texte brut de bout en bout.
    - **Aucune authentification forte** du serveur : rien n'empêche un attaquant de se faire passer pour le serveur légitime (absence de certificat, de clé d'hôte vérifiable comme en SSH).
    - **Aucune vérification d'intégrité** : un attaquant en position d'interception peut modifier silencieusement le contenu de la session (commandes envoyées, réponses affichées) sans que le client ou le serveur ne puisse détecter l'altération.

    Ce cumul expose Telnet à une **surface d'attaque maximale** face aux scénarios de Man-in-the-Middle, bien au-delà de la simple écoute passive.

---

## 3. Empreinte, audit & méthodologie d'exploitation (Red Team)

### Énumération & grabbing de bannières

```bash
# Connexion directe pour observer la bannière renvoyée par le service
telnet cible.com 23
```

```text
Trying 203.0.113.10...
Connected to cible.com.
Escape character is '^]'.

Ubuntu 22.04.3 LTS
cible login:
```

!!! tip "La bannière révèle souvent bien plus qu'un simple message d'accueil"
    La bannière pré-authentification affiche fréquemment le **système d'exploitation exact**, parfois sa version précise, et occasionnellement le nom d'hôte ou l'organisation propriétaire — autant d'informations exploitables pour cibler ensuite une recherche de vulnérabilités connues (CVE) propres à cette version précise.

**Scans automatisés via Nmap :**

```bash
# Détection du niveau de chiffrement effectif (Telnet ne devrait jamais en proposer)
nmap -p23 --script telnet-encryption cible.com

# Brute-force d'identifiants directement intégré au moteur NSE
nmap -p23 --script telnet-brute \
     --script-args userdb=users.txt,passdb=passwords.txt \
     cible.com

# Extraction d'informations NTLM exposées par certaines implémentations Windows/réseau
nmap -p23 --script telnet-ntlm-info cible.com
```

### Vecteurs d'attaque courants

**Sniffing / capture de trafic :**

```bash
# Capture ciblée du trafic Telnet pour extraction visuelle des identifiants
tcpdump -i eth0 -A 'tcp port 23'
```

```text
# Filtre Wireshark équivalent, pour une inspection interactive de la session
tcp.port == 23
```

!!! danger "Extraction triviale d'identifiants"
    Une session Telnet standard transmet le login, le mot de passe et l'intégralité des commandes tapées en clair, caractère par caractère. Toute position d'écoute sur le chemin réseau (Wi-Fi partagé, commutateur mal segmenté, port mirroring non autorisé) suffit à reconstituer l'intégralité d'une session, y compris les commandes exécutées et leurs sorties.

**Man-in-the-Middle (MitM) :**

```bash
# Positionnement en MitM via empoisonnement ARP (exemple avec ettercap)
ettercap -T -M arp:remote /192.168.1.1// /192.168.1.50//
```

Une fois positionné entre le client et le serveur, l'attaquant peut non seulement **observer** passivement la session, mais également **injecter des commandes arbitraires** au sein d'une session active déjà authentifiée, ou modifier silencieusement les réponses affichées à l'utilisateur légitime (ex : masquer une commande malveillante injectée par ailleurs).

!!! warning "MitM contre Telnet : au-delà de la simple écoute"
    Contrairement à un simple sniffing passif, une attaque MitM active sur Telnet permet une **prise de contrôle en temps réel** de la session : injection de commandes, altération des résultats affichés, voire maintien discret d'un accès parallèle à l'insu de l'administrateur légitime connecté.

**Brute-force d'identifiants (contexte IoT/réseau) :**

```bash
# Brute-force ciblé via Hydra sur un service Telnet exposé
hydra -L users.txt -P passwords.txt telnet://cible.com

# Test rapide d'identifiants par défaut constructeur, fréquents sur équipements IoT
hydra -l admin -P default_passwords.txt telnet://192.168.1.1
```

!!! danger "Telnet et les botnets IoT"
    L'exposition massive de services Telnet sur des équipements IoT (caméras, routeurs domestiques, objets connectés) conservant des **identifiants par défaut** constructeur non modifiés a directement permis l'émergence de botnets historiques de grande ampleur, dont **Mirai** reste l'exemple le plus documenté : un scan de masse du port 23/TCP suivi d'un test d'une liste réduite d'identifiants par défaut a suffi à compromettre des centaines de milliers d'appareils à l'échelle mondiale.

---

## 4. Usage légitime résiduel : Telnet comme sonde réseau

Malgré son obsolescence en tant que protocole d'administration, la commande `telnet` reste utilisée par certains administrateurs comme **outil de diagnostic rapide** pour tester la connectivité TCP brute vers un port arbitraire, sans se limiter au port 23 :

```bash
# Test de connectivité TCP vers un port arbitraire (ici, un serveur HTTP sur le port 80)
telnet 192.168.1.1 80
```

```text
Trying 192.168.1.1...
Connected to 192.168.1.1.
Escape character is '^]'.
```

!!! note "Pourquoi ça fonctionne même sans dialoguer en Telnet"
    Le client `telnet` établit simplement une connexion TCP standard vers l'hôte et le port indiqués. Si la connexion s'établit (`Connected to...`), le port est ouvert et accepte les connexions TCP — indépendamment du fait que le service qui y répond parle réellement le protocole Telnet. C'est cette propriété, et non une quelconque compatibilité protocolaire, qui rend le client Telnet utile comme sonde généraliste.

### Alternatives modernes recommandées pour ces tests

!!! tip "Préférer des outils dédiés au diagnostic, plus riches en information"
    L'usage du client Telnet à cette seule fin de sonde reste toléré, mais des alternatives modernes offrent davantage d'informations et de contrôle :

```bash
# netcat — équivalent direct, avec un mode "scan" explicite et verbeux
nc -zv 192.168.1.1 80

# curl — utile en particulier pour sonder un service HTTP/HTTPS avec le détail de la négociation
curl -v http://192.168.1.1:80

# PowerShell (environnements Windows) — test de connectivité avec résultat structuré
Test-NetConnection -ComputerName 192.168.1.1 -Port 80
```

---

## 5. Matrice comparative : Telnet vs SSH

| Critère | Telnet (port 23) | SSH (port 22) |
|---|---|---|
| **Chiffrement / Confidentialité** | Aucun — tout circule en texte brut | Chiffrement systématique de bout en bout (algorithmes modernes négociés, ex : ChaCha20-Poly1305, AES-GCM) |
| **Authentification** | Simple couple login/mot de passe transmis en clair, aucune vérification d'identité du serveur | Authentification forte, incluant la vérification de la **clé d'hôte du serveur** et la possibilité d'authentification par **clé cryptographique client** (Ed25519, RSA) |
| **Intégrité des données** | Aucune protection — une altération en transit passe inaperçue | Intégrité garantie par des codes d'authentification de message (MAC) sur chaque paquet de la session |
| **Conformité moderne (PCI DSS, ANSSI)** | Explicitement proscrit — la transmission en clair d'identifiants viole directement les exigences de protection des données d'authentification | Référence recommandée pour toute administration à distance, alignée avec les référentiels PCI DSS et les recommandations ANSSI |

---

## 6. Hardening, migration & remédiation (Blue Team)

### Désactivation totale du service Telnet

```bash
# Debian/Ubuntu — désinstallation complète du serveur Telnet
apt remove --purge telnetd
systemctl disable --now telnet.socket 2>/dev/null || true
```

```bash
# Équipements réseau Cisco IOS — désactivation explicite des lignes VTY en Telnet
line vty 0 4
 transport input ssh
 no transport input telnet
```

### Migration obligatoire vers SSH avec clés cryptographiques modernes

```bash
# Génération d'une paire de clés Ed25519, algorithme recommandé actuel
# (compact, performant, et considéré robuste face aux attaques connues)
ssh-keygen -t ed25519 -C "admin@cible.com" -f ~/.ssh/id_ed25519_admin
```

```ini
# /etc/ssh/sshd_config — configuration serveur SSH durcie de référence
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
Protocol 2
```

### Isolation des équipements legacy ne pouvant pas être mis à jour

!!! warning "Cas des équipements industriels/legacy incapables de supporter SSH"
    Certains équipements industriels (automates, matériel réseau ancien) n'implémentent parfois que Telnet nativement, sans possibilité de mise à niveau logicielle. Dans ce cas :

    - **Micro-segmenter** ces équipements dans un VLAN dédié, strictement isolé du reste du réseau de production et d'Internet.
    - N'autoriser l'accès Telnet à ces équipements que depuis un **bastion d'administration** dédié, lui-même accessible uniquement via SSH/VPN, jamais directement depuis un poste utilisateur standard.
    - Documenter et planifier explicitement le remplacement ou la mise à niveau de ces équipements à moyen terme plutôt que de considérer l'isolation comme une solution pérenne.

### Blocage du port 23/TCP aux pare-feux périphériques et internes

```bash
# Blocage explicite du port 23 en entrée, exemple iptables
iptables -A INPUT -p tcp --dport 23 -j DROP

# Blocage équivalent en sortie, pour empêcher tout usage sortant non autorisé
iptables -A OUTPUT -p tcp --dport 23 -j DROP
```

!!! danger "Le blocage périmétrique ne dispense pas de la désactivation locale"
    Bloquer le port 23 au niveau du pare-feu périphérique ne protège pas contre un service Telnet resté actif et accessible **en interne** (mouvement latéral post-compromission). La désactivation du service lui-même sur chaque hôte reste la mesure de fond ; le filtrage réseau n'en est qu'un complément de défense en profondeur.

---

## 7. Anti-sèche commandes CLI (Cheat Sheet)

```bash
# Connexion Telnet classique vers le port de service (23)
telnet cible.com 23

# Utilisation de Telnet comme sonde de connectivité TCP vers un port arbitraire
telnet cible.com 443

# Capture ciblée du trafic Telnet pour audit
tcpdump -i eth0 -A 'tcp port 23' -w capture_telnet.pcap

# Scan de découverte et d'audit via Nmap
nmap -p23 --script telnet-encryption,telnet-brute,telnet-ntlm-info cible.com

# Alternatives modernes pour un simple test de port, sans dialogue Telnet
nc -zv cible.com 443
curl -v telnet://cible.com:23   # curl sait aussi parler Telnet de façon minimale
Test-NetConnection -ComputerName cible.com -Port 443   # PowerShell
```

---

## 8. Références

- RFC 854 — *Telnet Protocol Specification* : [https://www.rfc-editor.org/rfc/rfc854](https://www.rfc-editor.org/rfc/rfc854)
- RFC 855 — *Telnet Option Specifications* : [https://www.rfc-editor.org/rfc/rfc855](https://www.rfc-editor.org/rfc/rfc855)
- ANSSI — Recommandations de sécurité relatives à l'administration sécurisée des systèmes d'information : [https://www.ssi.gouv.fr/](https://www.ssi.gouv.fr/)
