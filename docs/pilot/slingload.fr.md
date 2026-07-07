# Sling-load

Le sling-load vous permet de récupérer un crate en **stationnant au-dessus de lui** — sans
menu F10, sans équipe au sol. Vous maintenez un hover stable au-dessus du crate, un compte à
rebours s'écoule, et le crate se raccroche sous votre hélicoptère. Vous le transportez ensuite
lentement et à basse altitude là où il est nécessaire, puis vous le déposez.

Il s'agit du sling-load *virtuel* de CTLD : il surveille votre position par rapport aux crates
à proximité plutôt que d'utiliser le crochet à cargo natif de DCS. Le mécanisme fonctionne donc
de façon identique sur tous les hélicoptères pour lesquels la mission l'active, et il ne dépend
jamais d'un vrai crochet gréé de votre part.

!!! note "Est-il disponible sur votre appareil ?"
    Le sling-load ne fonctionne que si le créateur de mission a défini `canSlingload = true`
    pour votre type d'appareil. Les avions à voilure fixe ne peuvent pas faire de hover, ils
    n'y ont donc jamais accès. Si rien ne se passe lorsque vous stationnez au-dessus d'un
    crate, votre appareil n'est probablement pas configuré pour cela — voir
    [Configuration](../mission-maker/configuration.md) dans le guide du créateur de mission.

## Accrocher un crate

Pour accrocher un crate, placez-vous en hover stable directement au-dessus de lui :

1. **Placez-vous au-dessus du crate.** Maintenez votre altitude de sorte que l'écart entre vous
   et le crate soit compris entre `minimumHoverHeight` et `maximumHoverHeight` — **7.5 m à 12 m**
   par défaut.
2. **Restez centré.** Restez à moins de `maxDistanceFromCrate` — **5.5 m** à l'horizontale — du
   crate.
3. **Tenez le hover.** Une fois dans la fenêtre, un compte à rebours à l'écran démarre. Tenez-le
   pendant `hoverTime` secondes — **10 s** par défaut.

Pendant que vous tenez la position, un message défilant s'affiche : *"Hovering above … crate.
Hold hover for N seconds!"* Si vous vous éloignez trop — hors de la fenêtre de distance ou
d'altitude — **le compte à rebours s'arrête et se réinitialise** ; revenez dans la fenêtre et il
recommence. Si vous êtes proche mais mal réglé en altitude, CTLD vous indique que vous êtes
*trop bas* ou *trop haut* pour accrocher.

Lorsque le compte à rebours atteint zéro, le crate s'accroche automatiquement et vous obtenez
*"Slingloaded … crate!"*. Le poids de votre hélicoptère est mis à jour pour refléter la charge.

!!! tip "Un crate à la fois — en général"
    Vous ne pouvez accrocher un crate que tant que vous êtes sous la capacité de crates de votre
    appareil (`maxCratesOnboard`, un par défaut). Les crates qui font déjà partie d'une scène
    placée (comme un FOB unpacké) ne peuvent pas être accrochés.

Si la mission a désactivé la récupération en hover (`enableHoverSlingload = false`), le compte à
rebours ne s'exécute jamais. Vous pouvez toujours charger un crate par le sol, via **F10 → CTLD
→ Crate Commands → Load Crate**, tant que `loadCrateFromMenu` est activé.

## Transporter et déposer

Une fois un crate accroché, deux entrées apparaissent sous **Crate Commands** — mais **uniquement
tant que vous êtes en vol avec un sling-load actif** :

**Release Sling-load** — la manière contrôlée de déposer un crate :

- Disponible uniquement une fois que vous êtes bas : votre hauteur au-dessus du sol (AGL) doit
  être inférieure ou égale à `maximumHoverHeight` (environ 12 m). Plus haut que cela et CTLD
  refuse, en vous demandant de descendre.
- Le crate est déposé proprement sur le sol sous vous.
- À utiliser pour une livraison de précision.

**Cut Sling-load** — un largage d'urgence, disponible à n'importe quelle altitude :

- **Au-dessus de 40 m AGL**, le crate est **détruit** à l'impact — il tombe de trop haut et se
  casse.
- **À 40 m AGL ou en dessous**, le crate est largué et atterrit en conservant votre inertie
  actuelle. Plus vous allez vite, plus il glisse loin de la verticale sous vous. Ralentissez
  avant de couper si vous voulez qu'il atterrisse là où vous l'attendez.

## Restez lent

Il existe une limite de vitesse stricte lorsque vous transportez un crate en sling. Dépassez
`maxSlingloadSpeed` — **50 m/s, soit environ 180 km/h**, par défaut — et le crate est **arraché
et perdu**. Vous recevez un avertissement et le crate a disparu. Transportez votre cargo lentement
et à basse altitude.

## Voir aussi

- [Crates](crates.md) — spawn, chargement depuis le menu, dépose et unpack des crates.
- [Configuration](../mission-maker/configuration.md) — activer le sling-load par appareil
  (`canSlingload`) et régler la fenêtre de hover, la limite de vitesse et les temporisations.
