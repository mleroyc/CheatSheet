# Bash Scripting — fiche de triche terrain

---

## 1. Shebang & variables

```bash
#!/bin/bash                        # Shebang : interpréteur utilisé pour exécuter le script
#!/usr/bin/env bash                # Variante portable, résout bash via le PATH
```

```bash
nom="valeur"                       # Variable locale au script (pas d'espace autour du =)
readonly PI="3.14"                 # Variable constante, non réassignable ensuite
export MA_VAR="valeur"             # Variable exportée, visible par les processus enfants
unset nom                          # Supprime une variable de l'environnement courant
```

```bash
resultat=$(commande)               # Substitution de commande, syntaxe moderne recommandée
resultat=`commande`                # Substitution de commande, syntaxe historique (backticks)
date_du_jour=$(date +%Y-%m-%d)     # Exemple : capture la sortie d'une commande dans une variable
```

| Variable d'environnement | Contenu |
|---|---|
| `$HOME` | Répertoire personnel de l'utilisateur courant |
| `$PATH` | Liste des répertoires de recherche des exécutables |
| `$USER` | Nom de l'utilisateur courant |
| `$PWD` | Répertoire de travail courant |
| `$SHELL` | Shell par défaut de l'utilisateur |

!!! tip "Quoting"
    Toujours entourer une variable de guillemets doubles à l'usage (`"$var"`) pour éviter le word splitting et l'expansion de glob sur les valeurs contenant espaces ou caractères spéciaux.

---

## 2. Arguments & variables spéciales

| Variable | Signification |
|---|---|
| `$0` | Nom du script en cours d'exécution |
| `$1` ... `$9` | Arguments positionnels (1er au 9e) |
| `$#` | Nombre total d'arguments passés au script |
| `$@` | Tous les arguments, en tant que liste de mots distincts |
| `$*` | Tous les arguments, en tant que chaîne unique |
| `$?` | Code de retour de la dernière commande exécutée (0 = succès) |
| `$$` | PID du script en cours d'exécution |
| `$!` | PID du dernier processus lancé en arrière-plan |

```bash
#!/bin/bash
echo "Script : $0"
echo "Premier argument : $1"
echo "Nombre d'arguments : $#"
echo "Tous les arguments : $@"

for arg in "$@"; do                # Itère correctement chaque argument, y compris avec espaces
    echo "Argument : $arg"
done
```

```bash
commande_qui_peut_echouer
if [ $? -eq 0 ]; then              # Vérifie le code de retour de la commande précédente
    echo "Succès"
fi
```

```bash
long_scan &                        # Lance un processus en arrière-plan
pid_scan=$!                        # Capture son PID immédiatement après
wait $pid_scan                     # Attend la fin du processus avant de continuer
```

---

## 3. Conditions & tests

```bash
if [ "$val" -eq 10 ]; then
    echo "Égal à 10"
elif [ "$val" -gt 10 ]; then
    echo "Supérieur à 10"
else
    echo "Inférieur à 10"
fi
```

| Opérateur numérique | Signification | Opérateur textuel | Signification |
|---|---|---|---|
| `-eq` | Égal | `==` | Chaînes identiques |
| `-ne` | Différent | `!=` | Chaînes différentes |
| `-lt` | Strictement inférieur | `-z` | Chaîne vide |
| `-gt` | Strictement supérieur | `-n` | Chaîne non vide |
| `-le` | Inférieur ou égal | | |
| `-ge` | Supérieur ou égal | | |

```bash
if [ -z "$var" ]; then             # Vrai si $var est vide ou non définie
    echo "Variable vide"
fi

if [ -n "$var" ]; then             # Vrai si $var contient une valeur
    echo "Variable non vide"
fi
```

| Test fichier | Signification |
|---|---|
| `-f fichier` | Vrai si le chemin existe et est un fichier régulier |
| `-d fichier` | Vrai si le chemin existe et est un répertoire |
| `-x fichier` | Vrai si le chemin existe et est exécutable |
| `-r fichier` | Vrai si le chemin est lisible |
| `-w fichier` | Vrai si le chemin est modifiable en écriture |
| `-e fichier` | Vrai si le chemin existe, quel que soit son type |

```bash
if [ -f "/etc/passwd" ] && [ -r "/etc/passwd" ]; then
    echo "Fichier présent et lisible"
fi
```

