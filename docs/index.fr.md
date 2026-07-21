# CTLD v2

**Combat Troops and Logistics Dispatcher** — framework de scripting de mission pour DCS World.

CTLD permet aux équipages d'hélicoptères de transporter des troops, de déployer des FOB, de
sling-loader des crates, d'opérer des JTAC, et bien plus — le tout piloté par un menu F10 et un
moteur Lua v2 modulaire.

## Liens rapides { #quick-links }

- [Guide pilote](pilot/index.md) — opérer CTLD depuis le cockpit (menu F10)
- [Guide mission maker](mission-maker/index.md) — configurer CTLD dans votre mission
- [Documentation développeur](developer/index.md) — architecture, sous-systèmes, events, build & test

## Installation

1. Téléchargez `CTLD.lua` depuis la [dernière release](../../releases/latest).
2. Ajoutez un trigger **DO SCRIPT FILE** dans le Mission Editor de DCS pointant vers `CTLD.lua`.
3. Optionnellement, ajoutez un second trigger chargeant votre `CTLD_userConfig.lua` pour surcharger
   les valeurs par défaut.

## Compatibilité { #compatibility }

- DCS World (toute carte)
- Lua 5.1 (bac à sable DCS)
- Aucune dépendance à MIST requise
