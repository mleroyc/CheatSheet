# 🛠️ Notion / Shell : One-liners, opérateurs logiques et boucles

## 1. Description rapide (Rôle et cas d'usage)

Les opérateurs d'enchaînement (`;`, `&&`, `||`) et les structures de contrôle (`for`, `if`) peuvent s'écrire en une seule ligne dans le shell, permettant d'automatiser des tâches répétitives (scan réseau, traitement par lots) directement en ligne de commande, sans écrire de script séparé. Un socle indispensable en administration système comme en reconnaissance offensive.

## 2. Syntaxe de base

```bash
cmd1 ; cmd2
cmd1 && cmd2
cmd1 || cmd2
for var in liste; do commande; done
if [ condition ]; then commande; else commande; fi
```

## 3. Options, fanions et opérateurs principaux

| Opérateur / Structure | Effet |
|---|---|
| `;` | Exécute les commandes séquentiellement, sans condition sur le résultat |
| `&&` | Exécute la commande suivante uniquement si la précédente a réussi (exit code 0) |
| `\|\|` | Exécute la commande suivante uniquement si la précédente a échoué (exit code ≠ 0) |
| `for var in liste; do ...; done` | Boucle sur chaque élément d'une liste ou d'un motif de fichiers |
| `{1..N}` | Génère une séquence de nombres de 1 à N |
| `if [ cond ]; then ...; fi` | Exécute un bloc si la condition est vraie |
| `if [ cond ]; then ...; else ...; fi` | Ajoute une branche alternative si la condition est fausse |

## 4. Exemples pratiques & Cas d'usage

**Balayage réseau rapide par ping en une ligne (reconnaissance)**
```bash
for i in {1..254}; do ping -c 1 -W 1 192.168.1.$i && echo "192.168.1.$i UP"; done
```

**Traiter en lot tous les fichiers de log d'un dossier**
```bash
for file in *.log; do gzip "$file"; done
```

**Enchaîner build et déploiement uniquement si chaque étape réussit**
```bash
make build && make test && make deploy
```

**Exécuter une commande de secours si la principale échoue**
```bash
ping -c 1 8.8.8.8 || echo "Pas de connexion internet"
```

**Vérifier l'existence d'un fichier avant de le traiter dans un script**
```bash
if [ -f /etc/nginx/nginx.conf ]; then echo "Config présente"; else echo "Config manquante"; fi
```

**Télécharger un script et l'inspecter avant exécution (bonne pratique sécurité)**
```bash
curl -o script.sh https://exemple.com/script.sh && cat script.sh
# Puis, seulement après vérification manuelle :
bash script.sh
```

## 5. Astuces & Pièges à éviter

!!! warning "Ne jamais faire curl | bash sans inspection préalable"
    Le pattern `curl https://url | bash` télécharge et exécute un script sans aucune vérification de son contenu, exposant à l'exécution de code arbitraire si l'URL est compromise ou détournée. Téléchargez toujours le script séparément, inspectez-le, puis exécutez-le dans un second temps.

!!! tip "&& et || sont basés sur le code de sortie (exit code), pas sur la sortie texte"
    `&&` et `||` réagissent au code de retour de la commande précédente (0 = succès, tout autre = échec), indépendamment de ce qui est affiché à l'écran. Une commande qui affiche une erreur en sortie mais retourne un code 0 sera quand même considérée comme un succès.

!!! tip "Le point-virgule n'offre aucune protection en cas d'échec"
    `cmd1 ; cmd2` exécute `cmd2` même si `cmd1` a échoué. Dans un enchaînement critique (ex: `cd /dossier ; rm -rf *`), préférez toujours `&&` pour éviter qu'une commande destructrice ne s'exécute dans le mauvais répertoire en cas d'échec du `cd`.
