# Sling-load

Sling-load lets you pick up a crate by **hovering over it** — no F10 menu, no ground crew.
You hold a steady hover above the crate, a countdown runs, and the crate hooks up under your
helicopter. You then fly it low and slow to where it is needed and set it down.

This is CTLD's *virtual* sling-load: it watches your position relative to nearby crates rather
than using the DCS native cargo hook. That means the mechanic works the same across every
helicopter the mission enables it on, and it never relies on you rigging a real hook.

!!! note "Is it available on your aircraft?"
    Sling-load only works if the mission maker set `canSlingload = true` for your aircraft
    type. Fixed-wing aircraft cannot hover, so they never get it. If nothing happens when you
    hover over a crate, your airframe probably is not configured for it — see
    [Configuration](../mission-maker/configuration.md) in the Mission Maker guide.

## Hooking a crate

To hook a crate, put yourself in a stable hover directly over it:

1. **Get above the crate.** Hold your height so the gap between you and the crate is between
   `minimumHoverHeight` and `maximumHoverHeight` — **7.5 m to 12 m** by default.
2. **Stay centred.** Keep within `maxDistanceFromCrate` — **5.5 m** horizontally — of the crate.
3. **Hold the hover.** Once you are in the window, an on-screen countdown starts. Hold it for
   `hoverTime` seconds — **10 s** by default.

While you hold position you get a running message: *"Hovering above … crate. Hold hover for N
seconds!"* If you drift too far — out of the distance or height window — **the countdown stops
and resets**; get back in the window and it starts over. If you are close but off on height,
CTLD tells you you are *too low* or *too high* to hook.

When the countdown reaches zero the crate hooks up automatically and you get *"Slingloaded …
crate!"*. Your helicopter's weight updates to reflect the load.

!!! tip "One crate at a time — usually"
    You can only hook a crate while you are below your aircraft's crate capacity
    (`maxCratesOnboard`, one by default). Crates that are already part of a placed scene (such
    as an unpacked FOB) cannot be hooked.

If the mission has hover pickup switched off (`enableHoverSlingload = false`), the countdown
never runs. You can still load a crate the ground way, from **F10 → CTLD → Crate Commands →
Load Crate**, as long as `loadCrateFromMenu` is enabled.

## Carrying and dropping

Once a crate is on the hook, two entries appear under **Crate Commands** — but **only while you
are airborne with a live sling-load**:

**Release Sling-load** — the controlled way to set a crate down:

- Only available once you are low: your height above ground (AGL) must be at or below
  `maximumHoverHeight` (about 12 m). Higher than that and CTLD refuses, telling you to descend.
- The crate is placed neatly on the ground below you.
- Use this for precision delivery.

**Cut Sling-load** — an emergency drop, available at any altitude:

- **Above 40 m AGL** the crate is **destroyed** on impact — it falls too far and breaks.
- **At or below 40 m AGL** the crate drops and lands with your current momentum carried into it.
  The faster you are moving, the further it skates from directly below you. Slow down before you
  cut if you want it to land where you expect.

## Keep it slow

There is a hard speed limit while you carry a slung crate. Exceed `maxSlingloadSpeed` — **50 m/s,
roughly 180 km/h**, by default — and the crate is **torn loose and lost**. You get a warning and
the crate is gone. Fly your cargo low and slow.

## See also

- [Crates](crates.md) — spawning, loading from the menu, dropping and unpacking crates.
- [Configuration](../mission-maker/configuration.md) — enabling sling-load per aircraft
  (`canSlingload`) and tuning the hover window, speed limit and timings.
