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

## 🌊 Design « Dashboard Ocean » (4ᵉ passe)

Implémentation fidèle du design claude.ai « Dashboard Ocean »
(`Dashboard Ocean.dc.html`) : les écrans du design sont reconstruits tels
quels — chaque page du dashboard est désormais **un seul template plein
écran** reprenant le markup du design (entête « 🌿 Mon jardin », navigation
pilule à emojis, cartes CAPTEUR / ACTIONNEUR, jauge circulaire, bouton-vanne
organique, tuiles, hero météo, anneau de batterie conique, page Réglages avec
modales), branché sur les vraies données du système.

| # | Changement | Détail |
|---|------------|--------|
| O1 | **1 page = 1 template Ocean** | Les 20 anciens widgets (verre gris) et leurs groupes sont remplacés par 5 templates : 🌊 Page Jardin / Météo / IA / EcoFlow / Réglages. Les nœuds de données (Capteur, Litres du jour, agrégateur État système, Formatage météo, energie_ok, Logger Central, 📊 Logger, Set Profil, Set Maintenance…) sont recâblés vers ces nouvelles pages |
| O2 | **Page Jardin** | Bandeaux d'alerte (coupure énergie, arrosage en cours, maintenance), carte 📡 CAPTEUR (jauge circulaire d'humidité, température, litres du jour, barre de quota en dégradé sauge→terracotta, batteries capteur/vanne), carte 🔧 ACTIONNEUR (bouton-vanne organique OUVRIR/FERMER avec états en attente LoRaWAN, interrupteur AUTO, sélecteur ⚡ rapide / 🐌 lent, bouton ↻ actualiser), tuiles EcoFlow / Eau restante / Décision IA, journal d'événements |
| O3 | **Page Météo** | Hero en dégradé océan (ville, température 64 px, ressenti, min/max, pluie attendue), bandeau 24 h défilant, prévision 8 jours avec barres min→max, tuiles qualité de l'air / vent / UV / soleil — alimentés par le payload Open-Meteo existant |
| O4 | **Page IA** | Badge de décision (ARROSAGE terracotta / VEILLE sauge / PAUSE), raison en Lora 21 px, confiance, profil actif + bouton « Modifier ⚙️ », 6 tuiles de stats (humidité, seuil, écart, quota restant, arrosages du jour, âge capteur), journal des décisions en table Heure / Décision / Raison / Volume |
| O5 | **Page EcoFlow** | Anneau conique de charge (`conic-gradient`, couleur selon coupure/reprise), tuiles ☀️ entrée solaire / 🔌 sortie / ⏳ temps restant / connexion, carte Alertes avec seuils de coupure et statut détaillé |
| O6 | **Page Réglages** | Profil de culture en puces façon segmented control (tous les profils réels), 6 tuiles de seuils du profil actif, cartes 🔩 Matériel et 🌍 Système avec modales (fréquence de réveil de la vanne câblée en réel), carte 🔧 Mode maintenance avec interrupteur |
| O7 | **Commandes** | Les envois restent identiques : `valve 01/02/80`, `set_auto`, `config 02/1E`, `set_plant_profile`, `set_maintenance`, `clear-log`. Le switch « Routage UI vanne » gagne une règle `config` ; un switch « Routage UI réglages » distribue les ordres de la page Réglages |
| O8 | **Style global** | Palette océan en variables CSS + classes `oc-*` partagées, Lora (Google Fonts) pour les titres, chrome Dashboard 2.0 masqué (app bar / tiroir) au profit de l'entête et de la navigation du design, `prefers-reduced-motion` respecté |

## 🗂 Réorganisation de l'éditeur (5ᵉ passe)

L'onglet « Arrosage jardin » était devenu illisible (55 nœuds enchevêtrés).
Réorganisation sans aucun changement de logique — mêmes nœuds, mêmes messages :

| # | Changement | Détail |
|---|------------|--------|
| R1 | **4 onglets thématiques** | 🌱 Arrosage jardin (logique + LoRaWAN), 🌊 Dashboard Ocean (les 5 pages UI + style + routeur réglages), 🌤 Météo, ⚡ EcoFlow. Les pages UI n'utilisent pas le contexte `flow.*`, elles pouvaient donc changer d'onglet ; toute la logique reste sur « Arrosage jardin » (contexte de flux partagé) |
| R2 | **Sections groupées** | Chaque onglet est rangé en bandes étiquetées : ⚙️ Config & supervision, 📡 Uplink LoRaWAN, 🎛 Vanne — état & AUTO, 📤 Downlink LoRaWAN, 🤖 Pilotage IA, 🛟 Sécurité & reset — et l'équivalent sur Météo/EcoFlow. Disposition en couches gauche → droite (sources → traitements → sorties) |
| R3 | **Nœuds link à la place des câbles longue distance** | Les deux gros points de convergence (« Logger Central », « 🧭 État système ») et tous les échanges inter-onglets passent par des paires link in/out nommées (« Capteur (Dragino) → », « → Page Jardin (Ocean) »…). 29 link out + 14 link in créés ; plus aucun câble ne traverse l'écran ni les onglets |
| R4 | **Vérifié dans l'éditeur** | Import chargé dans un Node-RED réel et inspecté onglet par onglet (captures) : aucune référence cassée, aucun câble inter-onglets, aucune collision de position |

