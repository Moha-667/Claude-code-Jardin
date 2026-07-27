# Corrections apportées à `flows_82.json` → `flows_82_corrige.json`

Analyse et corrections du 21/07/2026. 19 nœuds modifiés, 2 supprimés, 1 ajouté
(config TLS), 96 inchangés. Chaque correctif a été vérifié par une passe de
relecture adversariale indépendante (10 vérifications, 0 réfutation).

## ⚠️ Actions manuelles OBLIGATOIRES après import

1. **Révoquer l'ancienne clé OpenAI** (`sk-proj-qXlh…rB7cA`) sur
   <https://platform.openai.com/api-keys> — elle a circulé en clair dans l'export,
   considérez-la compromise.
2. **Créer une nouvelle clé** et la fournir au serveur Node-RED en variable
   d'environnement : `OPENAI_API_KEY=sk-…` (fichier systemd, `.bashrc`,
   `docker -e`, etc.), puis redémarrer Node-RED. Le flow la lit désormais
   depuis l'environnement — elle n'apparaîtra plus jamais dans un export.
3. **Vérifier la connexion MQTT TTN** après import : le broker passe en
   TLS (port 8883). Les identifiants TTN (username/API key) sont dans le
   fichier credentials, pas dans cet export — ils sont conservés si vous
   importez sur la même instance.

## 🔴 Correctifs critiques

| # | Problème | Correction |
|---|----------|------------|
| 1 | Clé API OpenAI stockée **en clair** dans le `global-config` (visible dans tout export/partage) | L'entrée `OPENAI_API_KEY` est maintenant de type `env` : elle référence la variable d'environnement du système au lieu de contenir la clé |
| 2 | Les alertes **coupure/reprise énergie** (`ENERGY_CUTOFF_ENTER`/`ENERGY_RESUME`) n'atteignaient jamais le formatter → aucun toast ni e-mail pour l'événement le plus important | Sortie 2 de « EcoFlow → energie_ok » câblée aussi vers « 📢 Formatter alerte EcoFlow » |
| 3 | **Écart minimum de 6 h entre arrosages non appliqué pendant ~3 h** : l'historique n'est alimenté qu'après le délai d'observation (180 min), l'IA horaire pouvait ré-arroser entre-temps | Le Pré-check v8 prend en compte `attente_mesure_post` et `arrosage_fin_ts` : l'arrosage qui vient de se terminer compte immédiatement dans `dernierArrosageH` et `arrosagesAujourdhui` (sans double comptage après calibration). `Math.floor` remplace `Math.round` pour ne jamais sous-estimer l'écart |

## 🟠 Correctifs importants

