# Cheat Sheet : Identité utilisateur — `whoami`, `id`, `groups`, `who`

!!! tip "Usage principal"
    Vérifier rapidement le contexte d'exécution courant (utilisateur, UID/GID, groupes, sessions actives) — étape réflexe en post-exploitation ou en audit système.

## 1. Syntaxe de base

```bash
# Structure générale
whoami
id [options] [utilisateur]
groups [utilisateur]
who [options]
```

## 2. Commandes rapides & Cas d'usage fréquents

### Identifier l'utilisateur courant
```bash
# Affiche uniquement le nom d'utilisateur actuel
whoami
```

### Vérifier ses privilèges effectifs (UID/GID)
```bash
# Affiche UID, GID principal et tous les groupes secondaires
id
```

### Vérifier l'identité d'un autre utilisateur
```bash
# Utile pour vérifier les droits d'un compte de service avant une escalade
id www-data
```

### Lister uniquement les groupes d'appartenance
```bash
# Liste les groupes de l'utilisateur courant
groups
```

### Voir qui est connecté et ce qu'il fait
```bash
# Liste les sessions actives, terminal et heure de connexion
who
```

## 3. Synthèse des Flags & Options (Tableau)

| Flag / Commande | Rôle | Exemple d'utilisation |
| --- | --- | --- |
| `id -u` | Affiche uniquement l'UID numérique | `id -u` |
| `id -un` | Affiche uniquement le nom d'utilisateur associé à l'UID | `id -un` |
| `id -g` | Affiche uniquement le GID principal | `id -g` |
| `id -Gn` | Liste les noms de tous les groupes secondaires | `id -Gn` |
| `who -a` | Affiche toutes les informations disponibles (login, boot, etc.) | `who -a` |
| `who -b` | Affiche la date/heure du dernier démarrage système | `who -b` |
| `w` | Comme `who`, mais ajoute la charge système et la commande en cours de chaque utilisateur | `w` |

## 4. One-Liners & Pièges courants

```bash
# Vérifier rapidement si on appartient à un groupe à privilèges (sudo, docker, adm...)
id | grep -Eo '(sudo|docker|adm|wheel)'
```

```bash
# Repérer un compte connecté récemment de manière suspecte (accès distant, pivot)
who | grep -v "$(whoami)"
```

!!! warning "Attention"
    `id` sans argument montre l'identité du shell courant, pas nécessairement celle du script en cours d'exécution (cas des scripts SUID/sudo) : pensez à vérifier `id` **dans** le contexte d'exécution réel (ex: dans un script, ou juste après un `sudo -u`).
