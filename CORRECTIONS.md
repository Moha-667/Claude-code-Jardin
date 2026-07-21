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
