# Glossaire de cybersécurité

> **Périmètre :** informatique, systèmes, réseaux, sécurité applicative, cloud, Blue Team, Red Team, réponse à incident et gouvernance. Les définitions sont volontairement courtes et pratiques.
>
> **Dernière révision éditoriale :** 23 octobre 2026.
>
> **Limite :** aucun glossaire ne peut contenir littéralement tous les outils, protocoles, vulnérabilités et noms d'attaques existants. Ce document constitue une base de référence large, destinée à être complétée. Les noms de produits et les techniques évoluent ; consulter les références officielles en fin de document.
>
> **Cadre d'utilisation :** les tests offensifs, scans, simulations d'hameçonnage et analyses doivent être effectués uniquement sur des systèmes que l'on possède ou pour lesquels on dispose d'une autorisation explicite et d'un périmètre défini.


## Sommaire

- [Glossaire alphabétique](#glossaire-alphabetique)
  - [Chiffres et symboles](#chiffres-et-symboles)
  - [A](#a) · [B](#b) · [C](#c) · [D](#d) · [E](#e) · [F](#f) · [G](#g) · [H](#h) · [I](#i) · [J](#j) · [K](#k) · [L](#l) · [M](#m) · [N](#n) · [O](#o) · [P](#p) · [Q](#q) · [R](#r) · [S](#s) · [T](#t) · [U](#u) · [V](#v) · [W](#w) · [X](#x) · [Y](#y) · [Z](#z)
- [Référence rapide des ports](#reference-rapide-des-ports)
- [Références utiles](#references-utiles)
- [Notes de maintenance](#notes-de-maintenance)

---

## Glossaire alphabétique

### Chiffres et symboles

- **802.1X** — Contrôle d'accès réseau basé sur l'authentification de port.

### A

- **AAA** — Authentication, Authorization, Accounting : authentification, autorisation et traçabilité/comptabilisation.
- **ABAC** — Contrôle d'accès basé sur des attributs du sujet, de la ressource et du contexte.
- **Abuse.ch** — Ensemble de projets et flux utiles à la recherche de menaces et d'infrastructures malveillantes.
- **Accès aux identifiants (Credential Access)** — Obtention de mots de passe, jetons, clés ou autres éléments d'authentification.
- **Accès initial (Initial Access)** — Première prise de pied dans un environnement.
- **ACL** — Access Control List, liste de contrôle d'accès.
- **ACL (Access Control List)** — Liste des droits ou règles d'accès associés à un objet.
- **Acquisition forensique** — Création d'une copie ou collecte documentée de données à des fins d'analyse.
- **Actif** — Élément ayant de la valeur pour une organisation : données, système, compte, service, réseau ou savoir-faire.
- **Active Directory (AD)** — Service d'annuaire Microsoft couramment utilisé pour les identités, ordinateurs, groupes et politiques d'un domaine Windows.
- **ADCS** — Services de certificats Active Directory ; une configuration incorrecte peut créer des chemins d'escalade de privilèges.
- **Admission controller** — Contrôle appliqué à des objets Kubernetes au moment de leur admission.
- **Adresse MAC** — Identifiant de couche liaison généralement utilisé sur un réseau local.
- **Adversaire / acteur de menace** — Personne, groupe ou entité susceptible de mener une action malveillante.
- **Adversarial example** — Entrée manipulée pour provoquer une erreur ou une réponse inattendue d'un modèle.
- **AES** — Advanced Encryption Standard.
- **AES** — Algorithme de chiffrement symétrique largement utilisé.
- **AI red teaming** — Évaluation systématique des comportements indésirables, détournements et fuites d'un système d'IA.
- **Air gap** — Séparation physique ou logique forte entre réseaux ; elle réduit certaines voies d'accès mais n'annule pas tout risque.
- **Aircrack-ng** — Suite de diagnostic et d'audit des réseaux Wi-Fi, à employer uniquement sur des réseaux autorisés.
- **Alert fatigue** — Diminution de l'attention des analystes due à un trop grand volume d'alertes peu pertinentes.
- **Alerte** — Signal généré par une règle, un outil ou un analyste nécessitant une qualification.
- **Amass** — Cartographie de surface externe et découverte de relations DNS/infrastructure.
- **Amplification attack** — Usage d'un service tiers pour produire une réponse nettement plus grande que la requête initiale.
- **AMQP** — Protocole de messagerie entre applications.
- **Analyse de risque** — Démarche qui identifie les scénarios de risque et estime leur vraisemblance et leur impact.
- **Android Debug Bridge (ADB)** — Outil de développement et de diagnostic permettant de communiquer avec un appareil ou émulateur Android.
- **Anonymisation** — Transformation visant à rendre l'identification des personnes irréalisable dans les conditions considérées ; l'évaluation dépend des moyens raisonnablement disponibles.
- **ANSSI** — Agence nationale française de la sécurité des systèmes d'information.
- **API** — Application Programming Interface.
- **API (Application Programming Interface)** — Interface permettant à des logiciels d'échanger des données ou de déclencher des opérations.
- **API gateway** — Point d'entrée centralisant souvent authentification, limitation de débit, routage et journalisation des API.
- **API key** — Secret ou identifiant utilisé par une application pour accéder à une API ; sa portée et sa rotation sont essentielles.
- **Application web** — Application accessible au moyen d'un navigateur ou d'un protocole Web.
- **Application-layer DoS** — Saturation de ressources applicatives par des requêtes coûteuses.
- **APT** — Advanced Persistent Threat.
- **APT (Advanced Persistent Threat)** — Campagne ou acteur capable de mener des opérations persistantes et ciblées ; le terme ne désigne pas nécessairement un groupe précis.
- **Arbitrary Code Execution (ACE)** — Capacité à faire exécuter du code choisi dans un contexte donné ; le terme ne précise pas nécessairement si l'accès est distant.
- **Arbitrary File Read/Write** — Lecture ou écriture de fichiers sans autorisation adéquate.
- **Argon2 / scrypt / bcrypt / PBKDF2** — Fonctions de dérivation de clé utilisables pour stocker les mots de passe ; choix et paramètres doivent être adaptés au contexte.
- **Arjun** — Outil de découverte de paramètres HTTP.
- **ARP** — Protocole de résolution IPv4 vers adresse MAC sur le réseau local.
- **ARP spoofing / ARP poisoning** — Falsification de réponses ARP pour associer une adresse IP à une adresse MAC contrôlée par l'attaquant.
- **Artefact forensique** — Trace exploitable laissée par un système ou une application.
- **Artifact repository** — Registre conservant les livrables logiciels construits.
- **AS-REP roasting** — Technique visant des comptes Kerberos configurés sans pré-authentification, permettant une tentative de récupération hors ligne du secret.
- **Atomic Red Team** — Bibliothèque de tests atomiques mappés sur des techniques de sécurité, utilisée pour valider des contrôles de détection.
- **Attaque** — Action visant à compromettre la confidentialité, l'intégrité, la disponibilité ou le contrôle d'un système.
- **Audit de conformité** — Vérification documentée du respect d'exigences légales, contractuelles ou normatives.
- **Audit technique** — Évaluation d'une configuration, d'un système ou d'une application selon un référentiel ou des objectifs définis.
- **auditd** — Sous-système de journalisation d'audit Linux.
- **Authentication bypass** — Contournement des contrôles d'authentification.
- **Authenticité** — Propriété garantissant qu'une identité, un message ou une origine est bien celle annoncée.
- **Authentification défaillante** — Contrôles insuffisants pour prouver l'identité ou gérer les sessions.
- **Authorization bypass** — Contournement des vérifications qui déterminent les opérations ou ressources accessibles.
- **Autopsy / The Sleuth Kit** — Outils d'analyse d'images disque et de systèmes de fichiers.
- **Autoruns** — Utilitaire Sysinternals pour examiner les mécanismes de démarrage automatique sous Windows.
- **AV** — Antivirus.

### B

- **Baiting** — Appât, comme un fichier ou support prétendument intéressant, visant à provoquer une action risquée.
- **Bandit** — Outil d'analyse statique de code Python ciblant certaines faiblesses de sécurité.
- **Banner grabbing** — Collecte des bannières ou métadonnées exposées par des services.
- **BAS** — Breach and Attack Simulation.
- **Baseline** — Configuration de référence servant à mesurer et contrôler l'état de sécurité.
- **Bastion / jump host** — Hôte intermédiaire contrôlé pour accéder à des systèmes d'administration.
- **BCP / DRP** — Plans de continuité d'activité et de reprise après sinistre.
- **BCP / PCA** — Business Continuity Plan / plan de continuité d'activité.
- **Beacon** — Signal périodique émis par un implant ou agent vers une infrastructure de contrôle.
- **BEC** — Business Email Compromise.
- **BEC (Business Email Compromise)** — Fraude exploitant une boîte mail ou se faisant passer pour un interlocuteur professionnel afin d'obtenir un paiement ou des données.
- **Bettercap** — Cadre de test et d'observation réseau utilisé en laboratoire et pour des audits autorisés.
- **BFLA (Broken Function Level Authorization)** — Faiblesse API où des fonctions sont accessibles au-delà des droits attendus.
- **BGP** — Border Gateway Protocol.
- **BGP** — Protocole de routage inter-domaines utilisé entre systèmes autonomes sur Internet.
- **BGP hijacking / route leak** — Annonce ou propagation incorrecte de routes BGP pouvant détourner ou perturber le trafic.
- **Binary Ninja** — Plateforme d'analyse et d'ingénierie inverse.
- **BloodHound** — Outil de visualisation des relations et chemins de privilèges dans des environnements Active Directory et Entra ID selon les collecteurs utilisés.
- **BOLA (Broken Object Level Authorization)** — Faiblesse API où un utilisateur peut accéder à l'objet d'un autre faute de vérification des droits.
- **Botnet** — Ensemble de systèmes compromis pilotés de manière coordonnée.
- **Breach simulation / BAS** — Tests automatisés de scénarios d'attaque afin de valider des contrôles de prévention et détection.
- **Broken Access Control** — Catégorie générale de contrôles d'accès insuffisants.
- **Brute force** — Essais répétés de valeurs possibles pour trouver un secret ou un identifiant valide.
- **Bucket public** — Espace de stockage cloud accessible publiquement, intentionnellement ou par erreur.
- **Buffer overflow** — Écriture au-delà des limites d'un tampon mémoire.
- **Bug bounty** — Programme récompensant le signalement de vulnérabilités dans un périmètre défini.
- **Build system compromise** — Compromission d'un outil ou d'une étape de compilation pouvant contaminer les artefacts produits.
- **Burp Suite** — Plateforme de test de sécurité des applications Web avec proxy d'interception et outils d'analyse.
- **Business email rule abuse** — Détournement de règles de boîte mail pour masquer des messages, rediriger des échanges ou faciliter une fraude.
- **Business logic flaw** — Contournement d'une règle métier sans nécessairement exploiter une erreur technique classique.
- **BYOD** — Bring Your Own Device, utilisation d'appareils personnels dans un contexte professionnel.

### C

- **C2 / C&C** — Command and Control.
- **CA** — Certificate Authority.
- **CA (Certificate Authority)** — Autorité qui émet et signe des certificats.
- **Cache poisoning** — Introduction de données indésirables dans un cache partagé.
- **Caldera** — Voir MITRE CALDERA ; orchestration de scénarios d'émulation adversaire.
- **Campagne** — Ensemble coordonné d'activités liées à une même opération ou un même objectif.
- **Canary token** — Élément leurre servant à signaler un accès inattendu lorsqu'il est utilisé.
- **Capabilities Linux** — Découpage de privilèges traditionnellement associés à root en capacités plus granulaires.
- **Captive portal abuse** — Abus d'un portail captif ou de ses contrôles d'accès.
- **CASB** — Cloud Access Security Broker.
- **CASB** — Contrôle de sécurité entre utilisateurs et applications cloud.
- **CDN** — Content Delivery Network.
- **CDN (Content Delivery Network)** — Réseau de distribution de contenu pouvant aussi offrir filtrage, cache et protection DDoS.
- **Censys** — Plateforme d'observation de services, certificats et actifs Internet.
- **CERT-FR** — Centre gouvernemental français de veille, d'alerte et de réponse aux attaques informatiques.
- **Certificat X.509** — Document numérique liant une identité ou un nom à une clé publique, signé par une autorité de certification ou auto-signé.
- **Certificate pinning** — Vérification applicative d'un certificat ou d'une clé attendue, en complément du modèle normal de confiance ; le mécanisme doit être conçu pour permettre la rotation.
- **Certipy** — Outil d'audit des configurations Active Directory Certificate Services.
- **cgroups** — Contrôle de ressources et regroupement de processus sous Linux.
- **ChaCha20-Poly1305** — Suite cryptographique combinant chiffrement et authentification.
- **Chain of custody** — Documentation des personnes, dates, transferts et opérations ayant concerné une preuve numérique.
- **Chainsaw** — Outil de recherche et de détection dans les journaux Windows EVTX.
- **Checkov** — Outil d'analyse de sécurité pour Infrastructure as Code et configurations cloud.
- **Chiffrement asymétrique** — Utilisation d'une paire de clés publique et privée pour des fonctions comme l'échange de clés ou la signature.
- **Chiffrement au repos** — Protection cryptographique des données stockées.
- **Chiffrement de bout en bout (E2EE)** — Chiffrement où seuls les terminaux prévus détiennent normalement les clés permettant de lire le contenu.
- **Chiffrement en transit** — Protection cryptographique des données pendant leur transport.
- **Chiffrement symétrique** — Chiffrement et déchiffrement à l'aide d'une même clé secrète.
- **CI/CD** — Automatisation de l'intégration, des tests et de la livraison ou du déploiement logiciel.
- **CIA** — Confidentiality, Integrity, Availability : confidentialité, intégrité, disponibilité.
- **CIDR** — Notation décrivant un préfixe réseau et sa longueur, par exemple `/24`.
- **CIS** — Center for Internet Security.
- **CIS Benchmarks** — Guides de configuration sécurisée pour systèmes, logiciels et équipements.
- **CIS Controls** — Ensemble priorisé de mesures pratiques de cybersécurité.
- **Click-to-run / user-assisted execution** — Cas où une action de l'utilisateur est requise avant que du contenu dangereux soit exécuté.
- **Clickjacking** — Tromperie visuelle poussant un utilisateur à interagir avec une interface superposée ou dissimulée.
- **Clickjacking protection** — Mesures telles que `frame-ancestors` ou `X-Frame-Options` qui limitent l'intégration non désirée d'une page dans un cadre.
- **Cloud computing** — Mise à disposition à la demande de ressources informatiques partagées, pilotables par logiciel.
- **Cloud IAM** — Contrôles d'identité et d'autorisation propres à un environnement cloud.
- **Cloud metadata service** — Service local à une instance exposant parfois des métadonnées ou identifiants ; son accès doit être protégé.
- **Cloud misconfiguration** — Paramétrage cloud trop permissif ou incompatible avec le besoin.
- **Cloudsplaining** — Outil d'analyse de risques liés aux permissions IAM cloud dans les contextes pris en charge.
- **CNAPP** — Cloud-Native Application Protection Platform.
- **CNAPP** — Plateforme regroupant plusieurs fonctions de sécurité cloud-native, souvent posture, workloads et risques applicatifs.
- **CNIL** — Autorité française de protection des données personnelles.
- **CoAP** — Protocole Web compact pour environnements contraints et IoT.
- **Cobalt Strike** — Plateforme commerciale de simulation d'adversaire et d'émulation d'attaques.
- **Code review** — Relecture du code pour identifier défauts, risques et problèmes de maintenabilité.
- **CodeQL** — Plateforme d'analyse de code permettant des requêtes de sécurité sur des bases de code.
- **Cold boot attack** — Classe d'attaques exploitant la persistance résiduelle de données en mémoire après une coupure dans certaines conditions.
- **Collecte** — Rassemblement de données intéressant l'attaquant.
- **Command and Control (C2/C&C)** — Canal de communication entre un implant compromis et son opérateur ou son infrastructure de contrôle.
- **Confidentialité** — Propriété empêchant l'accès ou la divulgation non autorisés d'une information.
- **Configuration drift** — Écart progressif entre la configuration réelle et la configuration approuvée.
- **Container** — Unité d'exécution isolée reposant sur des fonctions du système d'exploitation.
- **Containment / confinement** — Mesures visant à limiter la propagation et l'impact d'un incident.
- **Continuité d'activité (PCA)** — Organisation permettant de maintenir les activités prioritaires pendant une perturbation.
- **Contrôle d'accès défaillant** — L'application n'impose pas correctement les droits autorisés pour une ressource ou une action.
- **Contrôle de sécurité** — Mesure technique, organisationnelle ou physique réduisant un risque.
- **Contrôleur de domaine (DC)** — Serveur fournissant les services d'annuaire et d'authentification d'un domaine AD.
- **Cookie** — Petit élément de donnée envoyé par un navigateur au serveur selon des règles de domaine, chemin et sécurité.
- **Corrélation** — Association de plusieurs événements pour révéler un scénario ou une relation significative.
- **CORS (Cross-Origin Resource Sharing)** — Mécanisme du navigateur qui contrôle les requêtes inter-origines autorisées.
- **Cortex** — Moteur d'analyse et d'enrichissement souvent associé à TheHive.
- **Couverture de détection** — Proportion des scénarios, actifs ou techniques attendus effectivement surveillés et testés.
- **Covert channel** — Canal de communication dissimulé dans un protocole ou un comportement normalement utilisé à d'autres fins.
- **Credential phishing** — Hameçonnage conçu spécifiquement pour capturer des identifiants ou jetons.
- **Credential stuffing** — Réutilisation automatisée d'identifiants issus de fuites antérieures sur d'autres services.
- **CRL** — Liste de certificats révoqués publiée par une autorité.
- **CRLF injection** — Insertion de caractères de retour chariot/saut de ligne pour modifier la structure d'un message ou journal.
- **cron / systemd timers** — Mécanismes de planification d'exécution sous Unix/Linux.
- **Cross-Site Request Forgery (CSRF)** — Déclenchement d'une action au nom d'un utilisateur authentifié sans intention valide de sa part.
- **Cross-Site Scripting (XSS)** — Injection de contenu actif dans une page consultée par un utilisateur.
- **CrowdStrike Falcon** — Plateforme commerciale de protection et de détection sur les terminaux.
- **Cryptographic failure** — Usage de cryptographie absente, faible, mal paramétrée ou mal appliquée.
- **Cryptographie** — Techniques mathématiques protégeant les données ou permettant d'assurer intégrité, authenticité et confidentialité.
- **CSIRT** — Computer Security Incident Response Team.
- **CSIRT / CERT** — Équipe de réponse et de coordination des incidents de sécurité.
- **CSP (Content Security Policy)** — Politique navigateur réduisant certains risques de contenu actif, notamment certains XSS.
- **CSPM** — Cloud Security Posture Management.
- **CSPM (Cloud Security Posture Management)** — Détection des mauvaises configurations et écarts de conformité cloud.
- **CSR (Certificate Signing Request)** — Demande de certificat incluant notamment une clé publique et des attributs d'identité.
- **CSRF token** — Valeur imprévisible utilisée pour vérifier qu'une action sensible provient d'un flux attendu.
- **curl / wget** — Clients de transfert HTTP(S) et d'autres protocoles.
- **CVE** — Common Vulnerabilities and Exposures.
- **CVE (Common Vulnerabilities and Exposures)** — Identifiant normalisé d'une vulnérabilité divulguée publiquement.
- **CVSS** — Common Vulnerability Scoring System.
- **CVSS (Common Vulnerability Scoring System)** — Système de notation de la sévérité technique d'une vulnérabilité ; le score ne représente pas à lui seul le risque métier.
- **CWE** — Common Weakness Enumeration.
- **CWE (Common Weakness Enumeration)** — Classification de types de faiblesses logicielles ou matérielles qui peuvent conduire à des vulnérabilités.
- **CWPP (Cloud Workload Protection Platform)** — Protection des charges de travail cloud, par exemple machines virtuelles et conteneurs.
- **Cyber Kill Chain** — Modèle décrivant des phases possibles d'une opération, de la reconnaissance à l'action sur l'objectif.
- **Cyber Resilience Act (CRA)** — Cadre européen portant notamment sur des exigences de cybersécurité de produits comportant des éléments numériques, selon son champ et son calendrier d'application.
- **Cyber threat hunting** — Recherche proactive de signes de compromission dans les données de sécurité, au-delà des seules alertes automatisées.
- **Cyberattaque ciblée** — Opération conçue autour d'une organisation, d'une personne ou d'un objectif déterminé.
- **CyberChef** — Outil web pour transformer, décoder et analyser des données, à utiliser en évitant d'y déposer des données sensibles sans autorisation.
- **Cybercriminel** — Acteur motivé principalement par un gain financier ou un autre avantage criminel.

### D

- **DACL / SACL** — Listes de contrôle d'accès aux permissions et à l'audit dans Windows.
- **Dalfox** — Outil d'audit ciblant notamment les risques XSS.
- **Dark web** — Partie de services accessibles via des réseaux ou logiciels spécifiques, parfois utilisée pour des activités illicites mais pas exclusivement.
- **DAST** — Tests dynamiques d'une application en fonctionnement.
- **Data leakage via LLM** — Risque qu'un modèle ou son environnement divulgue des données confidentielles auxquelles il a accès.
- **Data poisoning** — Corruption volontaire de données d'entraînement, d'indexation ou de référence pour influencer un système.
- **Data tampering** — Modification non autorisée de données en transit ou au repos.
- **DCSync** — Technique simulant certaines fonctions de réplication d'annuaire pour obtenir des données sensibles lorsque les permissions le permettent.
- **DDoS** — Distributed Denial of Service.
- **DDoS (Distributed DoS)** — Déni de service lancé depuis plusieurs systèmes, souvent un botnet.
- **Deauthentication attack** — Envoi abusif de trames de désauthentification pour perturber des connexions Wi-Fi, lorsque les protections sont insuffisantes.
- **Découverte (Discovery)** — Exploration des comptes, systèmes, services et relations présents dans un environnement.
- **Default gateway** — Passerelle utilisée pour joindre les destinations hors du sous-réseau local.
- **Défense en profondeur** — Superposition de plusieurs mesures de sécurité indépendantes afin qu'une seule défaillance ne suffise pas à compromettre l'ensemble.
- **Délai de correction** — Temps entre l'identification d'une vulnérabilité et sa correction ou son traitement accepté.
- **Dependabot** — Fonction d'automatisation de mises à jour de dépendances et de signalement d'avis de sécurité dans les environnements pris en charge.
- **Dependency confusion** — Confusion entre dépendances privées et publiques conduisant à télécharger une dépendance non attendue.
- **Dependency pinning** — Fixation des versions ou empreintes de composants dépendants.
- **Dependency pinning** — Verrouillage de versions ou sommes de contrôle de dépendances pour limiter les variations imprévues.
- **Deserialization vulnerability** — Traitement non sûr de données sérialisées qui peut provoquer altération d'objets, divulgation ou exécution de code.
- **Détection basée sur les signatures** — Détection fondée sur des motifs, empreintes ou règles connus.
- **Détection comportementale** — Détection fondée sur les comportements observés plutôt que sur une seule signature.
- **Detection coverage** — Part des scénarios, techniques ou actifs pour lesquels une détection utile existe et a été testée.
- **Detection engineering** — Conception, test, déploiement et amélioration des règles et capacités de détection.
- **DevSecOps** — Intégration continue de contrôles de sécurité dans les pratiques et pipelines DevOps.
- **DHCP** — Attribution automatique de paramètres de configuration IP.
- **DHCP starvation** — Épuisement du pool d'adresses d'un serveur DHCP par un grand nombre de demandes.
- **Diffie–Hellman / ECDH** — Familles de mécanismes d'établissement de secret partagé.
- **dig / nslookup / host** — Outils d'interrogation DNS.
- **Dirsearch** — Outil de découverte de chemins Web.
- **Disponibilité** — Capacité d'un système ou d'une donnée à être accessible lorsque nécessaire.
- **DKIM** — Signature cryptographique de certains éléments de messages électroniques.
- **DLP** — Contrôles visant à limiter les fuites de données sensibles.
- **DLP** — Data Loss Prevention.
- **DMARC** — Politique de domaine et mécanisme de reporting aidant à traiter les échecs SPF/DKIM et l'usurpation visible.
- **DNP3** — Protocole de télémesure/commande présent dans certains environnements industriels et d'infrastructures.
- **DNS** — Domain Name System.
- **DNS** — Système distribué associant des noms de domaine à des informations, notamment adresses IP.
- **DNS cache poisoning** — Introduction de données DNS malveillantes dans un cache de résolution.
- **DNS spoofing** — Fourniture de réponses DNS falsifiées pour rediriger un client.
- **DNS tunneling** — Encapsulation de données dans des échanges DNS, parfois à des fins de contournement ou d'exfiltration.
- **DNSSEC** — Extensions DNS apportant une validation cryptographique de l'authenticité et de l'intégrité de certaines données DNS.
- **Docker** — Écosystème de construction et d'exécution de conteneurs.
- **DoH (DNS over HTTPS)** — Transport de requêtes DNS dans HTTPS.
- **DOM (Document Object Model)** — Représentation manipulable de la structure d'une page Web.
- **DOM-based XSS** — XSS résultant d'une manipulation dangereuse du DOM côté navigateur.
- **Domaine AD** — Ensemble logique d'objets, comptes et politiques administrés par Active Directory.
- **DORA** — Règlement européen sur la résilience opérationnelle numérique du secteur financier.
- **DoS** — Denial of Service.
- **DoS (Denial of Service)** — Action visant à rendre un service indisponible.
- **DoT (DNS over TLS)** — Transport de requêtes DNS dans TLS.
- **Double extorsion** — Rançongiciel accompagné de vol de données et de menace de publication.
- **Double free** — Libération répétée du même objet mémoire, pouvant conduire à un comportement imprévu.
- **Downgrade attack** — Forcer une communication à utiliser une option de sécurité moins robuste.
- **DPIA / AIPD** — Analyse d'impact relative à la protection des données, requise dans certains traitements à risque élevé selon le RGPD.
- **Drive-by download** — Téléchargement ou tentative d'exécution de contenu indésirable lors de la visite d'une page, souvent via une vulnérabilité ou une interaction trompeuse.
- **DRP / PRA** — Disaster Recovery Plan / plan de reprise d'activité informatique.
- **Due diligence sécurité** — Vérifications effectuées avant une acquisition, un contrat ou une relation fournisseur.
- **Durcissement (hardening)** — Réduction de la surface d'attaque par la désactivation des fonctions inutiles et l'application de configurations sûres.
- **Dwell time** — Durée entre le début d'une compromission et sa détection ou son confinement, selon la définition retenue.
- **Dynamic analysis** — Analyse d'un programme pendant son exécution.

### E

- **EAP** — Cadre d'authentification utilisé notamment avec 802.1X.
- **Eavesdropping** — Écoute d'une communication sans autorisation.
- **ECC (cryptographie sur courbes elliptiques)** — Famille de techniques cryptographiques à clé publique fondées sur les courbes elliptiques.
- **Échange de clés** — Procédure permettant à des parties d'établir un secret partagé.
- **Ed25519 / ECDSA** — Algorithmes de signature numérique.
- **EDR** — Collecte la télémétrie des terminaux et fournit détection et investigation des comportements suspects.
- **EDR** — Endpoint Detection and Response.
- **eIDAS** — Cadre européen concernant l'identification électronique et certains services de confiance.
- **Elastic Security** — Fonctions de détection et d'investigation reposant sur l'écosystème Elastic.
- **Élévation de privilèges** — Obtention de permissions supérieures à celles initialement détenues.
- **Embedding** — Représentation numérique d'un contenu dans un espace vectoriel.
- **Endpoint** — Poste, serveur ou appareil en bout de réseau.
- **Enum4linux-ng** — Outil d'énumération de services SMB/Samba dans un contexte de test.
- **EPP** — Endpoint Protection Platform.
- **EPSS** — Estimation probabiliste de la possibilité qu'une vulnérabilité soit exploitée dans la nature.
- **Éradication** — Suppression de la cause et des composants malveillants identifiés.
- **Eric Zimmerman Tools** — Collection d'utilitaires utilisés pour analyser des artefacts Windows.
- **Escalade** — Transmission d'une alerte ou d'un incident à une équipe de niveau ou de responsabilité supérieure.
- **État-nation** — Acteur étatique ou soutenu par un État, souvent doté de ressources et d'objectifs stratégiques.
- **Ethernet (IEEE 802.3)** — Technologie réseau filaire de couche liaison.
- **Évasion de défense** — Actions destinées à éviter ou contourner les dispositifs de sécurité.
- **Événement de sécurité** — Fait observable ; il n'est pas nécessairement malveillant ni un incident.
- **Exception de sécurité** — Acceptation temporaire et documentée d'un risque, avec propriétaire, justification et échéance.
- **Exécution** — Lancement de commandes ou de code sur un système.
- **Exfiltration** — Extraction de données hors du périmètre sans autorisation.
- **Exfiltration** — Sortie non autorisée de données hors de l'environnement ciblé.
- **Exploit** — Code, séquence ou procédé qui tire parti d'une vulnérabilité.
- **Exploit chain** — Enchaînement de plusieurs faiblesses ou actions permettant d'atteindre un impact supérieur.
- **Exploit kit** — Ensemble de composants qui tente d'identifier puis d'exploiter des vulnérabilités côté client ; terme surtout associé à des campagnes historiques et actuelles selon les contextes.
- **Exploitability** — Facilité pratique avec laquelle une vulnérabilité peut être exploitée dans un contexte donné.
- **Exposition** — Degré auquel un actif est accessible à une menace, directement ou indirectement.

### F

- **FaaS / serverless** — Exécution de fonctions gérée par un fournisseur, avec infrastructure sous-jacente largement abstraite.
- **Falco** — Outil de détection de comportements au niveau système, notamment dans des environnements cloud-native.
- **Fault injection** — Perturbation physique ou logique d'un composant pour provoquer un comportement exploitable.
- **Faux négatif** — Activité malveillante qui n'est pas détectée par le contrôle.
- **Faux positif** — Alerte ou détection signalant à tort une activité malveillante.
- **Feroxbuster** — Outil de découverte de contenu Web.
- **ffuf** — Outil de fuzzing Web destiné à tester des chemins, paramètres ou valeurs d'entrée.
- **FIDO2 / WebAuthn** — Standards d'authentification résistante au phishing basés sur des clés cryptographiques.
- **File integrity monitoring (FIM)** — Surveillance de changements inattendus sur des fichiers et configurations critiques.
- **File upload vulnerability** — Téléversement de fichiers dont le type, le contenu, le nom ou le stockage ne sont pas contrôlés correctement.
- **Fileless malware** — Activité malveillante s'appuyant principalement sur des mécanismes en mémoire ou des outils natifs plutôt que sur un fichier traditionnel.
- **FIM** — File Integrity Monitoring.
- **FIM** — Surveillance des modifications de fichiers critiques.
- **Firewall evasion** — Tentatives de faire passer un trafic à travers des règles de filtrage inadéquates.
- **Firmware** — Logiciel intégré à un appareil ou composant matériel.
- **Forensique numérique / DFIR** — Collecte, préservation, analyse et interprétation de preuves numériques, souvent dans le cadre d'une réponse à incident.
- **Forêt AD** — Limite logique supérieure regroupant des domaines Active Directory partageant un schéma et des relations de confiance.
- **Format string vulnerability** — Utilisation non sûre d'une chaîne de format contrôlée par une source non fiable.
- **Fragmentation IP** — Division d'un paquet en fragments selon le protocole et le chemin réseau.
- **Fraude au paiement** — Manipulation de paiement, de compte fournisseur, d'IBAN ou de processus de validation.
- **Fraude au président** — Variante de BEC où le fraudeur usurpe un dirigeant afin d'obtenir un virement ou une opération confidentielle.
- **Frida** — Instrumentation dynamique de processus, utilisée notamment pour déboguer et auditer des applications.
- **FTK Imager** — Outil d'acquisition et d'examen de preuves numériques.
- **FTP** — Protocole de transfert de fichiers historique ; le FTP classique ne chiffre pas le trafic.
- **FTPS** — FTP utilisant TLS.
- **Fuzz testing / fuzzing** — Génération de nombreuses entrées afin de découvrir des plantages, anomalies ou faiblesses.

### G

- **GDB / WinDbg** — Débogueurs utilisés pour examiner l'exécution de programmes.
- **Ghidra** — Suite d'ingénierie inverse de logiciels.
- **Gitleaks** — Outil de détection de secrets exposés dans des dépôts Git.
- **GMSA** — Compte de service géré de groupe, conçu pour gérer automatiquement des mots de passe de comptes de service.
- **gNMI / NETCONF / RESTCONF** — Interfaces de gestion et de configuration d'équipements réseau.
- **Gobuster** — Outil de découverte de répertoires, fichiers et ressources de services dans des audits autorisés.
- **Golden Ticket** — Concept d'attaque impliquant la création frauduleuse de tickets Kerberos à partir d'un secret critique du domaine.
- **Google Security Operations** — Plateforme de sécurité incluant des fonctions SIEM et d'investigation.
- **GPO (Group Policy Object)** — Ensemble de paramètres appliqués aux utilisateurs ou ordinateurs Windows.
- **GraphQL** — Langage de requête et environnement d'exécution pour interroger des données à travers une API.
- **GRC** — Governance, Risk and Compliance.
- **GRE** — Protocole d'encapsulation de paquets, qui n'assure pas à lui seul le chiffrement.
- **Greenbone / OpenVAS / GVM** — Écosystème d'analyse de vulnérabilités et de gestion des scans.
- **Group3r** — Outil d'audit de paramètres de stratégies de groupe dans certains environnements Windows.
- **gRPC** — Appels distants fréquemment utilisés dans les architectures de services.
- **gRPC** — Cadre d'appels distants utilisant généralement HTTP/2 et Protocol Buffers.
- **GRR Rapid Response** — Cadre de réponse à incident et d'investigation à distance.
- **Grype** — Scanner de vulnérabilités pour images, fichiers et SBOM compatibles.
- **Guardrail** — Contrôle logiciel ou organisationnel destiné à limiter des sorties ou actions indésirables ; il ne constitue pas une garantie absolue.
- **GVM feed** — Flux de tests et de données alimentant les scans dans l'écosystème Greenbone.

### H

- **Hachage (hashing)** — Calcul d'une empreinte de taille fixe à partir de données ; le hachage seul n'est pas un chiffrement réversible.
- **Hacktiviste** — Acteur utilisant des opérations numériques pour promouvoir une cause politique ou sociale.
- **Hardcoded credentials** — Secrets intégrés directement au code, à l'image ou à la configuration.
- **Hardware root of trust** — Base matérielle utilisée pour ancrer des vérifications de confiance.
- **Hash d'intégrité** — Empreinte utilisée pour vérifier qu'une copie ou un élément n'a pas changé.
- **Hashcat** — Outil de vérification de robustesse de secrets par calcul intensif hors ligne.
- **HIDS / HIPS** — Détection ou prévention d'intrusions sur un hôte.
- **HMAC** — Code d'authentification de message basé sur un hash et une clé secrète.
- **HMI / IHM** — Interface opérateur d'un système industriel.
- **Homoglyph attack** — Utilisation de caractères visuellement similaires mais techniquement différents pour tromper l'utilisateur.
- **Honeynet** — Ensemble de leurres interconnectés permettant d'observer des comportements.
- **Honeypot** — Système leurre conçu pour observer des activités ou attirer des tentatives d'accès.
- **HSM (Hardware Security Module)** — Matériel conçu pour protéger des clés et réaliser certaines opérations cryptographiques.
- **HSTS** — Directive demandant au navigateur de n'utiliser que HTTPS pour un domaine pendant une période.
- **HTTP / HTTPS** — Protocoles Web, HTTPS ajoutant une protection TLS.
- **HTTP request smuggling** — Désaccord d'interprétation des frontières de requêtes HTTP entre composants intermédiaires et serveur.
- **HTTP response splitting** — Injection de séparateurs de réponse dans un contexte HTTP mal protégé.
- **HTTP Toolkit** — Outil d'observation et de débogage du trafic HTTP(S).
- **HTTP/1.1, HTTP/2, HTTP/3** — Versions de HTTP avec différences de multiplexage et de transport ; HTTP/3 utilise QUIC.
- **HttpOnly** — Attribut de cookie qui empêche l'accès direct au cookie depuis les scripts côté navigateur.
- **Hydra** — Outil de test de robustesse des authentifications réseau ; à utiliser uniquement avec autorisation explicite.
- **Hypothèse de chasse** — Question testable utilisée pour guider une investigation proactive.

### I

- **IA générative** — Système produisant du contenu à partir de modèles appris.
- **IaaS** — Infrastructure à la demande : machines virtuelles, réseaux et stockage.
- **IAM** — Identity and Access Management.
- **IAM (Identity and Access Management)** — Gestion du cycle de vie des identités et de leurs autorisations.
- **IAST** — Instrumentation d'une application en fonctionnement pour observer des vulnérabilités pendant les tests.
- **IBM QRadar** — Plateforme SIEM.
- **ICMP / ICMPv6** — Protocoles de messages d'erreur et de diagnostic associés à IP.
- **ICMP abuse** — Usage abusif de messages ICMP à des fins de reconnaissance, de perturbation ou de tunnelisation.
- **ICS** — Industrial Control Systems.
- **ICS** — Systèmes de contrôle industriel.
- **IDA** — Désassembleur et environnement d'analyse de binaires.
- **IDOR (Insecure Direct Object Reference)** — Accès à un objet en modifiant un identifiant, faute de vérification d'autorisation adéquate.
- **IdP (Identity Provider)** — Service qui authentifie des utilisateurs et fournit des assertions ou jetons d'identité.
- **IDS** — Système détectant du trafic ou des comportements suspects.
- **IDS / IPS** — Intrusion Detection System / Intrusion Prevention System.
- **IEC 62443** — Famille de normes de cybersécurité des systèmes d'automatisation et de contrôle industriel.
- **IGA (Identity Governance and Administration)** — Gouvernance des identités, demandes d'accès, certifications et séparation des tâches.
- **Image de conteneur** — Modèle utilisé pour créer un conteneur ; elle doit être versionnée, signée si possible et analysée.
- **Image disque** — Copie bit à bit d'un support ou d'une partition, selon la méthode employée.
- **IMAP** — Protocole d'accès et de gestion des courriels sur un serveur.
- **Impacket** — Collection Python de bibliothèques et d'outils pour protocoles réseau, notamment en environnements Windows.
- **Impact** — Actions affectant la disponibilité, l'intégrité ou la confiance dans les systèmes et données.
- **Impact** — Conséquence d'un incident : perte financière, indisponibilité, fuite de données, atteinte à la réputation ou risque humain.
- **Improper certificate validation** — Vérification insuffisante de la chaîne, du nom ou du statut d'un certificat.
- **Improper input validation** — Validation insuffisante des données reçues.
- **Improper output encoding** — Encodage de sortie inadéquat qui permet à des données de changer de contexte d'interprétation.
- **Incident de sécurité** — Événement confirmé ou suspect susceptible de compromettre des actifs ou des données.
- **Indicateur d'attaque (IOA)** — Comportement ou séquence d'actions pouvant révéler une attaque, même si l'artefact change.
- **Indicateur de compromission (IOC)** — Artefact pouvant signaler une compromission : hash, domaine, adresse IP, chemin, clé de registre, etc. Un IOC isolé ne prouve pas toujours une attaque.
- **Indirect prompt injection** — Instructions malveillantes présentes dans des contenus consultés par le modèle, comme des documents, pages ou courriels.
- **Infection Monkey** — Outil de simulation de propagation et d'évaluation de segmentation dans un environnement contrôlé.
- **Information disclosure** — Divulgation d'informations sensibles par une réponse, un journal, une erreur ou un fichier.
- **Infrastructure as Code (IaC)** — Description versionnée et automatisable de l'infrastructure, par exemple par fichiers déclaratifs.
- **Infrastructure d'attaque** — Domaines, serveurs, comptes, relais et autres ressources utilisés pour une opération.
- **Ingénierie sociale** — Manipulation de personnes pour provoquer une action, divulguer une information ou contourner une procédure.
- **Injection** — Données contrôlées par l'utilisateur interprétées comme des commandes ou instructions par un autre composant.
- **Insecure direct object reference** — Voir IDOR : référence directe à une ressource sans validation correcte des droits.
- **Insecure randomness** — Génération de valeurs prévisibles utilisées pour des secrets, jetons ou identifiants.
- **Insider / menace interne** — Risque provenant d'une personne ayant un accès légitime ou privilégié, volontairement ou non.
- **Insufficient entropy** — Manque d'imprévisibilité dans un secret ou une valeur aléatoire.
- **Integer overflow / underflow** — Dépassement de la plage représentable par un entier, susceptible de produire un comportement inattendu.
- **Intégrité** — Propriété garantissant que les données et systèmes ne sont modifiés que de manière autorisée.
- **IoC / IOC** — Indicator of Compromise.
- **IOC extraction** — Extraction d'indicateurs tels que hashes, domaines, chemins ou clés à partir d'un échantillon ou d'une enquête.
- **IoT** — Internet of Things.
- **IoT (Internet of Things)** — Appareils connectés et systèmes qui collectent ou échangent des données.
- **IP spoofing** — Falsification de l'adresse IP source d'un paquet.
- **IPS** — Système capable de bloquer des activités détectées selon ses règles et son mode de déploiement.
- **IPsec** — Internet Protocol Security.
- **IPsec** — Suite de protocoles de sécurité pour IP.
- **IPv4 / IPv6** — Versions du protocole Internet utilisant des espaces d'adressage différents.
- **IR** — Incident Response.
- **IS-IS** — Protocole de routage interne à état de liens.
- **ISAC** — Information Sharing and Analysis Center.
- **ISMS / SMSI** — Information Security Management System / système de management de la sécurité de l'information.
- **ISO 22301** — Norme de management de la continuité d'activité.
- **ISO/IEC 27001** — Norme d'exigences pour un système de management de la sécurité de l'information.
- **ISO/IEC 27002** — Référentiel de mesures de sécurité de l'information.
- **ISO/IEC 27005** — Norme de gestion des risques liés à la sécurité de l'information.

### J

- **Jailbreak** — Tentative de contourner les restrictions ou consignes d'un modèle.
- **Jailbreak / rooting** — Suppression de certaines restrictions de sécurité d'un appareil iOS ou Android.
- **John the Ripper** — Outil d'audit de robustesse de mots de passe par tests hors ligne.
- **Journal / log** — Enregistrement horodaté d'un événement produit par un système ou une application.
- **JWE** — Format de chiffrement de contenu JSON Web.
- **JWS** — Format de signature ou d'authentification de contenu JSON Web.
- **JWT (JSON Web Token)** — Format de jeton contenant des claims, souvent signé ou authentifié ; un JWT signé n'est pas nécessairement chiffré.

### K

- **KAPE** — Outil de collecte et de traitement d'artefacts Windows.
- **KDF (Key Derivation Function)** — Fonction dérivant une ou plusieurs clés depuis un secret ou un matériau initial.
- **Kerberoasting** — Technique d'audit/attaque visant les tickets de service Kerberos afin de tenter de retrouver hors ligne le secret d'un compte de service faible.
- **Kerberos** — Authentification par tickets.
- **Kerberos** — Protocole d'authentification par tickets, utilisé notamment par Active Directory.
- **Kerbrute** — Outil de vérification/énumération liée à Kerberos ; peut générer des événements d'authentification.
- **KEV (Known Exploited Vulnerabilities)** — Catalogue des vulnérabilités dont l'exploitation active est connue, notamment le catalogue publié par la CISA.
- **Keylogger** — Outil ou composant enregistrant les frappes clavier.
- **Kismet** — Outil de surveillance et de découverte de réseaux sans fil.
- **Kiterunner** — Outil de découverte et de test de routes API.
- **KMS** — Key Management Service.
- **KMS (Key Management Service)** — Service de gestion de clés cryptographiques et de leur cycle de vie.
- **KPI / KRI** — Key Performance Indicator / Key Risk Indicator.
- **KRACK** — Nom donné à une famille de faiblesses historiques dans le protocole WPA2 ; les correctifs et le contexte exact déterminent l'exposition.
- **kube-bench** — Vérification de certains contrôles de configuration Kubernetes selon le référentiel CIS.
- **kube-hunter** — Outil d'identification de certains risques d'exposition Kubernetes dans des environnements autorisés.
- **Kubernetes (K8s)** — Plateforme d'orchestration de conteneurs.
- **Kubescape** — Outil d'analyse de posture et de conformité Kubernetes.

### L

- **LACP (802.1AX)** — Négociation d'agrégation de liens réseau.
- **LAPS** — Solution de gestion des mots de passe administrateur locaux sur les postes et serveurs Windows.
- **LaZagne** — Outil de recherche de secrets stockés localement, utile dans des audits encadrés.
- **LDAP** — Protocole d'accès aux services d'annuaire.
- **LDAP / LDAPS** — Protocole d'annuaire, avec TLS pour la variante sécurisée couramment appelée LDAPS.
- **LDAP injection** — Altération d'une requête LDAP par des données non neutralisées.
- **ldapsearch** — Utilitaire de requête d'annuaires LDAP.
- **Lessons learned** — Améliorations issues du retour d'expérience.
- **Living off the Land (LotL)** — Utilisation d'outils natifs et légitimes du système pour réaliser des actions qui peuvent être malveillantes.
- **LLDP** — Protocole de découverte des équipements voisins.
- **LLM (Large Language Model)** — Modèle de langage entraîné sur de grands ensembles de données.
- **Load balancer** — Répartiteur de trafic entre plusieurs serveurs ou instances.
- **Loader / dropper** — Composant chargé d'installer ou de lancer une autre charge utile.
- **Local File Inclusion (LFI)** — Inclusion non sûre de fichiers présents localement.
- **Local Privilege Escalation (LPE)** — Obtention de privilèges supérieurs à partir d'un accès local limité.
- **LOLBin** — Binaire système légitime potentiellement détourné pour exécuter une activité non autorisée.
- **Lookalike domain** — Domaine ressemblant visuellement à un domaine légitime, parfois par substitution de caractères.
- **LSASS** — Processus Windows gérant notamment des fonctions d'authentification ; une cible sensible pour les secrets en mémoire.

### M

- **MAC flooding** — Surcharge de la table d'adresses d'un commutateur pour perturber son comportement de commutation.
- **MAC spoofing** — Usurpation d'une adresse MAC.
- **Malicious package** — Dépendance logicielle contenant volontairement du code malveillant.
- **Maltego** — Outil d'analyse de liens entre entités et données OSINT.
- **Malvertising** — Diffusion de contenu malveillant au travers de publicités en ligne.
- **Malware** — Logiciel ou code conçu pour réaliser des actions malveillantes.
- **MalwareBazaar** — Référentiel communautaire d'échantillons de malwares, soumis à ses règles d'accès et d'usage.
- **Man-in-the-Browser** — Compromission du navigateur permettant d'altérer une transaction ou d'observer des données.
- **Man-in-the-Middle (MitM)** — Interception et éventuellement modification d'une communication entre deux parties.
- **Mass assignment** — Liaison automatique de champs de données à un objet sans liste explicite des champs modifiables.
- **Masscan** — Scanner de ports conçu pour balayer de très grands espaces d'adresses à haut débit.
- **MASTG** — OWASP Mobile Application Security Testing Guide.
- **MASVS** — OWASP Mobile Application Security Verification Standard.
- **Mauvaise configuration** — Paramètres trop permissifs, inutiles, incohérents ou dangereux.
- **MD5 / SHA-1** — Fonctions de hashage historiques à ne pas choisir pour de nouveaux usages exigeant une résistance moderne aux collisions.
- **MDM/UEM** — Gestion centralisée des appareils mobiles ou de l'ensemble des terminaux d'entreprise.
- **MDR** — Managed Detection and Response.
- **MDR** — Service managé de détection et réponse, généralement assuré par un prestataire.
- **Membership inference** — Tentative d'estimer si une donnée particulière faisait partie des données d'entraînement d'un modèle.
- **Mémoire volatile** — Données présentes en RAM, susceptibles de disparaître à l'arrêt ou au redémarrage.
- **Memory corruption** — Altération inattendue de la mémoire d'un processus.
- **Memory forensics** — Analyse de la mémoire vive pour identifier processus, connexions, modules et artefacts.
- **Menace** — Cause potentielle d'un incident, intentionnelle ou accidentelle.
- **Mesure compensatoire** — Contrôle alternatif qui réduit le risque lorsqu'une mesure standard n'est pas applicable.
- **Metasploit Framework** — Cadre modulaire pour valider des vulnérabilités et conduire des tests d'intrusion autorisés.
- **MFA** — Authentification multifacteur reposant sur au moins deux facteurs distincts.
- **MFA** — Multi-Factor Authentication.
- **MFA fatigue / push bombing** — Multiplication de demandes d'approbation d'authentification pour pousser l'utilisateur à en accepter une.
- **MFA résistante au phishing** — Authentification liée au service ou à l'origine, réduisant les risques de relais de codes ou de pages d'imitation.
- **Microsoft Defender for Endpoint** — Solution de sécurité et d'investigation des terminaux Microsoft.
- **Microsoft Sentinel** — SIEM et plateforme d'orchestration/automatisation de sécurité cloud de Microsoft.
- **Mimikatz** — Outil de recherche et de démonstration de techniques relatives aux secrets et mécanismes d'authentification Windows ; fortement sensible en contexte réel.
- **MISP** — Plateforme de partage, de corrélation et de gestion d'indicateurs de menace.
- **MITM / MitM** — Man-in-the-Middle.
- **mitmproxy** — Proxy d'interception HTTP(S) destiné à l'analyse et au débogage dans un environnement autorisé.
- **MITRE ATT&CK** — Base de connaissances des tactiques, techniques et sous-techniques observées dans des attaques réelles.
- **MITRE ATT&CK** — Référentiel des comportements adverses utilisé pour la détection, l'analyse et les exercices.
- **MITRE ATT&CK mapping** — Association d'observations ou de détections à des techniques ATT&CK.
- **MITRE CALDERA** — Plateforme d'émulation d'adversaire basée sur ATT&CK.
- **Mobile application security** — Protection des applications mobiles, de leur stockage local, communications, authentification et intégration avec le système.
- **MobSF (Mobile Security Framework)** — Plateforme d'analyse statique et dynamique d'applications mobiles dans les environnements pris en charge.
- **Modbus** — Protocole industriel historique de communication entre équipements.
- **Model extraction** — Tentative de reconstituer un modèle ou son comportement à partir de requêtes et de réponses.
- **Model inversion** — Famille de techniques visant à inférer des informations sensibles depuis un modèle ou ses sorties.
- **Model poisoning** — Altération des données ou d'étapes d'entraînement pour influencer le comportement d'un modèle.
- **Model supply chain** — Chaîne de provenance des modèles, jeux de données, poids, dépendances et outils d'entraînement/déploiement.
- **Modèle de menace** — Représentation structurée des actifs, adversaires, frontières de confiance, chemins d'attaque et mesures de protection.
- **Modèle OSI** — Modèle de référence en sept couches : physique, liaison, réseau, transport, session, présentation et application.
- **Moindre privilège** — Attribution des droits strictement nécessaires à une tâche, pour la durée nécessaire.
- **Mouvement latéral** — Passage d'un système compromis à d'autres systèmes du même environnement.
- **MPLS** — Technologie de transfert réseau fondée sur des étiquettes.
- **MQTT** — Protocole léger de messagerie souvent utilisé pour l'IoT.
- **MTA-STS** — Mécanisme aidant à imposer TLS pour certains échanges SMTP entrants.
- **MTTC** — Temps moyen nécessaire pour contenir un incident ; ce sigle est moins uniformément utilisé que MTTD/MTTR.
- **MTTD** — Durée moyenne entre le début d'un incident et sa détection, selon les bornes de mesure retenues.
- **MTTD** — Mean Time to Detect.
- **MTTD** — Temps moyen de détection d'un incident.
- **MTTR** — Acronyme pouvant désigner le temps moyen de réponse ou de réparation ; préciser la définition dans les rapports.
- **MTTR** — Mean Time to Respond/Repair/Recover, selon la définition adoptée.
- **MTTR** — Temps moyen de réponse, de réparation ou de rétablissement selon la définition interne ; toujours expliciter la signification.
- **MTU** — Taille maximale d'un paquet ou d'une trame selon le contexte de couche.
- **MTU black hole** — Problème réseau où des paquets trop grands sont bloqués sans signalement exploitable, pouvant casser certaines communications.
- **Mutation testing** — Évaluation de l'efficacité des tests en introduisant des changements artificiels dans le code.

### N

- **N-day** — Vulnérabilité connue depuis un certain temps, souvent déjà corrigée mais encore présente sur des systèmes non mis à jour.
- **Naabu** — Outil de découverte de ports utilisé dans certains workflows de reconnaissance.
- **NAC** — Contrôle des appareils autorisés à se connecter à un réseau.
- **NAC** — Network Access Control.
- **NAC bypass** — Contournement possible de contrôles d'accès réseau insuffisants.
- **Namespace Kubernetes** — Regroupement logique de ressources dans un cluster ; ce n'est pas à lui seul une frontière de sécurité forte.
- **Namespaces Linux** — Isolation de vues de ressources système, utilisée notamment par les conteneurs.
- **NAT** — Traduction d'adresses réseau entre espaces d'adressage.
- **NDP** — Mécanismes IPv6 de découverte de voisins et de routeurs.
- **NDR** — Détection et investigation à partir de données réseau.
- **NDR** — Network Detection and Response.
- **Nessus** — Scanner commercial de vulnérabilités et de configurations.
- **Netcat / Ncat / socat** — Utilitaires génériques de communication réseau et de diagnostic.
- **NetExec** — Cadre d'audit d'environnements réseau et Windows, notamment pour des contrôles d'authentification et de configuration autorisés.
- **NetFlow / IPFIX / sFlow** — Formats ou méthodes d'export de métadonnées sur les flux réseau.
- **Network segmentation bypass** — Contournement de contrôles censés isoler des zones réseau.
- **NetworkPolicy** — Règles limitant les flux réseau entre pods dans un cluster compatible.
- **NFS** — Protocole de partage de fichiers réseau fréquent dans les environnements Unix/Linux.
- **Nikto** — Scanner de serveur Web recherchant notamment des configurations et fichiers risqués.
- **NIS2** — Directive européenne visant à renforcer les exigences de cybersécurité et la gestion des incidents dans des entités et secteurs couverts.
- **NIST** — National Institute of Standards and Technology.
- **NIST Cybersecurity Framework (CSF)** — Cadre de gestion des risques cyber ; sa version 2.0 organise les résultats autour de six fonctions, dont Govern.
- **NIST SP 800-53** — Catalogue de contrôles de sécurité et de confidentialité.
- **NIST SP 800-61** — Référence de gestion et de réponse aux incidents de sécurité informatique ; consulter la révision applicable la plus récente.
- **Niveau 1 / L1** — Triage initial des alertes, collecte de contexte et escalade selon les procédures.
- **Niveau 2 / L2** — Investigation approfondie, corrélation et qualification technique.
- **Niveau 3 / L3** — Expertise avancée, détection, réponse complexe, ingénierie et chasse aux menaces.
- **Nmap** — Découverte d'hôtes et de services, scan de ports et collecte de métadonnées réseau.
- **Nonce** — Valeur utilisée une seule fois ou destinée à éviter la réutilisation dangereuse d'un échange.
- **NoSQL injection** — Manipulation d'une requête ou d'un opérateur dans une base NoSQL.
- **Notification de violation de données** — Obligation éventuelle d'informer l'autorité ou les personnes concernées en cas de violation de données personnelles, selon la loi applicable et les circonstances.
- **NTLM** — Famille historique de mécanismes d'authentification Windows ; à limiter lorsque possible au profit de mécanismes plus modernes.
- **NTP** — Network Time Protocol.
- **NTP** — Synchronisation de l'heure des systèmes.
- **Nuclei** — Moteur de détection utilisant des modèles de tests versionnés.
- **Null pointer dereference** — Accès à travers un pointeur nul entraînant souvent un plantage.

### O

- **OAuth 2.0** — Cadre de délégation d'autorisation permettant à une application d'obtenir un accès limité à des ressources.
- **Objection** — Outil basé sur Frida facilitant certaines tâches de test mobile autorisées.
- **OCSP** — Protocole permettant d'interroger le statut de révocation d'un certificat.
- **OIDC** — OpenID Connect.
- **On-path attack** — Attaque où l'adversaire est placé sur le chemin de communication et peut observer ou modifier le trafic.
- **OPC UA** — Architecture de communication et d'interopérabilité largement utilisée en automatisation industrielle.
- **Open redirect** — Redirection vers une destination externe contrôlée par l'utilisateur sans garde-fou suffisant.
- **OpenCTI** — Plateforme de gestion et de contextualisation du renseignement sur les menaces.
- **OpenID Connect (OIDC)** — Couche d'identité au-dessus d'OAuth 2.0 utilisée pour l'authentification fédérée.
- **OpenPGP / PGP** — Standards et outils de chiffrement et signature à clé publique.
- **OpenVPN** — Solution VPN s'appuyant sur TLS et des composants réseau associés.
- **Opportuniste** — Attaquant qui vise des cibles en fonction de leur exposition ou de faiblesses faciles à exploiter.
- **OpSec (Operational Security)** — Pratiques limitant les informations que les actions d'un opérateur révèlent sur lui ou son opération.
- **OS command injection** — Données non fiables interprétées comme une commande système.
- **OSINT** — Open Source Intelligence.
- **OSINT (Open Source Intelligence)** — Collecte et analyse d'informations provenant de sources ouvertes et légalement accessibles.
- **OSPF** — Protocole de routage interne fondé sur l'état des liens.
- **osquery** — Outil d'interrogation de l'état d'un système par une interface de type SQL.
- **OT** — Operational Technology.
- **OT (Operational Technology)** — Systèmes qui surveillent ou commandent des processus physiques.
- **Out-of-bounds read/write** — Lecture ou écriture hors des limites mémoire attendues.
- **OWASP** — Organisation communautaire qui publie des référentiels et outils liés à la sécurité applicative.
- **OWASP API Security Top 10** — Référentiel ciblant les risques de sécurité propres aux API.
- **OWASP ASVS** — Référentiel de vérification de sécurité applicative.
- **OWASP Top 10** — Liste de sensibilisation aux risques majeurs des applications Web ; la version de référence actuelle au moment de la rédaction est l'édition 2025.
- **OWASP WSTG** — Guide méthodologique de test de sécurité des applications Web.
- **OWASP ZAP** — Proxy et plateforme de test Web, particulièrement utilisée pour l'apprentissage et l'automatisation.

### P

- **PaaS** — Plateforme gérée qui réduit la gestion de l'infrastructure sous-jacente.
- **Packers / obfuscation** — Techniques transformant ou masquant un binaire ou son code, parfois pour réduire la détection.
- **Packet sniffing** — Capture et observation de paquets réseau.
- **Palo Alto Cortex XDR** — Plateforme de détection et de réponse étendues.
- **PAM** — Privileged Access Management, ou Pluggable Authentication Modules sous Linux selon le contexte.
- **PAM (Pluggable Authentication Modules)** — Architecture modulaire d'authentification sous Unix/Linux.
- **PAM (Privileged Access Management)** — Contrôles dédiés aux comptes, sessions et secrets privilégiés.
- **Pass-the-Hash** — Utilisation d'un matériau d'authentification dérivé d'un mot de passe à la place du mot de passe en clair, dans les protocoles qui le permettent.
- **Pass-the-Ticket** — Réutilisation d'un ticket Kerberos obtenu ou volé.
- **Passkey** — Identifiant basé sur une clé cryptographique, généralement utilisable via l'authentificateur d'un appareil.
- **Password spraying** — Essai d'un petit nombre de mots de passe courants sur un grand nombre de comptes.
- **PAT / NAT overload** — Traduction de plusieurs flux via une ou plusieurs adresses, différenciés notamment par les ports.
- **Patch** — Mise à jour corrigeant une anomalie, une faiblesse ou une vulnérabilité.
- **Patch management** — Processus d'inventaire, de priorisation, de test et de déploiement des correctifs.
- **Patching** — Application de correctifs au système d'exploitation et aux logiciels.
- **Path traversal / directory traversal** — Accès à des chemins situés en dehors du répertoire autorisé par manipulation de chemins.
- **Payload / charge utile** — Partie d'un code ou d'une requête qui porte la fonction principale.
- **PCA / PRA** — Plan de continuité d'activité / plan de reprise d'activité.
- **PCI DSS** — Standard de sécurité applicable aux environnements traitant des données de cartes de paiement.
- **Pentest / test d'intrusion** — Test encadré visant à démontrer l'exploitabilité de faiblesses dans un périmètre autorisé.
- **Pepper** — Secret additionnel conservé séparément des hashes de mots de passe.
- **Perfect Forward Secrecy (PFS)** — Propriété limitant l'impact sur les sessions passées de la compromission ultérieure d'une clé à long terme, si les conditions cryptographiques sont réunies.
- **Périmètre (scope)** — Systèmes, adresses, comptes, applications et actions compris dans un audit ou un test.
- **Persistance** — Capacité à conserver un accès après une déconnexion, un redémarrage ou une action de nettoyage.
- **Phantom** — Nom historique associé aux capacités SOAR de Splunk.
- **Pharming** — Redirection vers un site frauduleux, par manipulation de résolution de nom ou d'autres mécanismes.
- **Phishing / hameçonnage** — Message trompeur conçu pour voler des identifiants, pousser au paiement, ouvrir une pièce jointe ou faire exécuter une action.
- **Ping sweep** — Sondage de plusieurs adresses pour repérer des hôtes qui répondent.
- **PingCastle** — Outil d'évaluation de posture et de risques Active Directory.
- **PKI (Public Key Infrastructure)** — Infrastructure de gestion des certificats, autorités de certification, clés et règles de confiance.
- **PKI / ICP** — Public Key Infrastructure / infrastructure à clés publiques.
- **Plaso / log2timeline** — Outils de construction de chronologies à partir de multiples sources forensiques.
- **Playbook** — Procédure structurée de traitement d'une alerte ou d'un incident.
- **Playbook ransomware** — Procédure spécifique de traitement d'une suspicion ou confirmation de rançongiciel.
- **PLC / API industriel** — Automate programmable contrôlant une machine ou un procédé.
- **PoC** — Proof of Concept.
- **PoC (Proof of Concept)** — Démonstration minimale permettant d'illustrer l'existence d'une faiblesse ; ce n'est pas nécessairement un outil complet d'exploitation.
- **Pod** — Plus petite unité déployable dans Kubernetes, pouvant contenir un ou plusieurs conteneurs.
- **Policy as Code** — Expression et contrôle automatisés de règles de conformité ou de sécurité.
- **Politique de sécurité** — Document fixant les principes et exigences de sécurité d'une organisation.
- **Polymorphic malware** — Malware modifiant sa représentation pour compliquer la détection basée sur signatures.
- **POP3** — Protocole de récupération de courriels.
- **Port** — Numéro logique identifiant un point de terminaison de transport.
- **Port scanning** — Sondage de ports pour identifier des services accessibles.
- **Post-mortem / retour d'expérience** — Analyse après incident visant à comprendre ce qui s'est produit et prévenir la répétition.
- **Postman / Insomnia** — Clients pour concevoir, envoyer et tester des requêtes API ; ce ne sont pas à eux seuls des scanners de sécurité.
- **PowerShell logging** — Journalisation des activités PowerShell, utile pour enquêter sur les commandes et scripts.
- **Prelude Operator** — Plateforme commerciale de simulation d'attaques et de validation de contrôles.
- **Pretexting** — Invention d'un scénario crédible pour obtenir une information ou une action.
- **PrivescCheck** — Script d'aide à l'examen de configurations Windows.
- **Probabilité / vraisemblance** — Estimation de la possibilité qu'un scénario se produise dans un contexte défini.
- **Process Explorer** — Outil Windows d'inspection des processus et handles.
- **Process Monitor (Procmon)** — Outil d'observation d'activités fichiers, registre, processus et threads sous Windows.
- **Procmon** — Voir Process Monitor, outil de suivi d'activités sous Windows.
- **Prompt injection** — Entrée conçue pour pousser un modèle ou une application utilisant un modèle à ignorer les instructions prévues ou à agir d'une manière non autorisée.
- **Proofpoint / Mimecast** — Exemples de familles de solutions centrées notamment sur la sécurité de la messagerie.
- **Property-based testing** — Tests générant des valeurs pour vérifier des propriétés définies.
- **Protocol attack** — Épuisement de ressources en exploitant le fonctionnement d'un protocole.
- **Prototype pollution** — Modification non sûre de propriétés de prototypes dans des environnements JavaScript.
- **Provenance** — Informations indiquant comment, où et à partir de quoi un artefact a été construit.
- **Prowler** — Outil d'audit de posture de sécurité cloud, avec contrôles dépendant des services et versions pris en charge.
- **Proxy abuse** — Utilisation détournée d'un proxy ouvert ou d'un proxy compromis.
- **Pseudonymisation** — Remplacement d'identifiants directs par des identifiants de substitution, avec possibilité de réassociation si une information séparée existe.
- **PSSI** — Politique de sécurité des systèmes d'information.
- **PTP** — Synchronisation horaire de précision.
- **Purdue model** — Modèle de référence souvent utilisé pour représenter des niveaux d'architecture industrielle ; il ne décrit pas toutes les architectures modernes.
- **Purple Knight** — Outil d'évaluation de posture de sécurité d'environnements d'identité Microsoft.
- **Purple Team** — Collaboration entre Red Team et Blue Team pour améliorer les contrôles et les détections.
- **Purple teaming** — Tests collaboratifs par lesquels l'équipe offensive valide les capacités défensives.
- **PurpleSharp** — Outil open source de simulation d'actions adverses dans des environnements Windows de test.
- **Pylint / Ruff** — Outils de qualité et d'analyse de code Python ; ils ne remplacent pas un audit de sécurité dédié.

### Q

- **QoS** — Techniques de gestion de priorités et de qualité de service.
- **Qualys VMDR** — Plateforme commerciale de gestion des vulnérabilités et des risques.
- **QUIC** — Protocole de transport sécurisé fonctionnant au-dessus d'UDP, utilisé notamment par HTTP/3.
- **Quishing** — Hameçonnage utilisant un QR code qui renvoie vers un contenu frauduleux.

### R

- **Race condition** — Résultat incorrect lorsque plusieurs opérations concurrentes s'exécutent dans un ordre non prévu.
- **Race-to-root** — Expression informelle décrivant une course pour obtenir le niveau de privilège maximal ; ce n'est pas une classe normalisée unique.
- **RACI** — Responsible, Accountable, Consulted, Informed : matrice des responsabilités.
- **radare2 / rizin** — Outils d'analyse et de rétro-ingénierie de binaires.
- **RADIUS** — Protocole courant d'authentification, d'autorisation et de comptabilisation réseau.
- **RAG** — Retrieval-Augmented Generation.
- **RAG (Retrieval-Augmented Generation)** — Architecture qui récupère des documents pour enrichir les réponses d'un modèle.
- **Ransom DDoS** — Menace ou réalisation d'un DDoS pour extorquer de l'argent.
- **Ransomware / rançongiciel** — Malware ou opération visant à extorquer une rançon, souvent avec chiffrement ou vol de données.
- **Rapid7 InsightVM / Nexpose** — Solutions de gestion des vulnérabilités.
- **RASP** — Protection en cours d'exécution intégrée ou associée à une application.
- **RAT** — Remote Access Trojan/Tool.
- **RAT (Remote Access Trojan/Tool)** — Composant permettant le contrôle distant d'un système ; l'expression dépend du contexte malveillant ou légitime.
- **Rate limiting** — Limitation du nombre ou du rythme des requêtes afin de contrôler l'abus et la charge.
- **RBAC** — Contrôle d'accès basé sur les rôles.
- **RBAC** — Role-Based Access Control.
- **RBAC Kubernetes** — Autorisations associées à des rôles dans un cluster Kubernetes.
- **RCE** — Remote Code Execution.
- **RDP** — Protocole Microsoft d'accès distant à un bureau.
- **RDP** — Remote Desktop Protocol.
- **Reconnaissance** — Collecte d'informations sur une cible avant ou pendant une opération.
- **Red Team exercise** — Exercice simulant des objectifs et comportements d'adversaire pour tester les capacités globales d'une organisation.
- **ReDoS (Regular Expression DoS)** — Épuisement des ressources par une expression régulière au comportement excessivement coûteux.
- **Reflected XSS** — XSS renvoyé dans la réponse à partir de données de la requête.
- **Reflection attack** — Envoi de requêtes falsifiées à des serveurs tiers pour faire diriger les réponses vers la victime.
- **Registry** — Service stockant et distribuant des paquets, images ou artefacts.
- **Relais d'authentification** — Transmission en temps réel d'une authentification légitime vers le service visé, sans nécessairement connaître le secret.
- **Remote Code Execution (RCE)** — Vulnérabilité ou chaîne de faiblesses permettant l'exécution de code contrôlé par un attaquant sur un système distant.
- **Remote File Inclusion (RFI)** — Inclusion de contenu distant dans un contexte vulnérable.
- **Remote Privilege Escalation** — Obtention de privilèges supérieurs via une interaction distante, lorsque le système est vulnérable.
- **Renovate** — Outil automatisant les mises à jour de dépendances.
- **Replay attack** — Réémission d'un message ou jeton valide capturé précédemment, lorsque le protocole ne l'empêche pas.
- **Reprise après sinistre (PRA)** — Plan de restauration des systèmes et données après une interruption majeure.
- **Reproducible build** — Compilation dont le résultat peut être reproduit à partir des mêmes sources et paramètres.
- **Residual risk** — Risque qui subsiste après la mise en œuvre des mesures de traitement.
- **Résilience** — Capacité à résister à un incident, à continuer un service essentiel et à retrouver un fonctionnement acceptable.
- **Resource exhaustion** — Épuisement de mémoire, CPU, connexions, stockage, quotas ou autres ressources.
- **Responder** — Outil de laboratoire d'audit de certains mécanismes de résolution de noms et d'authentification Windows.
- **Responsible disclosure** — Divulgation coordonnée d'une vulnérabilité avec l'entité concernée, selon un calendrier et des règles convenus.
- **Responsible disclosure** — Processus de signalement coordonné d'une vulnérabilité.
- **REST** — Style architectural d'API s'appuyant généralement sur les ressources et les méthodes HTTP.
- **Rétablissement / recovery** — Remise en service sûre, suivie d'une surveillance renforcée.
- **Retire.js** — Outil de détection de bibliothèques JavaScript connues pour comporter des vulnérabilités.
- **Reverse proxy** — Serveur intermédiaire qui reçoit les requêtes des clients puis les transmet aux services en arrière-plan.
- **RGPD / GDPR** — Règlement européen sur la protection des données personnelles.
- **RIP** — Protocole de routage historique à vecteur de distance.
- **Risk appetite** — Niveau et type de risque qu'une organisation accepte de prendre pour atteindre ses objectifs.
- **Risk register** — Registre structuré des risques, propriétaires, traitements et échéances.
- **Risque** — Combinaison de la vraisemblance d'un scénario et de ses conséquences.
- **Risque résiduel** — Risque restant après traitement.
- **ROE / lettre d'autorisation** — Document et accord attestant l'autorisation et les limites de l'exercice ; les exigences précises dépendent du cadre légal et contractuel.
- **Rogue access point** — Point d'accès Wi-Fi installé sans autorisation.
- **Rogue DHCP** — Serveur DHCP non autorisé qui distribue de faux paramètres réseau.
- **Root cause analysis (RCA)** — Recherche de la cause principale et des facteurs contributifs d'un incident.
- **Rootkit** — Ensemble de techniques ou composants visant à cacher une présence ou à conserver des privilèges élevés.
- **Route poisoning** — Manipulation d'informations de routage pour provoquer une route indésirable ou une interruption.
- **Routeur** — Équipement transférant des paquets entre réseaux IP.
- **Routing table** — Table qui aide un hôte ou routeur à choisir une route pour une destination.
- **rpcclient** — Client d'interrogation de certains services RPC/Samba.
- **RPO (Recovery Point Objective)** — Perte maximale de données, exprimée en temps, jugée acceptable après un incident.
- **RPO / RTO** — Recovery Point Objective / Recovery Time Objective.
- **RSA** — Algorithme à clé publique utilisé notamment pour certaines signatures et opérations de chiffrement/échange historiques.
- **RTO (Recovery Time Objective)** — Durée cible maximale pour rétablir un service après un incident.
- **RTP / SRTP** — Transport de médias temps réel, SRTP ajoutant des protections de sécurité.
- **RTU** — Unité distante de télémesure et de commande.
- **Rubeus** — Outil d'audit et de recherche portant sur les mécanismes Kerberos Windows.
- **Rules of Engagement (RoE)** — Règles d'engagement définissant autorisations, limites, horaires, interdictions, contacts et conditions d'arrêt d'un test.
- **Runbook** — Instructions opérationnelles détaillées pour effectuer une tâche récurrente.

### S

- **S/MIME** — Standard de signature et de chiffrement de courriels fondé sur des certificats.
- **SaaS** — Application consommée comme service.
- **Safety instrumented system (SIS)** — Système de sécurité instrumenté qui met un procédé dans un état sûr selon les conditions prévues.
- **Safety vs security** — La sécurité fonctionnelle vise à réduire les risques physiques ; la cybersécurité protège contre les actions et défaillances liées aux systèmes numériques. Elles doivent être considérées ensemble.
- **Salt** — Valeur aléatoire ajoutée au calcul d'un hash de mot de passe pour rendre les empreintes identiques moins corrélables.
- **SAM (Security Account Manager)** — Base locale Windows contenant des informations de comptes locaux.
- **Same-origin policy** — Règle du navigateur isolant par défaut les ressources de certaines origines différentes.
- **SameSite** — Attribut contrôlant l'envoi d'un cookie dans certains contextes inter-sites.
- **SAML** — Standard XML d'échange d'assertions d'authentification et d'autorisation, souvent utilisé en SSO d'entreprise.
- **Sandbox** — Environnement isolé permettant d'observer le comportement d'un fichier ou programme.
- **Sandbox evasion** — Comportement visant à éviter l'analyse en environnement d'observation automatisé.
- **Sandbox navigateur** — Mécanisme d'isolation limitant les actions et accès possibles à un contenu ou processus.
- **SASE** — Architecture combinant des fonctions réseau et de sécurité fournies en service.
- **SASE / SSE / ZTNA** — Secure Access Service Edge / Security Service Edge / Zero Trust Network Access.
- **SAST** — Analyse statique de code source ou compilé sans exécution de l'application.
- **SAST / DAST / IAST / RASP** — Analyse statique / dynamique / instrumentation interactive / protection applicative à l'exécution.
- **Sauvegarde immuable** — Copie protégée contre les modifications ou suppressions pendant une période définie.
- **SBOM** — Inventaire des composants inclus dans un produit logiciel.
- **SBOM (Software Bill of Materials)** — Inventaire formel des composants et dépendances d'un logiciel.
- **SBOM firmware** — Inventaire des composants logiciels présents dans un firmware, lorsque l'information peut être obtenue.
- **SCA** — Software Composition Analysis.
- **SCA (Software Composition Analysis)** — Identification des dépendances, licences et vulnérabilités des composants logiciels.
- **SCADA** — Systèmes de supervision et d'acquisition de données industrielles.
- **Scapy** — Bibliothèque Python de manipulation et d'analyse de paquets, utile pour les tests de protocoles.
- **Scareware** — Logiciel ou page alarmiste poussant la victime à acheter un produit, installer un programme ou divulguer des données.
- **ScoutSuite** — Outil d'audit multi-cloud orienté posture de sécurité.
- **SCTP** — Protocole de transport orienté messages prenant en charge plusieurs flux.
- **SD-WAN** — Pilotage logiciel de connexions WAN avec choix de chemins et politiques centralisées.
- **SDLC / SSDLC** — Software Development Life Cycle / Secure SDLC.
- **Seatbelt** — Outil d'inventaire et de vérification de configurations sur Windows utilisé lors d'audits.
- **Secret exposé** — Mot de passe, jeton, clé privée ou clé API accessible à des personnes non autorisées.
- **Secret rotation** — Remplacement périodique ou déclenché d'un secret par un nouveau.
- **Secrets management** — Stockage, contrôle d'accès et rotation des secrets sans les intégrer en clair au code.
- **Secrets scanning** — Recherche automatisée de clés et identifiants accidentellement présents dans le code ou les dépôts.
- **Secure** — Attribut de cookie qui limite son envoi aux connexions sécurisées HTTPS.
- **Secure boot** — Vérification cryptographique de composants de démarrage avant leur exécution.
- **Secure by default** — Paramètres initiaux conçus pour minimiser l'exposition et les privilèges.
- **Secure by design** — Intégration de la sécurité dans les choix d'architecture et de conception dès le départ.
- **Sécurité de l'information** — Protection de l'information, quel que soit son support, contre les atteintes à la confidentialité, l'intégrité et la disponibilité.
- **Sécurité informatique** — Protection des systèmes informatiques, logiciels, données et infrastructures.
- **Sécurité réseau** — Protection des communications, équipements, flux et frontières réseau.
- **Security champion** — Personne relais de la sécurité au sein d'une équipe produit ou métier.
- **Security gate** — Condition de contrôle dans un pipeline empêchant une livraison si un seuil défini n'est pas atteint.
- **Security misconfiguration** — Configuration de sécurité inadaptée ou incomplète.
- **Security Onion** — Distribution intégrant plusieurs composants open source de surveillance et d'analyse réseau.
- **Segmentation** — Séparation logique ou physique de systèmes et zones pour limiter les déplacements et les impacts.
- **SELinux / AppArmor** — Mécanismes de contrôle d'accès obligatoire qui restreignent les actions de processus.
- **Semgrep** — Outil d'analyse statique configurable de code source.
- **SentinelOne Singularity** — Plateforme commerciale de sécurité des terminaux.
- **SEO poisoning** — Manipulation des résultats ou du référencement pour attirer les utilisateurs vers des pages malveillantes.
- **Séparation des tâches** — Répartition d'une opération sensible entre plusieurs rôles afin de réduire les abus et les erreurs.
- **Server-Side Request Forgery (SSRF)** — Utilisation d'une application serveur pour effectuer des requêtes vers des ressources choisies ou influencées par l'attaquant.
- **Service account / workload identity** — Identité utilisée par une application, un service ou une charge de travail.
- **Session** — État logique reliant plusieurs requêtes à une interaction authentifiée.
- **Session fixation** — Forcer ou faire adopter à une victime un identifiant de session connu de l'attaquant.
- **Session hijacking** — Prise de contrôle d'une session authentifiée, souvent à l'aide d'un identifiant de session volé.
- **Session hijacking réseau** — Détournement d'une communication ou session à partir de données de flux ou de session accessibles.
- **SFTP** — Protocole de transfert de fichiers via SSH, distinct de FTPS.
- **Shared responsibility model** — Répartition des responsabilités de sécurité entre fournisseur cloud et client ; elle dépend du service.
- **SharpHound** — Collecteur de données utilisé avec BloodHound pour certains environnements.
- **Shift left** — Déplacement de contrôles de sécurité vers les premières étapes du développement.
- **Shodan** — Moteur de recherche de services et appareils exposés sur Internet.
- **Shuffle** — Plateforme SOAR open source.
- **SID (Security Identifier)** — Identifiant de sécurité utilisé par Windows pour référencer une entité.
- **Side-channel attack** — Inférence de secrets à partir d'indices physiques comme le temps, la consommation électrique ou les émissions électromagnétiques.
- **SIEM** — Centralise, corrèle et analyse des événements de sécurité pour générer des alertes et faciliter les enquêtes.
- **SIEM** — Security Information and Event Management.
- **Sigma** — Format générique de règles de détection destinées à être converties vers différents backends.
- **Signature d'artefact** — Preuve cryptographique permettant de vérifier l'origine ou l'intégrité d'un artefact.
- **Signature numérique** — Mécanisme cryptographique permettant de vérifier l'origine et l'intégrité d'un message ou d'un artefact.
- **Silver Ticket** — Concept d'attaque impliquant un ticket Kerberos forgé pour un service donné à partir d'un secret associé.
- **SIM swapping** — Prise de contrôle frauduleuse d'un numéro mobile auprès d'un opérateur afin d'intercepter des codes ou réinitialiser des comptes.
- **SIP** — Protocole de signalisation pour sessions multimédias, notamment VoIP.
- **SLA** — Service Level Agreement.
- **Sliver** — Framework open source de simulation et d'opérations d'équipe rouge.
- **SLSA** — Cadre de niveaux d'assurance visant à renforcer l'intégrité de la chaîne de production logicielle.
- **SMB** — Protocole de partage de fichiers et d'autres ressources, surtout dans les environnements Windows.
- **smbclient** — Client en ligne de commande pour accéder à des partages SMB.
- **Smishing** — Hameçonnage par SMS ou messagerie mobile.
- **SMSI / ISMS** — Système de management de la sécurité de l'information.
- **SMTP** — Protocole d'envoi de courriels entre clients et serveurs ou entre serveurs.
- **SNMP** — Protocole de supervision et de gestion d'équipements réseau ; les versions et paramètres d'authentification importent.
- **Snort** — Moteur IDS/IPS basé notamment sur des règles de détection.
- **SOAP** — Protocole de messagerie structurée, généralement basé sur XML.
- **SOAR** — Automatise ou orchestre des réponses à des alertes et procédures de sécurité.
- **SOAR** — Security Orchestration, Automation and Response.
- **SOAR playbook** — Workflow automatisé ou semi-automatisé coordonnant enrichissement et actions de réponse.
- **SOC** — Security Operations Center.
- **SOC (Security Operations Center)** — Équipe et capacités chargées de surveiller, détecter, qualifier et coordonner la réponse aux événements de sécurité.
- **SOC 2** — Rapport d'assurance portant sur des contrôles selon des critères définis, particulièrement dans les services.
- **Socket** — Point de communication logiciel souvent défini par adresse, port et protocole.
- **Software supply-chain security** — Protection du code source, des dépendances, outils de build, registres, identités et processus de distribution.
- **Sous-technique** — Variante plus précise d'une technique ATT&CK.
- **SP (Service Provider)** — Application qui s'appuie sur un fournisseur d'identité.
- **Spear phishing** — Hameçonnage personnalisé visant une personne ou une équipe.
- **SPF** — Enregistrement DNS indiquant quels serveurs sont autorisés à envoyer des courriels pour un domaine.
- **SPF / DKIM / DMARC** — Mécanismes de sécurité et de politique de messagerie.
- **SpiderFoot** — Plateforme d'automatisation de collecte OSINT.
- **Splunk Enterprise Security** — Plateforme d'analyse et de corrélation de données de sécurité.
- **SPN (Service Principal Name)** — Nom identifiant un service dans un environnement Kerberos.
- **Spyware** — Logiciel de surveillance ou de collecte secrète d'informations.
- **SQL injection (SQLi)** — Injection de syntaxe SQL dans une requête construite de manière dangereuse.
- **SQLi** — SQL Injection.
- **sqlmap** — Outil d'aide au test et à la validation de faiblesses SQL injection dans un périmètre autorisé.
- **SSDLC (Secure Software Development Life Cycle)** — Intégration de pratiques de sécurité tout au long du cycle de vie logiciel.
- **SSH** — Protocole d'accès distant sécurisé et de tunnelisation.
- **SSH authorized_keys** — Fichier contenant des clés publiques autorisées à se connecter à un compte via SSH.
- **SSLyze / sslscan** — Outils d'analyse de configuration SSL/TLS.
- **SSO** — Single Sign-On.
- **SSO (Single Sign-On)** — Authentification unique permettant d'accéder à plusieurs applications selon une relation de confiance.
- **SSRF** — Server-Side Request Forgery.
- **SSRF vers services internes** — Abus d'une fonction serveur qui effectue des requêtes vers des ressources réseau non destinées à l'utilisateur.
- **Stager** — Composant initial minimal qui obtient ou lance d'autres composants.
- **Static analysis** — Analyse d'un fichier ou programme sans exécuter son code.
- **STIX / TAXII** — Modèles et mécanismes d'échange de renseignements sur les menaces.
- **STIX / TAXII** — Standards et protocoles d'échange de renseignement sur les menaces.
- **Stored XSS** — XSS enregistré dans un stockage puis affiché à d'autres utilisateurs.
- **STP / RSTP** — Protocoles évitant les boucles de couche 2.
- **strace / ltrace** — Outils Linux d'observation d'appels système et de bibliothèques.
- **Subfinder** — Découverte passive de sous-domaines à partir de sources publiques.
- **Subnetting** — Division d'un réseau IP en sous-réseaux.
- **sudo** — Mécanisme permettant l'exécution de commandes avec une identité ou des privilèges autorisés.
- **sudoers** — Configuration des utilisateurs autorisés à utiliser sudo et des commandes permises.
- **SUID / SGID** — Bits de permission Unix qui font s'exécuter un programme avec l'identité du propriétaire ou du groupe dans certains cas.
- **Supply-chain attack** — Compromission d'un fournisseur, d'une dépendance, d'un outil ou d'une étape de fabrication/distribution pour atteindre une cible.
- **Surface d'attaque** — Ensemble des points d'entrée, interfaces, identités et dépendances qu'un attaquant peut tenter d'utiliser.
- **Surface Internet** — Services, noms de domaine, certificats et adresses exposés publiquement par une organisation.
- **Suricata** — Moteur IDS/IPS et d'analyse réseau.
- **Switch / commutateur** — Équipement transmettant les trames entre ports selon leurs adresses MAC et sa configuration.
- **Syft** — Outil de génération de SBOM.
- **SYN flood** — Accumulation de demandes d'ouverture TCP afin d'épuiser les ressources associées aux connexions.
- **Sysinternals** — Suite d'utilitaires Windows pour l'administration et l'investigation.
- **Syslog** — Format et protocole de transmission de journaux.
- **Sysmon** — Outil Microsoft qui ajoute des événements système détaillés utiles à la détection.
- **Sysmon** — Source supplémentaire d'événements détaillés pour la détection Windows.

### T

- **Tabletop** — Exercice sur table visant à tester la coordination et la prise de décision sans exécuter d'attaque réelle.
- **Tabletop exercise** — Exercice de discussion simulant un scénario pour tester les décisions, rôles et procédures.
- **TACACS+** — Protocole souvent utilisé pour l'administration centralisée des équipements réseau.
- **Tactique** — But opérationnel d'une action adverse, par exemple obtenir un accès initial ou voler des identifiants.
- **Tailgating / piggybacking** — Entrée physique derrière une personne autorisée sans validation propre.
- **Taux de conformité** — Part des contrôles évalués qui satisfont les exigences définies ; il ne résume pas à lui seul le niveau de sécurité.
- **Taux de faux positifs** — Part des alertes positives qui ne correspondent pas au comportement recherché.
- **Taux de réussite de restauration** — Part des tests de restauration qui aboutissent à un résultat conforme aux objectifs.
- **TCP** — Protocole de transport orienté connexion avec livraison ordonnée et retransmission.
- **TCP desynchronization** — Altération ou exploitation des différences de suivi de flux TCP entre composants.
- **TCP sequence prediction** — Prédiction de numéros de séquence dans des contextes vulnérables ou anciens.
- **TCP/IP** — Famille de protocoles structurée autour d'IP, TCP, UDP et d'autres protocoles Internet.
- **tcpdump** — Outil en ligne de commande de capture et filtrage de paquets.
- **Tech support scam** — Arnaque prétendant provenir d'un support technique afin d'obtenir un paiement ou un accès distant.
- **Technique** — Manière générale d'atteindre un objectif tactique.
- **TEE (Trusted Execution Environment)** — Environnement d'exécution isolé offrant certaines garanties de confidentialité et d'intégrité.
- **Télémétrie** — Données collectées par les systèmes, applications, équipements et agents de sécurité.
- **Telnet** — Protocole historique d'accès distant sans chiffrement ; à éviter sur des réseaux non protégés.
- **Template injection / SSTI** — Données interprétées comme du code par un moteur de templates côté serveur.
- **testssl.sh** — Outil de vérification de la configuration TLS d'un service.
- **tfsec** — Outil d'analyse statique de configurations Terraform, dont des fonctions sont intégrées ou liées à d'autres offres selon l'évolution du projet.
- **TFTP** — Protocole simplifié de transfert de fichiers, sans mécanismes robustes d'authentification intégrés.
- **theHarvester** — Collecte d'informations publiques, notamment de noms, sous-domaines et adresses associés à une organisation.
- **TheHive** — Plateforme de gestion des incidents et des cas d'investigation.
- **Third-party risk management (TPRM)** — Évaluation et suivi des risques liés aux fournisseurs, partenaires et dépendances.
- **Threat hunting** — Recherche proactive de comportements malveillants qui n'ont pas nécessairement déclenché d'alerte.
- **Threat hunting query** — Requête appliquée aux journaux ou à la télémétrie pour rechercher un comportement ou une hypothèse.
- **Threat intelligence (renseignement sur la menace)** — Informations contextualisées sur les acteurs, capacités, infrastructures, vulnérabilités et campagnes de menace.
- **Threat modeling** — Processus consistant à identifier les menaces et faiblesses potentielles dès la conception.
- **Threat modeling applicatif** — Analyse des menaces au stade de la conception d'une application.
- **Three-way handshake** — Échange TCP SYN, SYN-ACK et ACK servant à établir une connexion.
- **Timeline analysis** — Reconstitution chronologique d'événements à partir des horodatages et traces disponibles.
- **Timesketch** — Plateforme d'analyse collaborative de chronologies.
- **Tines** — Plateforme d'automatisation de workflows de sécurité.
- **TLP** — Traffic Light Protocol, marquage des conditions de partage d'une information.
- **TLS** — Protocole sécurisant les communications, notamment HTTPS.
- **TLS termination** — Point où une connexion TLS est déchiffrée, par exemple sur un proxy ou un répartiteur.
- **TOCTOU (Time-of-check to time-of-use)** — Écart exploitable entre une vérification et l'utilisation ultérieure d'une ressource.
- **Tokenization** — Remplacement d'une donnée par un jeton de substitution ; ce mécanisme n'est pas nécessairement du chiffrement.
- **Tool/function calling risk** — Risque qu'un modèle déclenche un outil ou une action avec des permissions inappropriées.
- **TPM** — Module matériel fournissant des fonctions de stockage de clés et de mesure de confiance.
- **TPRM** — Third-Party Risk Management.
- **Traçabilité** — Capacité à relier une action à une identité, un contexte et une chronologie fiables.
- **traceroute / tracert / mtr** — Outils d'analyse du chemin réseau.
- **Triage** — Première évaluation d'une alerte selon sa crédibilité, sa gravité, son contexte et sa priorité.
- **Triple extorsion** — Variante ajoutant une pression supplémentaire, par exemple sur des partenaires, clients ou services exposés.
- **Trivy** — Scanner de vulnérabilités, de configurations, de secrets et d'artefacts cloud-native selon ses modules.
- **Trojan / cheval de Troie** — Programme présenté comme légitime ou utile mais comportant une fonction malveillante.
- **TruffleHog** — Outil de recherche de secrets dans des dépôts et sources prises en charge.
- **Trunk** — Lien transportant plusieurs VLAN entre équipements compatibles.
- **Trust boundary failure** — Absence de contrôle approprié lors du passage entre deux domaines de confiance.
- **TShark** — Version en ligne de commande des fonctions de capture/analyse de Wireshark.
- **TTL / Hop Limit** — Champ limitant la durée ou le nombre de sauts d'un paquet.
- **TTP** — Tactics, Techniques and Procedures.
- **TTP (Tactics, Techniques, Procedures)** — Objectifs tactiques, méthodes et procédures observés chez un adversaire.
- **Tunneling** — Transport d'un protocole à l'intérieur d'un autre ; légitime en réseau, mais parfois abusé pour contourner les contrôles.
- **Typosquatting** — Utilisation d'un domaine ressemblant à celui d'une marque ou d'un service légitime.
- **Typosquatting de dépendance** — Nom de paquet très proche d'un paquet légitime destiné à tromper un consommateur.
- **Typosquatting de package** — Publication d'un paquet au nom proche d'un paquet légitime pour tromper les développeurs.

### U

- **UAC (User Account Control)** — Mécanisme Windows qui limite certaines actions élevées et demande une élévation de privilèges selon le contexte.
- **UDP** — Protocole de transport sans établissement de connexion ni garantie de livraison.
- **UEBA** — Analyse du comportement des utilisateurs et entités pour repérer des écarts ou anomalies.
- **UEBA** — User and Entity Behavior Analytics.
- **UEM / MDM** — Unified Endpoint Management / Mobile Device Management.
- **UID / GID** — Identifiants numériques d'utilisateur et de groupe sous Unix/Linux.
- **Unrestricted file upload** — Dépôt de fichiers dangereux qui peuvent ensuite être interprétés ou exécutés.
- **URLhaus** — Base de données communautaire d'URLs associées à la distribution de malware.
- **Use case de détection** — Scénario documenté décrivant le comportement recherché, les données nécessaires, la logique de détection et le traitement attendu.
- **Use-after-free** — Utilisation d'un emplacement mémoire après libération.
- **Usurpation d'identité (spoofing)** — Falsification de l'identité apparente d'un expéditeur, d'un système, d'une adresse ou d'un service.

### V

- **Vault** — Terme générique ou nom de produits désignant un gestionnaire de secrets ; les capacités varient selon l'implémentation.
- **VDI** — Infrastructure de postes de travail virtuels.
- **Vector database** — Base destinée à stocker et rechercher des représentations vectorielles, souvent utilisées par les systèmes RAG.
- **Velociraptor** — Plateforme de collecte et d'investigation numérique à grande échelle.
- **Virus** — Malware qui s'attache à d'autres fichiers ou contenus et se propage lorsque ceux-ci sont exécutés ou partagés.
- **VirusTotal** — Service d'analyse et de partage de signaux sur des fichiers, URLs et autres artefacts ; les soumissions peuvent être partagées selon les conditions du service.
- **Vishing** — Hameçonnage par appel vocal.
- **VLAN (IEEE 802.1Q)** — Segmentation logique de couche 2.
- **VLAN / VPN / VPC** — Virtual LAN / Virtual Private Network / Virtual Private Cloud.
- **VLAN hopping** — Famille de techniques visant à franchir une séparation VLAN mal configurée.
- **VNC** — Famille de systèmes d'accès distant à une interface graphique.
- **Vol ou perte d'équipement** — Exposition de données ou de secrets par perte d'un appareil.
- **Volatility** — Framework d'analyse de mémoire.
- **Volumetric attack** — Saturation de capacité réseau par un volume élevé de trafic.
- **VPN** — Tunnel logique chiffré ou protégé traversant un réseau ; la sécurité dépend du protocole et de sa configuration.
- **Vrai négatif** — Absence correctement identifiée d'activité correspondant au critère détecté.
- **Vrai positif** — Détection correcte d'une activité malveillante ou interdite.
- **Vulnérabilité** — Faiblesse exploitable d'un système, d'un logiciel, d'une configuration, d'un processus ou d'une conception.
- **Vulnerability management** — Identification, priorisation, affectation et suivi de correction des vulnérabilités.
- **VXLAN** — Encapsulation destinée à étendre des réseaux de couche 2 au-dessus d'un réseau IP.

### W

- **WAF** — Pare-feu spécialisé dans les requêtes Web.
- **WAF** — Web Application Firewall.
- **WAF (Web Application Firewall)** — Filtre spécialisé dans le trafic HTTP(S), utile comme contrôle complémentaire mais incapable de remplacer un code sûr.
- **Watering hole** — Compromission d'un site fréquenté par les personnes ou organisations ciblées.
- **Wazuh** — Plateforme open source de détection, conformité, inventaire et surveillance de sécurité.
- **WDAC / AppLocker** — Technologies de contrôle des applications pouvant limiter les exécutables autorisés.
- **Web cache** — Cache stockant des réponses HTTP pour réduire la latence et la charge.
- **Webhook** — Notification HTTP émise par un service vers une URL lorsqu'un événement se produit.
- **WebSocket** — Canal de communication bidirectionnel sur une connexion HTTP(S) établie.
- **WEP cracking** — Récupération de clés WEP, protocole Wi-Fi obsolète et non sûr.
- **Whaling** — Hameçonnage ciblant des dirigeants ou personnes à forte responsabilité.
- **White Team** — Groupe qui encadre, arbitre et contrôle le déroulement d'un exercice de sécurité.
- **Whois** — Service de consultation d'informations d'enregistrement de domaines ou de ressources Internet, selon les données disponibles.
- **Wi-Fi evil twin** — Point d'accès frauduleux imitant un réseau sans fil légitime.
- **Windows Defender Firewall** — Pare-feu logiciel intégré à Windows.
- **WinPEAS / LinPEAS** — Scripts d'énumération de configurations susceptibles de signaler des chemins de privilèges ; résultats à valider manuellement.
- **Wiper** — Malware visant principalement à effacer ou détruire des données.
- **WireGuard** — Protocole VPN moderne et relativement simple.
- **Wireshark** — Analyseur graphique de paquets réseau.
- **Worm / ver** — Malware capable de se propager automatiquement entre systèmes.
- **WPA/WPA2/WPA3** — Familles de mécanismes de sécurité Wi-Fi ; la configuration, l'authentification et les correctifs comptent autant que la version annoncée.
- **Write blocker** — Dispositif ou mécanisme empêchant l'écriture sur un support pendant son acquisition.

### X

- **x64dbg** — Débogueur Windows pour l'analyse de programmes.
- **XDR** — Corrélation étendue entre plusieurs domaines, par exemple terminaux, identité, messagerie et réseau.
- **XDR** — Extended Detection and Response.
- **XPath injection** — Altération d'une expression XPath.
- **XSS** — Cross-Site Scripting.
- **XXE (XML External Entity)** — Exploitation d'entités externes XML activées ou mal contrôlées.

### Y

- **YARA** — Langage de règles visant à identifier des motifs dans des fichiers ou contenus.
- **YARA rule** — Règle de détection de motifs dans des fichiers ou contenus.

### Z

- **Zeek** — Moniteur de sécurité réseau générant des journaux structurés d'activités réseau.
- **Zeek** — Outil de surveillance réseau produisant des journaux de protocole riches.
- **Zero Trust** — Approche qui n'accorde pas de confiance implicite en fonction du réseau ou de l'emplacement et vérifie explicitement les accès.
- **Zero-day (0-day)** — Vulnérabilité exploitée ou connue avant qu'un correctif utilisable ne soit disponible pour les défenseurs concernés ; le sens exact varie selon le contexte.
- **Zip bomb** — Archive compacte dont la décompression consomme énormément de ressources.
- **Zmap** — Scanner Internet à grande échelle pour des recherches autorisées.
- **ZTNA** — Accès réseau fondé sur une vérification explicite de l'identité et du contexte, plutôt qu'un accès réseau large.
- **ZTNA** — Zero Trust Network Access.

## Référence rapide des ports

### Ports courants (repères de diagnostic)

> Les ports ci-dessous sont des usages fréquents, pas une preuve du service réellement exécuté. Un service peut écouter sur un port non standard, et un port ouvert n'est pas à lui seul une vulnérabilité.

| Port | Transport | Service courant | Remarque de sécurité |
|---:|---|---|---|
| 20/21 | TCP | FTP (données/contrôle) | FTP classique ne chiffre pas les identifiants ni les données. |
| 22 | TCP | SSH, SFTP via SSH | Restreindre les comptes, les méthodes d'authentification et l'exposition. |
| 23 | TCP | Telnet | Protocole en clair, généralement à désactiver. |
| 25 | TCP | SMTP entre serveurs | Contrôler le relais ouvert, TLS et la configuration de messagerie. |
| 53 | TCP/UDP | DNS | Protéger récursion, transferts de zone et intégrité des réponses. |
| 67/68 | UDP | DHCP serveur/client | Les protections de couche 2 et la surveillance des serveurs autorisés sont importantes. |
| 69 | UDP | TFTP | Pas d'authentification/chiffrement robustes intégrés. |
| 80 | TCP | HTTP | Rediriger vers HTTPS selon le contexte et éviter les données sensibles en clair. |
| 88 | TCP/UDP | Kerberos | Surveiller les erreurs et abus d'authentification ; protéger les comptes de service. |
| 110 | TCP | POP3 | Préférer une configuration chiffrée. |
| 123 | UDP | NTP | Utiliser des sources de temps fiables et limiter les abus d'exposition. |
| 135 | TCP | MS RPC Endpoint Mapper | Restreindre l'accès réseau selon les besoins. |
| 137–139 | TCP/UDP | NetBIOS | Protocoles historiques à limiter selon les besoins. |
| 143 | TCP | IMAP | Préférer une configuration chiffrée. |
| 161/162 | UDP | SNMP / traps | Éviter les configurations anciennes ou communautés par défaut ; limiter l'administration. |
| 179 | TCP | BGP | Accès et annonces doivent être contrôlés entre pairs prévus. |
| 389 | TCP/UDP | LDAP | Utiliser une protection de transport appropriée et des contrôles d'accès stricts. |
| 443 | TCP | HTTPS | TLS protège le transport, pas une application vulnérable en elle-même. |
| 445 | TCP | SMB | Restreindre aux réseaux nécessaires et appliquer les correctifs. |
| 465 | TCP | SMTP sur TLS implicite (usage courant) | Dépend de la configuration du serveur de messagerie. |
| 500 | UDP | IKE/IPsec | Utilisé pour établir certaines associations IPsec. |
| 514 | UDP/TCP selon implémentation | Syslog | Syslog sans protection ne garantit pas la confidentialité ou l'intégrité. |
| 587 | TCP | Submission SMTP | Port courant d'envoi authentifié depuis les clients. |
| 636 | TCP | LDAP sur TLS (LDAPS) | Valider les certificats et restreindre l'accès. |
| 993 | TCP | IMAP sur TLS | Utiliser des méthodes modernes d'authentification. |
| 995 | TCP | POP3 sur TLS | Vérifier certificats et paramètres du service. |
| 1433 | TCP | Microsoft SQL Server | Ne pas exposer publiquement sans besoin et contrôle explicites. |
| 1521 | TCP | Oracle Database (usage courant) | Restreindre l'accès aux clients autorisés. |
| 2049 | TCP/UDP selon version | NFS | Contrôler les exports, identités et règles réseau. |
| 2375/2376 | TCP | API Docker (sans TLS / avec TLS, usages courants) | L'accès à l'API de conteneurs équivaut souvent à un accès très privilégié. |
| 3306 | TCP | MySQL/MariaDB | Restreindre le réseau et renforcer les comptes. |
| 3389 | TCP/UDP | RDP | Réduire l'exposition, activer MFA quand possible et journaliser. |
| 5432 | TCP | PostgreSQL | Restreindre les clients et appliquer le moindre privilège. |
| 5900 | TCP | VNC (usage courant) | Limiter l'exposition et exiger des protections fortes. |
| 5985/5986 | TCP | WinRM HTTP/HTTPS | Contrôler les accès d'administration et préférer un transport sûr. |
| 6379 | TCP | Redis (usage courant) | Ne pas exposer sans protection ; vérifier authentification et bind réseau. |
| 8080/8443 | TCP | HTTP/HTTPS alternatifs, proxies ou consoles | Le service dépend de la configuration réelle. |
| 9200/9300 | TCP | Elasticsearch (API / communication de cluster, usages courants) | Contrôler authentification, exposition et règles réseau. |
| 11211 | TCP/UDP | Memcached (selon déploiement) | Restreindre l'exposition et désactiver les fonctions inutiles. |
| 27017 | TCP | MongoDB (usage courant) | Restreindre l'accès et vérifier authentification/configuration. |



## Références utiles

Ces sources officielles ou largement reconnues permettent de vérifier les définitions et de suivre les évolutions. Certaines publications sont en anglais.

### Référentiels et glossaires

- [NIST Cybersecurity Glossary](https://csrc.nist.gov/glossary) — Glossaire étendu, avec sources associées aux définitions.
- [MITRE ATT&CK](https://attack.mitre.org/) — Tactiques, techniques et sous-techniques adverses.
- [MITRE CWE](https://cwe.mitre.org/) — Catalogue des faiblesses communes.
- [CVE Program](https://www.cve.org/) — Identifiants publics de vulnérabilités.
- [NVD - National Vulnerability Database](https://nvd.nist.gov/) — Informations et enrichissements sur les vulnérabilités.
- [FIRST CVSS](https://www.first.org/cvss/) — Spécification et ressources CVSS.
- [FIRST EPSS](https://www.first.org/epss/) — Estimation de probabilité d'exploitation.
- [CISA Known Exploited Vulnerabilities Catalog](https://www.cisa.gov/known-exploited-vulnerabilities-catalog) — Catalogue de vulnérabilités exploitées connues.
- [OWASP Top 10:2025](https://owasp.org/Top10/) — Principaux risques applicatifs de l'édition 2025.
- [OWASP Web Security Testing Guide](https://owasp.org/www-project-web-security-testing-guide/) — Guide de test de sécurité Web.
- [OWASP API Security Project](https://owasp.org/www-project-api-security/) — Risques de sécurité des API.
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework) — Cadre de gestion des risques cyber.
- [CIS Critical Security Controls](https://www.cisecurity.org/controls) — Mesures de sécurité priorisées.
- [MITRE D3FEND](https://d3fend.mitre.org/) — Base de connaissances de contre-mesures défensives.
- [MITRE ATLAS](https://atlas.mitre.org/) — Base de menaces et techniques ciblant les systèmes d'IA.

### France et Union européenne

- [ANSSI](https://cyber.gouv.fr/) — Guides, recommandations et ressources françaises de cybersécurité.
- [CERT-FR](https://www.cert.ssi.gouv.fr/) — Alertes, avis et bulletins de sécurité.
- [CNIL](https://www.cnil.fr/) — Protection des données personnelles et conformité.
- [ENISA](https://www.enisa.europa.eu/) — Agence de l'Union européenne pour la cybersécurité.
- [EUR-Lex](https://eur-lex.europa.eu/) — Textes de droit de l'Union européenne, dont le RGPD, NIS2 et DORA.

### Protocoles et spécifications

- [RFC Editor](https://www.rfc-editor.org/) — Publications techniques et RFC des protocoles Internet.
- [IETF](https://www.ietf.org/) — Organisme de normalisation des protocoles Internet.
- [W3C](https://www.w3.org/) — Standards du Web.
- [WHATWG](https://whatwg.org/) — Spécifications vivantes de technologies Web, dont HTML.
- [FIDO Alliance](https://fidoalliance.org/) — Authentification FIDO, passkeys et technologies associées.
- [PCI Security Standards Council](https://www.pcisecuritystandards.org/) — Référentiels de sécurité de paiement.

### Outils et données

- [VirusTotal](https://www.virustotal.com/) — Analyse de fichiers et d'URLs ; attention au partage potentiel des soumissions.
- [MISP Project](https://www.misp-project.org/) — Partage d'informations de menace.
- [OpenCTI](https://opencti.io/) — Gestion de renseignement sur les menaces.
- [Sigma](https://sigmahq.io/) — Format de règles de détection.
- [YARA](https://virustotal.github.io/yara/) — Langage de règles de détection de motifs.
- [Zeek](https://zeek.org/) — Surveillance et analyse réseau.
- [Suricata](https://suricata.io/) — Moteur IDS/IPS et analyse réseau.
- [Wazuh](https://wazuh.com/) — Plateforme de surveillance et de détection open source.
- [The Sleuth Kit / Autopsy](https://www.sleuthkit.org/) — Outils d'investigation numérique.
- [Volatility Foundation](https://volatilityfoundation.org/) — Analyse de mémoire.

---

## Notes de maintenance

- Ajouter la date de vérification et la version des référentiels lorsqu'un terme dépend d'une édition précise.
- Pour une définition normative, lire la norme ou la spécification originale : un glossaire résume et ne remplace pas le texte de référence.
- Les outils peuvent changer de nom, de licence, de fonctionnalités ou de statut de maintenance. Vérifier leur documentation officielle avant de les intégrer à un processus.
- Pour un dépôt MkDocs, placer ce fichier dans `docs/` puis l'ajouter à la navigation dans `mkdocs.yml` si la navigation est définie manuellement.
