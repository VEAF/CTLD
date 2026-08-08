# Guide du concepteur de mission { #mission-maker-guide }

Cette section s'adresse aux **concepteurs de mission** — comment ajouter CTLD à une mission et le
configurer dans l'éditeur de mission de DCS et le fichier `CTLD_userConfig.lua`. Si vous souhaitez
*piloter* CTLD depuis le cockpit (le menu F10), consultez plutôt le [Guide du pilote](../pilot/index.md).

## Pour commencer { #getting-started }

**Téléchargez `ctld-tools.exe` depuis la [dernière release](https://github.com/VEAF/CTLD/releases) et
lancez-le.** C'est toute l'installation : l'outil porte CTLD et les sons de ses balises, et écrit
l'ensemble dans votre mission.

1. **Lancez l'outil.** Il s'ouvre dans votre navigateur, en local — sans installation, sans compte,
   sans rien à configurer au préalable. Si Windows le bloque au premier lancement, voir
   [ci-dessous](#windows-dit-quil-a-bloque-lapplication).
2. **« Ouvrir une config ou une mission… »** et choisissez votre `.miz` — ou partez des défauts CTLD
   si vous configurez avant d'avoir une mission. Ouvrir une mission qui contient déjà CTLD en
   récupère la configuration, prête à être modifiée : c'est ainsi que vous reprenez une mission
   préparée il y a des semaines, sans fichier annexe à conserver.
3. **Ajustez ce dont vous avez besoin** (les pages ci-dessous décrivent chaque domaine), puis
   **« Installer dans la mission… »**

L'outil écrit quatre choses dans le `.miz` : `CTLD.lua`, les deux fichiers son des balises, votre
configuration, et les déclencheurs MISSION START qui les chargent dans le bon ordre. Il indique
ce qu'il a écrit, et réinstaller remplace au lieu de dupliquer.

Le `CTLD.lua` qu'il écrit est celui **embarqué dans cet exe** : vous passez à une version plus récente
de CTLD en retéléchargeant l'outil une fois qu'une release est publiée — voir
[l'outil embarque son propre CTLD](ctld-tools.fr.md#the-tool-carries-its-own-ctld).

!!! info "Pourquoi un déclencheur joue les sons des balises au démarrage"
    L'un de ces déclencheurs joue les deux fichiers `.ogg` au démarrage de la mission. Il n'est pas là
    pour être entendu : l'éditeur de mission supprime tout fichier auquel aucun déclencheur ne fait
    référence lorsqu'il enregistre une mission, et sans lui vos balises deviendraient muettes dès que
    vous rouvririez la mission dans l'éditeur. Il s'exécute avant que quiconque soit en cockpit,
    personne ne l'entend donc.

### Windows dit qu'il a bloqué l'application

`ctld-tools.exe` n'est pas signé numériquement — un certificat coûte de l'argent qu'un projet
communautaire n'a pas de raison de dépenser —, donc Windows le considère comme venant d'un éditeur
inconnu. Le téléchargement n'a rien d'anormal ; il faut simplement le dire une fois :

- **« Windows a protégé votre ordinateur »** (la fenêtre bleue SmartScreen) → cliquez sur
  **Informations complémentaires**, puis sur **Exécuter quand même**.
- **Propriétés → Débloquer.** Si le fichier est arrivé par un navigateur, Windows le marque comme
  téléchargé depuis Internet. Clic droit sur `ctld-tools.exe` → **Propriétés** → cochez **Débloquer**
  en bas de l'onglet Général → **OK**, puis lancez-le.
- **Votre antivirus l'a mis en quarantaine.** Les exécutables en un seul fichier produits par
  PyInstaller sont un faux positif courant. Restaurez le fichier et ajoutez-lui une exclusion si votre
  antivirus insiste.

Chaque version est construite par un workflow GitHub public à partir des sources du tag : vous pouvez
vérifier d'où vient l'exécutable avant de le lancer.

??? note "Installer à la main"
    Tout ce que l'outil écrit est également attaché à chaque release, si vous préférez le faire
    vous-même :

    1. ajoutez `CTLD.lua` à la mission avec un déclencheur **MISSION START → DO SCRIPT FILE** — seul,
       CTLD tourne sur ses valeurs par défaut intégrées, ce qui suffit pour jouer ;
    2. ajoutez `beacon.ogg` et `beaconsilent.ogg` à la mission, sinon **les balises resteront
       muettes** ;
    3. pour personnaliser quoi que ce soit, ajoutez votre `CTLD_userConfig.lua` comme second
       déclencheur `DO SCRIPT FILE`, **avant** celui de `CTLD.lua` — le moteur lit la configuration
       au chargement.

Tous les réglages sont lus via `ctld.gs("paramName")` à l'exécution. Votre configuration est un
**instantané complet** porté par `ctld.configUser` dans `CTLD_userConfig.lua`, et non une liste de
surcharges — voir [Configuration](configuration.md).

## Sujets de configuration { #configuration-topics }

| Page | Ce que vous configurez |
| --- | --- |
| [Configurer avec `ctld-tools`](ctld-tools.fr.md) | La façon recommandée de configurer CTLD : une application locale, des formulaires au lieu de Lua, injection dans votre `.miz` |
| [Configuration](configuration.md) | Réglages globaux et capacités par appareil (`capabilitiesByType`) |
| [Configuration des zones](zones.md) | Zones de troops (TRZ, y compris les objectifs d'extraction), zones logistiques (LGZ), zones de waypoint (WPZ), zones IA (AIZ) |
| [Scènes & FOB](scenes-fob.md) | Déploiement de scènes (FARP, champ de mines…) et Forward Operating Bases |
| [Catalogue de crates](crates-catalogue.md) | `spawnableCrates`, et les définitions de crate/véhicule/AA/JTAC que les pilotes peuvent spawner |
| [Champ de mines](minefield.md) | Configuration de la scène champ de mines |
| [Traductions](translations.md) | Localisation et surcharges de traduction |
| [API legacy](legacy-api.md) | Compatibilité `ctld.*` v1 pour les scripts de mission existants |
