# Guide du concepteur de mission { #mission-maker-guide }

Cette section s'adresse aux **concepteurs de mission** — comment ajouter CTLD à une mission et le
configurer dans l'éditeur de mission de DCS et le fichier `CTLD_userConfig.lua`. Si vous souhaitez
*piloter* CTLD depuis le cockpit (le menu F10), consultez plutôt le [Guide du pilote](../pilot/index.md).

## Pour commencer

1. Ajoutez `CTLD.lua` à votre mission avec un déclencheur **DO SCRIPT FILE**.
2. Ajoutez éventuellement un second déclencheur **DO SCRIPT FILE** qui charge votre
   `CTLD_userConfig.lua` pour surcharger les valeurs par défaut.
3. Configurez les éléments dont vous avez besoin à l'aide des pages ci-dessous.

Tous les réglages sont lus via `ctld.gs("paramName")` à l'exécution ; vous les définissez dans
`CTLD_userConfig.lua` (`_cfg.settings[...]`).

## Sujets de configuration

| Page | Ce que vous configurez |
| --- | --- |
| [Configuration](configuration.md) | Réglages globaux et capacités par appareil (`capabilitiesByType`) |
| [Configuration des zones](zones.md) | Zones de troops (TRZ, y compris les objectifs d'extraction), zones logistiques (LGZ), zones de waypoint (WPZ), zones IA (AIZ) |
| [Scènes & FOB](scenes-fob.md) | Déploiement de scènes (FARP, champ de mines…) et Forward Operating Bases |
| [Catalogue de crates](crates-catalogue.md) | `spawnableCrates`, et les définitions de crate/véhicule/AA/JTAC que les pilotes peuvent spawner |
| [Champ de mines](minefield.md) | Configuration de la scène champ de mines |
| [Traductions](translations.md) | Localisation et surcharges de traduction |
| [API legacy](legacy-api.md) | Compatibilité `ctld.*` v1 pour les scripts de mission existants |