## 🛡 Sécurité énergie EcoFlow désactivable (6ᵉ passe)

À la demande de l'utilisateur : l'arrosage ne doit plus se bloquer quand
l'EcoFlow est hors ligne. Les verrous énergie (coupure ≤ 10 %, données
absentes/périmées > 15 min) passent derrière un drapeau global
`ecoflow_guard`, **désactivé par défaut**, réactivable par l'interrupteur
**🛡 Sécurité énergie EcoFlow** de la page Réglages.

| # | Changement | Détail |
|---|------------|--------|
| G1 | **Verrous conditionnés** | `choix vanne`, `Config fréquence vanne`, `Sauver AUTO`, `Pré-check`, `Parse & Decide` : les conditions `ecoCutoff`/`ecoStale` ne s'appliquent que si `ecoflow_guard === true`. `🛑 Coupure énergie EcoFlow` ignore les événements de coupure quand la sécurité est OFF (les reprises restent traitées) ; la branche de test « Sécurité énergie avant ouverture » suit le même drapeau |
| G2 | **Interrupteur UI** | Nouvelle carte sur la page Réglages (topic `set_ecoflow_guard`, handler « 🛡 Sécurité EcoFlow ON/OFF », état resservi à l'ouverture de page). L'agrégateur État système expose `ecoflow_guard` |
| G3 | **Visibilité** | Page Jardin : le bandeau rouge « Coupure énergie » n'apparaît que si la sécurité est active ; sécurité OFF → bandeau orange permanent « Sécurité énergie EcoFlow désactivée » |
| G4 | **Ce qui ne change pas** | La surveillance EcoFlow continue (lecture 5 min, watchdog, alertes, page EcoFlow) — seul le blocage de l'arrosage est débrayé. Vérifié en rendu réel + syntaxe JS de toutes les fonctions contrôlée |

## 💾 Persistance & rechargement des journaux (7ᵉ passe)

Constat utilisateur : « le journal ne retient pas l'historique ». Deux causes :

| # | Cause | Correction |
|---|-------|------------|
| P1 | **Contexte en mémoire vive** : sans `contextStorage: { default: { module: "localfilesystem" } }` dans `settings.js`, journal, historique IA, quota, calibration et états sont perdus à chaque redémarrage de Node-RED | Réglage côté serveur documenté pas à pas dans NOTICE.md §12 (aucun changement de flow possible pour ça — c'est la config du serveur) |
| P2 | **Rien n'était rejoué à l'ouverture d'une page** : le dashboard ne conserve que le *dernier* message reçu par page — l'état système (30 s) écrasait le journal et la mesure capteur, qui restaient vides jusqu'au prochain événement | À chaque ouverture de page (`$pageview`) : le Logger Central renvoie l'historique complet, et l'agrégateur État système embarque désormais la dernière mesure capteur (humidité, température, batterie) et le mode de réveil vanne — les pages Jardin et IA se remplissent immédiatement |

## ⚙️ Page Réglages complète du design (8ᵉ passe)

La page Réglages reprend désormais tout l'onglet Réglages du design
« Dashboard Ocean » — et chaque popup pilote la **vraie** configuration :

| # | Élément | Branchement réel |
|---|---------|------------------|
| S1 | Puces de profils avec emojis (🌿🍅🥬🥒🌱🌾) | Les 6 profils réels de `config_jardin`, libellés raccourcis |
| S2 | Popup 💧 Arrosage | `dailyWaterQuotaL` (20–400 L), `maxIrrigationMin` (1–15 min), fenêtre `minHour`–`maxHour`, blocage pluie `rainDailyBlockMm` (interrupteur = seuil 999 → désactivé) — écrits dans `config_jardin` par la nouvelle fonction « ⚙️ Réglages jardin (UI) » |
| S3 | Popup 🔩 Matériel | Fréquence de réveil vanne (réelle), **offset de calibration** appliqué désormais à l'humidité mesurée dans « Capteur (Dragino) », **seuil batterie EcoFlow** rendu réglable (« EcoFlow → energie_ok » lit `ecoflow_cutoff_soc`, reprise = seuil + 15), bouton « Tester la communication vanne » (ping 0x80 réel) |
| S4 | Popup 🔔 Notifications | 3 préférences persistées (gel, quota, batterie) ; « batterie » coupe réellement les alertes EcoFlow (📢 Formatter) |
| S5 | Popup 🌍 Système | Unités (litres/°C, gallons/°F affichés « bientôt »), ville météo, état LoRaWAN et appareils |
| S6 | Amorçage | `$pageview` déclenche aussi Set Profil Plante, Set Maintenance et la nouvelle fonction réglages : la page se remplit dès l'ouverture |