| # | Problème | Correction |
|---|----------|------------|
| 4 | Historique des commandes IA jamais mis à jour en direct (les messages `new-entry` mouraient dans le bouton de navigation « Voir EcoFlow ») | Sortie 3 de « Parse & Decide » recâblée directement sur « 📊 Logger ». Le Pré-check a maintenant une 3ᵉ sortie qui journalise aussi ses mises en veille en direct |
| 5 | E-mail inutilisable : le champ destinataire contenait un libellé au lieu d'une adresse | **Nœud e-mail supprimé à la demande de l'utilisateur** (alertes e-mail non souhaitées pour l'instant). Les alertes restent visibles en toast sur le dashboard. Pour réactiver plus tard : ajouter un nœud `e-mail` (palette node-red-node-email) sur la **sortie 2** de « 📢 Formatter alerte EcoFlow », avec l'adresse destinataire dans son champ To/name et des identifiants SMTP |
| 6 | Incohérence de fraîcheur EcoFlow : 3 fonctions testaient `ecoflow_last_update` (ne bouge que si les données *changent*) avec un seuil 15 min, alors que le watchdog tolère 60 min de données figées (batterie au repos = normal) → blocages AUTO injustifiés | « Parse & Decide », « Config fréquence vanne » et « Sécurité énergie avant ouverture » utilisent désormais `ecoflow_last_seen \|\| ecoflow_last_update`, comme « choix vanne », « Sauver AUTO » et le Pré-check |
| 7 | Toast Dashboard 2.0 cassé : `ui-notification` recevait un objet → « [object Object] » | Le formatter envoie une chaîne (`sujet — texte`) |
| 8 | MQTT TTN en clair (port 1883) : la clé API TTN transitait non chiffrée | Broker en port 8883 + TLS, avec un nœud `tls-config` dédié en **vérification stricte du certificat serveur** (sans lui, Node-RED se connecte en TLS mais sans vérifier le certificat) |

## 🟡 Correctifs mineurs / robustesse

| # | Problème | Correction |
|---|----------|------------|
| 9 | Plages horaires (7 h–20 h), saisons et resets journaliers basés sur l'heure **du serveur** (décalés si l'hôte est en UTC) | `timezone: "Europe/Paris"` ajouté à la config centralisée ; heure/mois/jour calendaire calculés via `Intl` avec ce fuseau dans le Pré-check, Parse & Decide et « Litres du jour ». Horodatages affichés (logs, historique, alertes) également en heure de Paris |
| 10 | Un échec de l'appel qualité de l'air jetait **toute** la mise à jour météo (météo périmée → IA en veille au bout de 2 h) | L'AQI n'est plus bloquant : la météo s'affiche avec la tuile air en « -- » gris. Gardes ajoutées sur la structure météo et sur `hourlyList` vide. Un AQI absent n'affiche plus faussement « Bonne » |
| 11 | Résidu Dashboard v1 : nœud `ui_base` orphelin (« unknown node » si la palette v1 n'est pas installée) | Supprimé |
| 12 | Groupe UI « Données EcoFlow » en double, sans page ni widget | Supprimé |
| 13 | Code mort : variable `payloadStr` inutilisée (Chef d'Orchestre), ternaire sans effet (`"openai+validation"` des deux côtés, Parse & Decide) | Nettoyés |
| 14 | Un fuseau horaire invalide dans une config persistée aurait fait planter tous les calculs `Intl` | L'Init Config valide `cfg.timezone` et retombe sur `Europe/Paris` en cas de valeur invalide |
| 15 | Une erreur **réseau** (timeout, DNS…) sur GET Weather / GET AQI n'émettait aucun message (`senderr: true`) : la météo sautait le cycle en silence, sans passer par les gardes ajoutées | `senderr: false` sur les 3 nœuds `http request` : l'erreur traverse la chaîne et est gérée proprement (météo affichée sans AQI, décision IA en VEILLE loggée) |

## ✅ Faux positif retiré de l'analyse initiale

- La file d'attente LYVA est bien configurée à 1 msg / 4 s (`nbRateUnits: 4`) —
  conforme à son nom, aucune correction nécessaire.

## ℹ️ Points laissés volontairement en l'état

- **Sortie pompe** de « 🛑 Coupure énergie EcoFlow » toujours branchée sur le debug
  « POMPE OFF - à raccorder » : il n'existe pas encore de commande matérielle réelle
  (relais, prise connectée…) à câbler.
- **Chaîne de test** « Sécurité énergie avant ouverture » (onglet EcoFlow) : conservée
  comme banc d'essai, ses sorties restent sur des nœuds debug.
- **Verrouillage hors-ligne « collant »** : une fois l'EcoFlow marqué hors ligne, seul
  un payload qui *change* le remet en ligne. C'est un choix prudent du flow d'origine
  (commenté comme intentionnel), conservé tel quel.
- **Numéro de série EcoFlow** : nécessaire aux appels API, conservé.

## 🔧 Optimisations (2ᵉ passe)

| # | Optimisation | Détail |
|---|--------------|--------|
| O1 | **Routage MQTT central** | Un switch « Routage TTN par équipement » aiguille chaque uplink vers les seules fonctions concernées (vanne → 2 fonctions, débitmètre → 1, capteur sol → 1) au lieu d'exécuter les 4 fonctions pour chaque message. Les gardes internes des fonctions sont conservées (défense en profondeur) |
| O2 | **Constantes mortes retirées** | « Vanne » et « Capteur (Dragino) » ne déclarent plus de valeurs par défaut qu'elles n'utilisent pas |
| O3 | **Groupe nommé** | Le groupe anonyme de l'onglet Arrosage s'appelle désormais « Pilotage IA & Journal » |
| O4 | **Persistance du contexte** (à activer côté serveur, voir ci-dessous) | Sans elle, un redémarrage de Node-RED efface quota d'eau du jour, historique d'arrosages, état vanne et mode AUTO |

### Activer la persistance (Windows)

Dans `C:\Users\<VOTRE_NOM>\.node-red\settings.js`, ajouter (ou décommenter) dans
`module.exports` :

```js
contextStorage: {
    default: { module: "localfilesystem" },
},
```

puis redémarrer Node-RED. L'état est alors sauvegardé dans
`C:\Users\<VOTRE_NOM>\.node-red\context\` (écriture toutes les 30 s).

Refactorings volontairement **non** faits (bénéfice faible / risque sur la logique
de sécurité) : centralisation de la vérification EcoFlow répétée dans plusieurs
fonctions, fusion des états `valve_state` / `vanne_lyva_state` (l'ancien format
sert encore de repli), suppression du banc de test « Sécurité énergie avant
ouverture ».

## 🎨 Refonte UI (3ᵉ passe)

| # | Changement | Détail |
|---|------------|--------|
| U1 | **Navigation unifiée** | La même barre (Jardin / Météo / IA / EcoFlow, page active surlignée) est présente en haut des 4 pages. Elle remplace les boutons épars (bouton EcoFlow, bouton Météo caché dans le Journal, bouton Retour) ; la page IA devient enfin accessible |
| U2 | **Thème unique** | Les deux thèmes étaient des doublons identiques : fusionnés en « Thème Jardin », appliqué aux 4 pages. Icônes de pages corrigées (mdi-sprout, mdi-weather-partly-cloudy, mdi-robot-outline, mdi-battery-charging) |
| U3 | **Page IA restylée** | « Profil Plante », « Mode Maintenance » et « Feedback Widget » passent au style verre sombre + accent vert du reste du dashboard (ils étaient en style brut/violet). La logique Vue (bindings, send) est inchangée |
| U4 | **Liens cassés corrigés** | Deux boutons pointaient vers `/dashboard/permaculture` qui n'existe pas (la page s'appelle `/page1`) : bouton retour du Feedback Widget (supprimé, remplacé par la nav) et bouton retour du widget Météo (corrigé) |
| U5 | **Feuille de style globale** | Un template `site:style` définit la police unifiée, des variables CSS partagées et des barres de défilement discrètes |
| U6 | **Divers** | Groupe « Capteur sol  » renommé « Capteur & Débit » (il contient aussi le débitmètre), table Historique IA harmonisée (coins 16 px), listes de membres des groupes d'éditeur resynchronisées |
| U7 | **Carte « État système »** (page Jardin, sous la navigation) | Synthèse en un coup d'œil : vanne (état + batterie + commande en attente), mode (AUTO/MANUEL/MAINTENANCE + état de l'automatisme), batterie EcoFlow (SOC + fraîcheur), eau restante du jour, dernière décision IA (avec raison). **Bandeau d'alerte persistant** (rouge pulsé pour coupure énergie, orange pour maintenance ou données EcoFlow absentes) — l'alerte critique ne repose plus sur un toast de 8 s. Alimentée par un agrégateur (« 🧭 État système ») déclenché toutes les 30 s, à l'ouverture de la page et sur chaque événement clé |
| U8 | **Nouveau visuel de vanne « robinet rotatif »** | Remplace le grand robinet SVG rouge. Cadran avec l'état écrit à l'intérieur (**OUVERT** vert / **FERMÉ** corail / **OUVERTURE-FERMETURE…** ambre pendant l'attente de confirmation LoRaWAN), poignée qui pivote, anneau qui change de couleur. **Un tap = ouvrir/fermer** (envoie 01/02), verrouillé et cadenassé en mode AUTO/maintenance. Colonne raccourcie (hauteur 9→6). Un switch « Routage UI vanne » sépare les messages `valve` (→ commande) et `set_auto` (→ bascule AUTO) |
| U9 | **Boutons Ouvrir/Fermer du bas retirés** | Le robinet rotatif gère désormais l'ouverture/fermeture ; l'ancien widget « Commandes Principales » est réduit au seul bouton « Actualiser l'état de la vanne » (ping/demande de statut), restylé et centré (hauteur 2→1) |

## 🚿 Correctifs vanne & durée d'arrosage (4ᵉ passe) — `flows_85.json` → `flows_85_corrige.json`

Analyse du 27/07/2026 suite à deux constats utilisateur : « ça n'arrose que
5 min » et « la vanne ne s'ouvre que quelques secondes ». 5 nœuds modifiés,
tout le reste inchangé.

### 🔴 Le bug « la vanne ne s'ouvre que quelques secondes »

Cause racine : la gestion de la **file de downlinks TTN** en LoRaWAN classe A.

- La vanne ne reçoit qu'**un seul downlink par réveil** (2 ou 30 min).
- Toutes les commandes partaient en `down/push` = **ajout** en file, jamais
  remplacement.
- Le Chef d'Orchestre **relance** l'ordre non confirmé à chaque réveil
  (cooldown 10 s ≪ réveil 2 min) → doublons empilés côté TTN.
- **Rien ne vidait jamais la file** : ni le watchdog timeout, ni le Reset
  d'urgence, ni la coupure EcoFlow.

Les ordres périmés s'accumulaient donc chez TTN et se **rejouaient un par
réveil**, parfois longtemps après. Dès qu'un FERMER périmé se trouvait dans la
file derrière un OUVRIR (appui OUVRIR puis FERMER pendant que la vanne dort,
relances de fermeture du cycle précédent, fermeture de sécurité EcoFlow…), la
vanne ouvrait, envoyait son uplink de confirmation, et recevait le FERMER dans
la foulée → **ouverte quelques secondes, puis refermée**.

| # | Problème | Correction |
|---|----------|------------|
| V1 | Commandes vanne empilées en `down/push`, rejeu d'ordres périmés | « choix vanne » passe en **`down/replace`** : la dernière commande remplace toute la file TTN. Appuyer OUVRIR puis FERMER pendant le sommeil = seul FERMER s'exécute |
| V2 | La config « mode rapide » (port 11) pouvait se perdre → cycle d'arrosage cadencé à 30 min | L'ouverture AUTO embarque la config mode rapide **dans le même `down/replace`** (trame port 11 puis trame port 10) : la vanne repasse en réveil 2 min avant d'ouvrir, quoi qu'il arrive |
| V3 | Watchdog à 10 min fixes : toute commande envoyée en mode ÉCO (réveil 30 min) partait en erreur avant même que la vanne ne se réveille | **Timeout adaptatif** au mode de réveil courant : 10 min en mode rapide, réveil + 5 min (35 min) en mode éco |
| V4 | Au timeout, la commande expirée **restait en file TTN** et s'exécutait des heures plus tard — ouverture fantôme sans personne pour chronométrer la fermeture (risque d'inondation) | Le watchdog **purge la file TTN** (`down/replace` vide) en plus de remettre l'automatisme au repos |
| V5 | Le Reset d'urgence remettait les états à zéro mais laissait les ordres en attente chez TTN | Le Reset **purge aussi la file TTN** |

### 🟠 La durée d'arrosage plafonnée à 5 min

| # | Problème | Correction |
|---|----------|------------|
| V6 | Le curseur « Durée max d'arrosage » (page Réglages, 1–15 min) était **silencieusement écrasé** par le plafond du profil plante (5 min codé en dur dans chaque profil) : quoi qu'on règle, l'IA restait limitée à 5 min | Le curseur **prime désormais sur le profil** dès qu'on y touche (la valeur UI est marquée `maxIrrigationMinSource: "ui"` et le Pré-check lui donne la priorité). Sans réglage manuel, le plafond du profil reste la valeur par défaut |

**5 min, est-ce assez ?** Ordres de grandeur : 5 min ≈ 30 L (débit théorique
6 L/min) ; 2 arrosages/jour max = **60 L/jour sur 24 m² = 2,5 mm/jour**. En
plein été (évapotranspiration 5–6 mm/jour), c'est léger, même en goutte-à-goutte
souterrain paillé. Recommandation : **10 à 15 min par arrosage en été**
(120–180 L/jour = 5–7,5 mm) via le curseur Réglages — les garde-fous restent
tous actifs (capteur d'humidité, pluie, quota 200 L, écart 6 h, 2/jour max).
L'écart de 6 h entre arrosages est sain ; c'était le volume par arrosage qui
limitait. À recouper avec le débit **réel** mesuré par le débitmètre (« Litres
du jour ») plutôt que les 6 L/min théoriques.
