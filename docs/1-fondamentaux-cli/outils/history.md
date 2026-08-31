# 🛠️ Commande / Notion : history

## 1. Description rapide (Rôle et cas d'usage)

`history` affiche et gère l'historique des commandes exécutées dans le shell. Combiné aux raccourcis d'expansion (`!!`, `!$`, `!N`...) et à la recherche interactive (`Ctrl+R`), il permet de rejouer, corriger ou réutiliser des commandes précédentes sans les retaper — un gain de productivité majeur en administration système comme en audit de sécurité.

## 2. Syntaxe de base

```bash
history [OPTIONS]
!expansion
```

## 3. Options, fanions et raccourcis principaux

| Élément | Effet |
|---|---|
| `history` | Affiche l'historique numéroté des commandes |
| `history -c` | Efface l'historique de la session courante |
| `history -d N` | Supprime uniquement la ligne N de l'historique |
| `!!` | Rejoue la dernière commande exécutée |
| `!$` | Réutilise le dernier argument de la commande précédente |
| `!N` | Rejoue la commande numéro N de l'historique |
| `!string` | Rejoue la dernière commande commençant par *string* |
| `Ctrl+R` | Recherche interactive inversée dans l'historique |
| `Ctrl+G` / `Esc` | Annule la recherche interactive en cours |

## 4. Exemples pratiques & Cas d'usage

**Réexécuter la dernière commande avec les privilèges root (oubli de sudo)**
```bash
sudo !!
```

**Réutiliser le dernier argument d'une commande précédente**
```bash
mkdir /var/log/app_custom
cd !$
```

**Rejouer une commande précise repérée dans l'historique**
```bash
history | grep tar
!482
```

**Retrouver rapidement la dernière commande ssh vers un serveur donné**
```bash
!ssh
```

**Rechercher interactivement une commande complexe déjà tapée (recon pentest)**
```text
Ctrl+R
(taper) nmap -sV
```

**Nettoyer l'historique après une opération sensible (audit, poste partagé)**
```bash
history -c
history -w
```

## 5. Astuces & Pièges à éviter

!!! warning "Vérifier une commande avant de la rejouer avec !N ou !string"
    `!N` et `!string` exécutent **immédiatement** la commande trouvée, sans confirmation. Sur une commande destructrice (`rm`, `dd`), une erreur de numéro ou un match inattendu sur `!string` peut avoir des conséquences graves. Utilisez `:p` en suffixe (ex: `!!:p`) pour afficher la commande sans l'exécuter.

!!! tip "Ne pas enregistrer une commande sensible dans l'historique"
    En définissant `HISTCONTROL=ignorespace` dans votre `.bashrc`, toute commande précédée d'un espace ne sera pas enregistrée dans l'historique — pratique pour taper un mot de passe ou un token en argument sans le laisser persister.

!!! tip "Horodater et dimensionner l'historique"
    `HISTTIMEFORMAT="%F %T "` affiche la date/heure de chaque commande via `history` (utile en analyse forensique d'un poste compromis). `HISTSIZE` contrôle le nombre de commandes en mémoire de session, `HISTFILESIZE` le nombre conservé dans `~/.bash_history` entre les sessions.

| Variable | Rôle |
|---|---|
| `HISTSIZE` | Nombre de commandes conservées en mémoire pour la session courante |
| `HISTFILESIZE` | Nombre de commandes conservées dans le fichier d'historique sur disque |
| `HISTTIMEFORMAT` | Format d'affichage de l'horodatage de chaque commande |
| `HISTCONTROL=ignorespace` | N'enregistre pas les commandes précédées d'un espace |
| `HISTCONTROL=ignoredups` | N'enregistre pas les doublons consécutifs |
