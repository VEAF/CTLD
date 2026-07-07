# Smoke

Sometimes the fastest way to mark a spot — a landing zone, a pickup point, a target for a
wingman — is to put coloured smoke on the ground. If your aircraft is set up for it, CTLD gives
you a **Smoke** submenu to drop grenades right where you are, and an optional auto-resume so a
marker keeps burning long after a single grenade would have died out.

## Drop Smoke

**Utility:** Places a coloured smoke grenade on the ground at your current position.

**How it works:** Pick a colour and CTLD drops that smoke on the ground directly beneath your
aircraft. Everyone on your coalition sees a short message confirming the drop (for example,
`<your unit> dropped RED smoke.`). DCS smoke burns for roughly 5 minutes and cannot be extended
natively — when it fades, drop another grenade, or use auto-resume below to keep it going.

**Activation:** F10 → CTLD → Smoke → **Drop Red Smoke** / **Drop Blue Smoke** /
**Drop Orange Smoke** / **Drop Green Smoke**

## Smoke Auto-Resume

**Utility:** Keeps your dropped smokes alive by automatically re-triggering them before they
expire, so a marker reads as a continuous signal.

**How it works:** The toggle is **per pilot** — you manage your own smokes, and it does not affect
anyone else. Every grenade you drop is tracked from the moment it leaves the aircraft, so smokes
you dropped *before* enabling auto-resume are picked up too.

- **[activate]** → the label switches to **[deactivate]**, and all your tracked smokes are
  re-triggered on a fixed interval (see [mission configuration](#mission-configuration)).
- **[deactivate]** → the label switches back to **[activate]**, your stored smoke positions are
  cleared, and any smoke currently burning simply fades out on its own.

A short message confirms the change: `Smoke auto-resume ON (270s interval)` or
`Smoke auto-resume OFF`.

**Activation:** F10 → CTLD → Smoke → **Smoke Auto-Resume [activate]** /
**Smoke Auto-Resume [deactivate]**

## Mission configuration

The Smoke submenu only appears on **transport aircraft** whose mission has enabled the feature,
and the auto-resume interval is set by the mission — not by you in the cockpit. Whether smoke is
available, and how often auto-resume re-fires, are decisions for the mission maker; see the
[Mission Maker guide](../mission-maker/index.md).
