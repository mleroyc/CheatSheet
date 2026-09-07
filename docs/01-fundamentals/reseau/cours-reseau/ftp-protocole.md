# FTP — protocole et client en ligne de commande

Cheat sheet sur le client FTP en ligne de commande : connexion, authentification, modes de transfert et commandes de session.

---

## Connexion & authentification

```bash
ftp cible.com                      # Ouvre une session FTP interactive vers l'hôte cible
ftp 192.168.1.10 21                # Précise explicitement le port (21 = port par défaut)
```

```bash
open cible.com                     # Établit la connexion depuis une session ftp> déjà ouverte
close                              # Ferme la connexion courante sans quitter le client
```

À la connexion, le client demande un identifiant puis un mot de passe :

```text
Name (cible.com:user): admin
Password: ********
```

### Connexion anonyme

```text
Name (cible.com:user): anonymous
Password: anonymous@
```

!!! tip "Convention du mot de passe anonyme"
    Par convention historique, le mot de passe attendu pour un compte `anonymous` est une adresse e-mail, souvent acceptée sans validation réelle (`anonymous@`, `guest@guest.com`, ou simplement vide selon le serveur).

!!! warning "Serveur mal configuré"
    Un accès anonyme en écriture (upload autorisé) sur un serveur de production constitue une faille critique : dépôt de fichiers malveillants, saturation de l'espace disque, ou pivot vers d'autres vecteurs d'attaque.

---

## Modes actif & passif

| | Mode actif | Mode passif |
|---|---|---|
| **Initiateur de la connexion data** | Le serveur se connecte vers le client | Le client se connecte vers le serveur |
| **Commande associée** | `PORT` | `PASV` |
| **Compatibilité NAT/firewall côté client** | Problématique (connexion entrante requise) | Généralement plus fiable |
| **Port data côté serveur** | Port 20 fixe | Port aléatoire haut, ouvert dynamiquement |

```bash
passive                            # Bascule le client en mode passif (souvent activé par défaut)
passive                            # Rejouer la commande bascule (toggle) l'état actif/passif
```

!!! tip "Basculer en cas d'échec de listing"
    Si un `ls` ou `dir` reste bloqué sans réponse après connexion, il s'agit fréquemment d'un mode actif incompatible avec un pare-feu client. Basculer en mode passif via `passive` résout la majorité de ces blocages.

---

## Navigation & transfert de fichiers

### Navigation dans l'arborescence distante

```bash
ls                                 # Liste le contenu du répertoire distant courant
dir                                # Variante détaillée (souvent identique à ls selon le serveur)
pwd                                # Affiche le répertoire distant courant
cd dossier                         # Change de répertoire sur le serveur distant
lcd /chemin/local                  # Change le répertoire local courant (côté client)
lpwd                               # Affiche le répertoire local courant
```

### Transfert de fichiers

```bash
get fichier.txt                    # Télécharge un fichier distant vers le répertoire local courant
get fichier.txt local.txt          # Télécharge en renommant le fichier localement
mget *.txt                         # Télécharge plusieurs fichiers via un motif (glob)
```

```bash
put fichier.txt                    # Envoie un fichier local vers le serveur distant
mput *.txt                         # Envoie plusieurs fichiers locaux via un motif (glob)
```

```bash
binary                             # Bascule en mode de transfert binaire (exécutables, archives, images)
ascii                              # Bascule en mode de transfert texte (fichiers .txt)
```

!!! warning "Mode binaire par défaut recommandé"
    Le mode `ascii` convertit les fins de ligne selon le système, ce qui corrompt silencieusement tout fichier non textuel (exécutable, archive, image). Utiliser systématiquement `binary` sauf transfert de texte brut confirmé.

### Commandes de session utiles

```bash
prompt                             # Désactive/réactive la confirmation interactive sur mget/mput
delete fichier.txt                 # Supprime un fichier distant
mkdir dossier                      # Crée un répertoire distant
rmdir dossier                      # Supprime un répertoire distant vide
bye                                # Ferme la session et quitte le client FTP
```

!!! tip "Automatiser un transfert multiple"
    Désactiver la confirmation avec `prompt` avant un `mget *` ou `mput *` évite de valider manuellement chaque fichier un par un lors d'un transfert massif.

---

## Voir aussi

- Fiche complémentaire : `dns-outils.md` pour la reconnaissance réseau en amont
- RFC 959 — File Transfer Protocol (spécification originale)
