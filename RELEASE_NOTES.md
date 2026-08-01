# CTLD 2.0.0-rc3 — version candidate

CTLD 2.0 est une **réécriture complète** du script CTLD v1 : le code monolithique devient un
ensemble de modules Lua **testables** (architecture orientée objet Manager/Entité), couvert par une
intégration continue — build unique, plus de 1 100 tests unitaires et fonctionnels, plus des tests
d'intégration en DCS réel.

Cette **rc3** fait parler CTLD. La plupart de ce qu'elle apporte tient en une idée : ce qui était
**silencieux ou inaccessible** devient dit ou appelable. Un point logistique se déclare par type
d'appareil au lieu d'être nommé unité par unité, une balise se pose depuis un script sans qu'un
pilote soit aux commandes, une zone d'embarquement posée sur un porte-avions suit enfin le
porte-avions — et trois situations qui vous étaient cachées sont désormais annoncées au démarrage.

Elle ajoute aussi les **Gazelle et le Yak-52**, absents du catalogue depuis le début.

## Nouveautés

- **Déclarez vos points logistiques par type d'appareil.** Le nouveau réglage `logisticUnitTypes`
  prend des noms de types DCS : chaque unité **et chaque objet statique** de la mission dont le type
  y figure devient un point logistique, sans que vous ayez à le nommer. La zone suit l'objet, donc un
  porte-avions garde son point logistique en route. Plus besoin de recopier dix noms d'unités d'une
  mission à l'autre :

  ```yaml
  logisticUnitTypes:
  - Stennis
  - CVN_71
  - FARP Ammo Dump Coating
  ```

  Un type listé qu'aucun objet de la mission ne porte n'est pas une erreur : c'est un catalogue,
  réutilisable tel quel d'une mission à l'autre.

- **Idem pour les points d'embarquement sur navire**, avec `troopZoneShipTypes`. Chaque navire du
  type listé devient un point d'embarquement à stock illimité, ancré au bâtiment.

- **Une balise radio peut être posée par un script.** Jusqu'ici, tout passait par le menu F10 d'un
  pilote : une FARP construite par script ne pouvait pas porter de balise. `createAtPoint()` la pose
  en un point quelconque et rend ses trois fréquences ; `removeBeacon()` la retire par son nom :

  ```lua
  local beacon = CTLDBeaconManager.getInstance():createAtPoint(
      point, coalition.side.BLUE, country.id.USA,
      { name = "FARP Alpha NDB", batteryMinutes = -1 })
  -- beacon:freqText() → "245.00 kHz - 350.50 / 45.20 MHz"
  ```

- **Cinq appareils de plus.** Les quatre **Gazelle** (`SA342L`, `SA342M`, `SA342Minigun`,
  `SA342Mistral`) et le **Yak-52** ont enfin leurs capacités déclarées : un soldat, pas de caisse —
  ce que la v1 leur donnait. Leurs pilotes récupèrent le transport de troupes, les balises et les
  fumigènes.

## Changements importants pour les concepteurs de mission

⚠️ **Le Ka-50 n'est plus un transport.** En v1, il élinguait des caisses et embarquait des soldats —
non par choix, mais parce qu'il ne figurait dans aucune des deux tables de capacités et héritait des
valeurs par défaut. CTLD 2 ne reprend pas ce comportement : un hélicoptère d'attaque monoplace n'est
pas un transport. Ses pilotes gardent le menu CTLD, le RECON et le statut JTAC ; ils perdent les
caisses, les troupes et les balises. **Si votre mission en avait besoin, ajoutez l'entrée
vous-même** — c'est de la configuration, pas du comportement moteur, et le guide de migration
explique comment.

- **Une zone d'embarquement posée sur un navire utilise un rayon de 200 m**, la valeur de la v1, au
  lieu de suivre le réglage `maximumDistancePackableUnitsSearch`. Sans effet si vous n'aviez pas
  modifié ce réglage.

- **Pour les auteurs de scripts** : `createAtZone(..., batteryLife = -1, ...)` signifie désormais
  « n'expire jamais ». Auparavant, cette valeur produisait une balise dont la batterie était déjà à
  plat.

- **Trois situations qui vous étaient cachées sont désormais annoncées au démarrage**, dans le
  rapport CTLD :
    - une configuration v1 qui porte encore `dropOffZones` — ce réglage n'est pas lu par CTLD 2, et
      le message vous indique son remplaçant (une entrée `aiZones` avec `isDropoff: true`) ;
    - une zone IA ignorée parce que son nom est déjà pris par une autre zone ;
    - un nom de type DCS que rien dans la mission ne pourra faire correspondre, refusé par
      `ctld-tools` avant même que la mission tourne.

## Corrections visibles en jeu

- **Une zone d'embarquement portée par un navire suit enfin son navire.** Elle était figée à la
  position du bâtiment au démarrage de la mission : un porte-avions appareillait et laissait son
  point d'embarquement au milieu de l'eau, sans le moindre message. La v1 recalculait la position à
  chaque vérification ; ce comportement est rétabli. Rien à changer dans vos missions.

- **Une entrée `aiZones` ignorée le dit.** Quand son nom est déjà utilisé par une autre zone, elle
  était écartée en silence et vous obteniez une zone IA qui ne faisait rien. Le piège est facile à
  tendre : une zone `TRZ_dropzone1_B_0_nil_0` occupe le nom `dropzone1`, donc une zone IA appelée
  `dropzone1` — même s'il s'agit d'une zone de l'éditeur bel et bien différente — entrait en
  collision avec elle. La correction tient dans deux noms distincts.

- **`ctld-tools` accepte les unités moddées que vous déclarez.** Le réglage `modTypes` existe
  précisément pour cela, mais l'outil rejetait quand même une caisse moddée et bloquait l'export.

## Documentation

- Le **guide de migration v1 → v2** gagne deux sections : ce que devient `dropOffZones` (avec un
  exemple avant/après), et quels appareils sont des transports — dont l'explication du cas Ka-50.
- La page **Zones** énonce une règle qui n'était écrite nulle part : `TRZ_`, `WPZ_`, les zones IA et
  la table héritée `troopZones` partagent **un seul** espace de noms, et la première zone
  enregistrée l'emporte.
- La page **Configuration** ne prétend plus qu'un appareil absent du catalogue n'a aucun menu CTLD :
  il en a un, il ne transporte simplement rien. « Le menu est là mais il est vide » a maintenant une
  cause documentée.

## Contributeurs

**FullGas** (développeur principal), **Zip** (assistance technique) — VEAF.

Cette rc3 vient de l'audit d'intégration mené pour brancher les **VEAF Mission Creation Tools** sur
CTLD 2 : quatre manques y ont été trouvés, tous corrigés ici, et trois autres défauts ont été
découverts en chemin.
