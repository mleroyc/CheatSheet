# Cheat Sheet : `sudo` — Exécution de commandes avec élévation de privilèges

!!! tip "Usage principal"
    Exécuter une commande unique avec les droits d'un autre utilisateur (généralement root), en s'authentifiant avec son **propre** mot de passe et selon des règles définies dans `/etc/sudoers` — pierre angulaire de l'audit de privilèges en pentest.

## 1. Syntaxe de base

```bash
# Structure générale
sudo [options] commande [arguments]
```

## 2. Commandes rapides & Cas d'usage fréquents

### Exécuter une commande en tant que root
```bash
# Demande le mot de passe de l'utilisateur courant (pas celui de root)
sudo apt update
```

### Exécuter une commande en tant qu'un autre utilisateur
```bash
# Exécute la commande avec l'identité de www-data
sudo -u www-data whoami
```

### Ouvrir un shell root interactif
```bash
# Équivalent d'un accès root persistant tant que le shell reste ouvert
sudo -i
```

### Lister ses droits sudo
```bash
# Affiche les commandes exécutables sans mot de passe et les règles applicables à l'utilisateur
sudo -l
```

### Éditer un fichier avec les droits root en toute sécurité
```bash
# Évite les risques liés à l'édition directe de fichiers système en root
sudoedit /etc/hosts
```

## 3. Synthèse des Flags & Options (Tableau)

| Flag / Option | Rôle | Exemple d'utilisation |
| --- | --- | --- |
| `-l` | Liste les commandes autorisées pour l'utilisateur courant | `sudo -l` |
| `-u utilisateur` | Exécute la commande sous une identité autre que root | `sudo -u alice id` |
| `-i` | Ouvre un shell de connexion complet en tant que root | `sudo -i` |
| `-s` | Ouvre un shell root sans charger l'environnement de connexion | `sudo -s` |
| `-k` | Invalide immédiatement le cache d'authentification sudo | `sudo -k` |
| `-v` | Rafraîchit le cache d'authentification sans exécuter de commande | `sudo -v` |

## 4. One-Liners & Pièges courants

```bash
# Étape réflexe en post-exploitation : vérifier ce qu'on peut exécuter en sudo sans mot de passe
sudo -l 2>/dev/null
```

```bash
# Rechercher une entrée sudoers exploitable pour une élévation de privilèges (via GTFOBins)
sudo -l | grep -E "NOPASSWD|ALL"
```

!!! warning "Attention"
    Une entrée `sudo -l` autorisant un binaire comme `vim`, `find`, `less`, `python` ou `awk` **sans restriction d'arguments** permet quasi systématiquement un bypass root (échapper vers un shell depuis l'outil autorisé) : vérifier ces binaires sur [GTFOBins](https://gtfobins.github.io/) avant toute conclusion sur le niveau de sécurité réel.
