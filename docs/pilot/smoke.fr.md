# Fumigène (smoke) { #smoke }

Parfois, le moyen le plus rapide de marquer un endroit — une landing zone, un point de pickup,
une cible pour un équipier — est de poser de la smoke colorée au sol. Si votre appareil est
configuré pour cela, CTLD vous donne un sous-menu **Smoke** pour larguer des grenades là où vous
vous trouvez, ainsi qu'un auto-resume optionnel afin qu'un marqueur continue de brûler bien
au-delà de la durée de vie d'une seule grenade.

## Drop Smoke

**Utilité :** Place une grenade de smoke colorée au sol à votre position actuelle.

**Fonctionnement :** Choisissez une couleur et CTLD largue cette smoke au sol directement sous
votre appareil. Tout le monde dans votre coalition voit un court message confirmant le largage
(par exemple, `<your unit> dropped RED smoke.`). La smoke de DCS brûle pendant environ 5 minutes
et ne peut pas être prolongée nativement — lorsqu'elle s'éteint, larguez une autre grenade, ou
utilisez l'auto-resume ci-dessous pour la maintenir active.

**Activation :** F10 → CTLD → Smoke → **Drop Red Smoke** / **Drop Blue Smoke** /
**Drop Orange Smoke** / **Drop Green Smoke**

## Smoke Auto-Resume

**Utilité :** Maintient vos smokes larguées actives en les redéclenchant automatiquement avant
leur expiration, afin qu'un marqueur soit perçu comme un signal continu.

**Fonctionnement :** Le toggle est **par pilote** — vous gérez vos propres smokes, et cela
n'affecte personne d'autre. Chaque grenade que vous larguez est suivie dès l'instant où elle
quitte l'appareil, de sorte que les smokes larguées *avant* d'activer l'auto-resume sont prises
en compte elles aussi.

- **[activate]** → le label bascule sur **[deactivate]**, et toutes vos smokes suivies sont
  redéclenchées à intervalle fixe (voir [configuration côté mission](#mission-configuration)).
- **[deactivate]** → le label rebascule sur **[activate]**, vos positions de smoke enregistrées
  sont effacées, et toute smoke en train de brûler s'éteint simplement d'elle-même.

Un court message confirme le changement : `Smoke auto-resume ON (270s interval)` ou
`Smoke auto-resume OFF`.

**Activation :** F10 → CTLD → Smoke → **Smoke Auto-Resume [activate]** /
**Smoke Auto-Resume [deactivate]**

## Configuration côté mission { #mission-configuration }

Le sous-menu Smoke n'apparaît que sur les **transport aircraft** dont la mission a activé la
fonctionnalité, et l'intervalle d'auto-resume est fixé par la mission — pas par vous dans le
cockpit. La disponibilité de la smoke, et la fréquence de redéclenchement de l'auto-resume, sont
des décisions du mission maker ; voir le [guide Mission Maker](../mission-maker/index.md).