!!! warning "[ ] vs [[ ]]"
    `[[ ]]` (Bash uniquement, non POSIX) autorise `&&`/`||` directement à l'intérieur et évite les problèmes de word splitting sur les variables non quotées. Préférer `[[ ]]` dans un script explicitement `#!/bin/bash`.

---

## 4. Boucles

```bash
for item in liste1 liste2 liste3; do   # Itère sur une liste de mots explicite
    echo "$item"
done

for fichier in *.txt; do               # Itère sur le résultat d'un glob
    echo "$fichier"
done

for ((i=0; i<10; i++)); do             # Boucle for de style C, contrôle fin des bornes
    echo "Itération $i"
done
```

```bash
while read -r line; do                 # Lit un fichier ligne par ligne, -r évite l'interprétation des \
    echo "Ligne : $line"
done < fichier.txt

cat fichier.txt | while read -r line; do   # Variante via pipe (attention au sous-shell, cf. section 6)
    echo "Ligne : $line"
done
```

```bash
compteur=0
until [ $compteur -ge 5 ]; do          # S'exécute tant que la condition est fausse
    echo "Compteur : $compteur"
    ((compteur++))
done
```

!!! tip "break et continue"
    `break` interrompt immédiatement la boucle englobante, `continue` passe directement à l'itération suivante — syntaxe identique dans `for`, `while` et `until`.

---

## 5. One-liners Recon/Cyber

### Ping sweep rapide

```bash
for i in {1..254}; do (ping -c 1 -W 1 192.168.1.$i &>/dev/null && echo "192.168.1.$i UP") & done; wait
# Balaie un /24 en parallèle, n'affiche que les hôtes qui répondent
```

### Port scanning basique via /dev/tcp

```bash
for port in {1..1024}; do
    (echo > /dev/tcp/192.168.1.10/$port) &>/dev/null && echo "Port $port ouvert"
done
# Utilise la pseudo-device Bash /dev/tcp, sans dépendance externe (pas besoin de nmap/nc)
```

```bash
timeout 1 bash -c "echo > /dev/tcp/192.168.1.10/443" &>/dev/null && echo "443 ouvert" || echo "443 fermé"
# Variante avec timeout pour éviter un blocage sur un port filtré
```

### Parsing d'IP/URLs depuis un fichier

```bash
grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' fichier.txt | sort -u
# Extrait toutes les adresses IPv4 uniques d'un fichier texte

grep -oE 'https?://[^ "]+' fichier.txt | sort -u
# Extrait toutes les URLs uniques d'un fichier texte

grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' access.log | sort | uniq -c | sort -rn
# Classe les IP par fréquence d'apparition, décroissante (top talkers d'un log)
```

---

## 6. Gestion du flux & redirections

```bash
commande > fichier.txt             # Redirige STDOUT vers un fichier (écrase le contenu existant)
commande >> fichier.txt            # Redirige STDOUT en ajout (append) à la fin du fichier
commande 2> erreurs.txt            # Redirige uniquement STDERR vers un fichier
commande 2>&1                      # Redirige STDERR vers la même destination que STDOUT
commande > sortie.txt 2>&1         # Combine STDOUT et STDERR dans un seul fichier
commande &> tout.txt               # Raccourci Bash équivalent à > fichier 2>&1
commande > /dev/null 2>&1          # Supprime toute sortie, standard comme erreur
```

```bash
commande1 | commande2              # Envoie STDOUT de commande1 vers STDIN de commande2
nmap -p 80 192.168.1.0/24 | grep open   # Exemple : filtre la sortie d'un scan
```

```bash
commande | tee fichier.txt         # Affiche la sortie à l'écran ET l'enregistre dans un fichier
commande | tee -a fichier.txt      # Variante en mode ajout (append) plutôt qu'écrasement
scan.sh | tee resultats.txt | grep "CRITICAL"   # Journalise tout, tout en filtrant l'affichage
```

!!! warning "Sous-shell et pipe"
    `commande | while read line; do ...; done` exécute la boucle dans un sous-shell : toute variable modifiée à l'intérieur est perdue une fois le pipe terminé. Préférer `while read line; do ...; done < fichier` quand la persistance des variables est nécessaire après la boucle.
