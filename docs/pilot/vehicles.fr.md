# Véhicules { #vehicles }

Certains avions de transport peuvent embarquer un **véhicule terrestre entier** — un HMMWV, un
camion-citerne, une pièce de DCA — au lieu de le décomposer en [crates](crates.md). Vous l'amenez
tout de même par les airs là où on en a besoin puis vous le posez, mais il n'y a pas d'étape
d'assemblage à l'arrivée : le véhicule repart prêt à combattre.

Le transport de véhicule entier est une capacité de l'appareil. Seuls les avions que la mission
autorise pour cela (la capacité `canTransportWholeVehicle`) affichent les menus de véhicule
ci-dessous. Tout le reste — y compris le UH-1H — déplace les véhicules à la manière des crates :
[packez-les en crates](pack.md), transportez les crates en sling ou par le menu, puis dépackez à
destination. Voir [Crates](crates.md).

Les véhicules que vous pouvez emporter doivent déjà se trouver au sol près de vous — placés par le
mission maker, ou [dépackés](crates.md) depuis des crates que vous avez livrés. Il n'existe aucune
action F10 qui fait apparaître un véhicule sorti de nulle part dans une zone logistique ;
**Request Equipment** vous remet toujours des crates, jamais un véhicule fini.

## Charger un véhicule (menu) { #load-a-vehicle-menu }

**Utilité :** Ramasse un véhicule terrestre proche en entier, afin que vous puissiez le transporter
par les airs sans avoir à le packer en crates au préalable.

**Fonctionnement :** Posez-vous à moins de `maximumDistancePackableUnitsSearch` (200 m par défaut) du
véhicule. CTLD liste les véhicules que vous pouvez soulever — filtrés selon votre coalition et selon
les types pour lesquels votre appareil est habilité (`loadableVehiclesRED` / `loadableVehiclesBLUE`).
Choisissez-en un et il est chargé virtuellement : le véhicule disparaît de la carte, son poids
s'ajoute à celui de votre appareil, et il voyage avec vous jusqu'à ce que vous le déchargiez. Vous
devez être au sol pour charger — tentez-le en vol stationnaire et vous obtenez **"Land to load
vehicles"**. Le nombre de véhicules que vous pouvez emporter à la fois est plafonné par appareil via
`maxWholeVehiclesOnboard` (1 par défaut) ; à la limite vous obtenez **"Cannot load more vehicles
(%1/%2)."**

**Activation :** F10 → CTLD → **Vehicle Commands** → **Load / Extract Vehicles** → *[nom du véhicule]*
(nécessite d'être posé ; le sous-menu est grisé en vol et affiche **"No vehicles nearby"** quand
aucun n'est à portée).

## Charger un véhicule (dynamic cargo) { #load-a-vehicle-dynamic-cargo }

**Utilité :** Permet à un C-130 ou un Il-76 d'avaler un véhicule par la rampe de chargement à la
manière dont DCS gère son propre dynamic cargo — sans aucun clic de menu.

**Fonctionnement :** Faites entrer le véhicule dans la soute de l'appareil. CTLD surveille la boîte
englobante de la soute ; lorsque le véhicule est à l'intérieur, il est chargé automatiquement et DCS
gère le poids nativement (les limites de nombre et de poids par appareil ci-dessus ne s'appliquent
**pas** à ce chemin). Le déchargement se fait de la même façon en sens inverse — le véhicule
réapparaît au sol lorsqu'il quitte la soute.

**Activation :** Automatique lorsque le véhicule entre dans la soute. Seuls les appareils de classe
C-130 / Il-76 (capables de dynamic cargo) utilisent ce chemin ; les autres transports capables
chargent via le menu ci-dessus.

## Décharger un véhicule { #unload-a-vehicle }

**Utilité :** Repose au sol, là où vous êtes, un véhicule que vous transportez.

**Fonctionnement :** Pour un véhicule chargé par le menu, CTLD le fait réapparaître (spawn) au sol
près de l'appareil sous son nom d'origine. Pour un véhicule en dynamic cargo, il ressort de la soute.
Dans les deux cas, le véhicule revient prêt à être rechargé plus tard.

**Activation :** F10 → CTLD → **Vehicle Commands** → **Unload Vehicles** → *[nom du véhicule]*
(nécessite d'être posé ; en vol avec un véhicule à bord, affiche **"Land to unload vehicles"**, et le
sous-menu est entièrement masqué quand rien n'est chargé). Pour larguer un véhicule par les airs à la
place, voir [Parachute](parachute.md) — **Parachute Vehicle** apparaît dans le même menu quand vous
êtes en vol avec un véhicule chargé.

## Packer un véhicule en crates { #pack-a-vehicle-into-crates }

**Utilité :** Retransforme un véhicule terrestre en crates afin que n'importe quel transport — y
compris les avions incapables de porter des véhicules entiers — puisse le déplacer. C'est l'inverse
du dépackage.

**Fonctionnement :** Posez-vous près d'un véhicule packable (à moins de
`maximumDistancePackableUnitsSearch`, 200 m). Le véhicule est retiré et ses `cratesRequired` crates
apparaissent autour de vous : dans le secteur **avant** (±45°) pour un hélicoptère, dans le secteur
**arrière** pour un C-130 / Il-76. De là, déplacez les crates en sling-load ou par le menu et
[dépackez-les](crates.md) à destination. Le packing n'est disponible que si la mission l'autorise
(`enablePackingVehicles`).

**Activation :** F10 → CTLD → **Crate Commands** → **Pack Equipt** → *[nom du véhicule]* (apparaît au
sol quand un véhicule packable est à proximité). Voir aussi [Pack](pack.md).

## Pour les mission makers { #for-mission-makers }

Quels avions peuvent porter des véhicules entiers, quels types de véhicules chacun peut soulever,
combien à la fois, et leurs poids sont tous définis dans la configuration des capacités des
appareils. Voir le [catalogue des crates](../mission-maker/crates-catalogue.md).
