# 🛠️ lsof — Liste des Fichiers & Sockets Ouverts

## 1. Description rapide

**lsof** (*List Open Files*) liste tous les fichiers ouverts par les processus en cours. Sous Linux, tout est fichier : sockets réseau, pipes, fichiers réguliers, devices. Outil clé pour identifier quel processus utilise un port, un fichier ou une connexion réseau.

---

## 2. Syntaxe de base

```bash
lsof [options] [fichier/répertoire]
```

Sans argument, `lsof` liste **tous** les fichiers ouverts de tous les processus — sortie très volumineuse. Toujours filtrer.

---

## 3. Options et fanions principaux

| Flag | Rôle |
| --- | --- |
| `-i` | Connexions réseau (sockets Internet) |
| `-i :PORT` | Filtre sur un port spécifique |
| `-iTCP` | Uniquement les sockets TCP |
| `-iUDP` | Uniquement les sockets UDP |
| `-sTCP:LISTEN` | Filtre les sockets TCP en état LISTEN |
| `-sTCP:ESTABLISHED` | Filtre les connexions TCP établies |
| `-u USER` | Filtre par nom d'utilisateur |
| `-c NOM` | Filtre par nom de processus (partiel) |
| `-p PID` | Filtre par PID |
| `-n` | Pas de résolution DNS |
| `-P` | Pas de résolution de noms de port |
| `+D /path` | Liste les fichiers ouverts dans un répertoire |

---

## 4. Exemples pratiques

```bash
# Lister toutes les connexions réseau avec processus et port numérique
lsof -i -n -P
```

```bash
# Identifier quel processus utilise le port 80
lsof -i :80
```

```bash
# Lister uniquement les services en écoute TCP (équivalent ss -tlnp)
lsof -iTCP -sTCP:LISTEN -n -P
```

```bash
# Voir tous les fichiers ouverts par un utilisateur spécifique
lsof -u www-data
```

```bash
# Voir les fichiers réseau ouverts par un processus (ex: nginx)
lsof -c nginx -i
```

```bash
# Trouver tous les processus avec une connexion vers une IP externe (threat hunting)
lsof -i -n -P | grep ESTABLISHED | grep -v "127.0.0.1\|::1"
```

---

## 5. Astuces & Pièges à éviter

!!! tip "Identifier qui bloque un port"
    `lsof -i :8080` est la commande la plus rapide pour savoir quel processus bloque un port avant de démarrer un service. Évite l'erreur "address already in use".

!!! tip "Trouver les fichiers supprimés encore ouverts"
    `lsof | grep deleted` liste les fichiers supprimés mais encore retenus en mémoire par un processus. Utile quand `df -h` montre un disque plein mais que les fichiers semblent absents — un processus les maintient ouverts.

!!! warning "lsof est très lent sans filtre"
    Sans option, `lsof` énumère des dizaines de milliers d'entrées et peut prendre 10-30 secondes. Toujours filtrer avec `-i`, `-u`, `-c` ou `-p` avant d'exécuter.

!!! warning "Root requis pour les fichiers des autres utilisateurs"
    Sans `sudo`, `lsof` ne voit que les fichiers du processus courant. Les sockets des autres utilisateurs et des services système ne sont pas visibles. Toujours `sudo lsof -i` pour une vue réseau complète.
