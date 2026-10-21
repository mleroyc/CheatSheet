# 🛠️ pstree — Arborescence des processus

## 1. Description rapide

`pstree` affiche les processus sous forme d'**arbre hiérarchique**, mettant en évidence les relations parent/enfant entre chaque processus. Il complète `ps` en offrant une vue structurelle immédiate plutôt qu'une liste plate.

**Cas d'usage :** comprendre la hiérarchie d'un service (worker spawner, master/worker), identifier un processus orphelin ou zombie, retracer l'origine d'un processus suspect (chaîne d'exécution en forensic), analyser les relations entre daemons.

---

## 2. Syntaxe de base

```bash
pstree                      # Arborescence de tous les processus depuis init/systemd
pstree -p                   # Affiche les PIDs entre parenthèses
pstree <PID>                # Arborescence à partir d'un processus précis
pstree <user>               # Arborescence des processus d'un utilisateur
```

---

## 3. Options et fanions principaux

| Option | Signification |
|---|---|
| `-p` | Affiche le PID de chaque processus entre parenthèses |
| `-u` | Affiche les changements d'utilisateur entre parent et enfant |
| `-a` | Affiche les arguments de chaque commande |
| `-n` | Trie par PID plutôt que par nom alphabétique |
| `-s` | Affiche les processus **ancêtres** d'un PID (chaîne vers init) |
| `-h` | Met en surbrillance le processus courant et ses ancêtres |
| `-H <PID>` | Met en surbrillance un PID spécifique |
| `-l` | Affichage long — ne tronque pas les lignes |
| `-g` | Affiche les PGID (Process Group ID) |
| `-t` | Affiche les noms de threads |
| `-Z` | Affiche les contextes SELinux (si activé) |

---

## 4. Exemples pratiques

```bash
# Arborescence complète avec PIDs
pstree -p

# Arborescence avec PIDs et changements d'utilisateur
pstree -pu

# Arborescence avec arguments des commandes et PIDs
pstree -pa

# Afficher uniquement les processus d'un utilisateur précis
pstree -p www-data

# Afficher l'arborescence à partir d'un PID précis (ex : un worker nginx)
pstree -p 1243

# Remonter la chaîne d'ancêtres d'un processus suspect (forensic)
pstree -ps $(pgrep -f "suspicious_script")
# Révèle le chemin complet : init → sshd → bash → suspicious_script

# Identifier les processus multi-threadés (threads regroupés)
pstree -t -p

# Comparer la hiérarchie avant/après un redémarrage de service
pstree -p | grep -A5 nginx
```

```text
# Exemple de sortie pstree -pu :
systemd(root)─┬─sshd(root)───sshd(root)───sshd(user)───bash(user)
              ├─nginx(root)─┬─nginx(www-data)
              │             └─nginx(www-data)
              ├─postgres(postgres)─┬─postgres(postgres)
              │                    └─postgres(postgres)
              └─cron(root)
```

---

## 5. Astuces & Pièges à éviter

!!! tip "Remonter l'origine d'un processus suspect"
    ```bash
    pstree -ps $(pgrep nc)
    # Si netcat tourne, révèle immédiatement quel processus parent l'a lancé
    # Ex : systemd → sshd → bash → nc  (connexion interactive légitime)
    # Ex : nginx → php-fpm → sh → nc   (RCE via webshell !)
    ```

!!! tip "Identifier les processus zombies"
    ```bash
    ps aux | awk '$8 == "Z" { print $2 }'   # Liste les PIDs zombies
    pstree -p | grep -B2 "Z"               # Retrouve le parent responsable du zombie
    ```
    Un zombie persiste parce que son processus **parent ne lit pas son code de retour** (`wait()`). La solution est de redémarrer le parent, pas de killer le zombie (qui est déjà mort).

!!! warning "pstree sans -l tronque les longues lignes"
    Par défaut, `pstree` tronque les lignes trop longues selon la largeur du terminal. Utiliser `-l` pour forcer l'affichage complet, notamment quand des arguments de commandes longs sont présents avec `-a`.

!!! warning "pstree ne remplace pas ps pour les détails"
    `pstree` est excellent pour la **structure** mais n'affiche pas %CPU, %MEM, RSS, ou l'état STAT. Pour un processus identifié visuellement dans pstree, basculer vers `ps -p <PID> -o pid,ppid,stat,%cpu,%mem,cmd` pour les métriques.

!!! tip "Utilisation en forensic — chaîne d'exécution complète"
    ```bash
    # Identifier comment un shell a été obtenu
    pstree -psa $(pgrep bash | tail -1)
    # Affiche les ancêtres + arguments → révèle si bash vient d'un sshd légitime
    # ou d'un processus anormal (php, python, nc...)
    ```
