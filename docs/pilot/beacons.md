# Beacons

Radio beacons are deployable navigation aids you drop from your aircraft. Each beacon
transmits on three frequencies at once — one you can home on with your ADF needle, plus a
UHF and an FM channel — so any coalition aircraft can find the spot you marked: a landing
zone, a rendezvous, a forward site, whatever you need to point people at.

Every beacon runs on a battery. Once it is flat the beacon shuts itself down and disappears,
so you do not have to police old beacons cluttering the airspace.

## Deploying a beacon

**Utility:** Marks your current position with a navigation beacon the whole coalition can
tune and home to.

**How it works:** CTLD spawns the beacon at your aircraft and picks three free frequencies
for it — a VHF (ADF) channel, a UHF channel and an FM channel, all unique so no two active
beacons collide. Transmission starts about a second after the drop. The coalition gets a
text message with the assigned frequencies, for example:

```
Navigation beacon deployed - 245.00 kHz - 350.50 / 45.20 MHz
```

On the ground the beacon is placed a few metres behind your aircraft so the ground unit does
not spawn inside you; airborne, it drops at your position.

**Activation:** F10 → CTLD → Radio Beacons → Drop Beacon

## Removing a beacon

**Utility:** Takes down a beacon you no longer need.

**How it works:** CTLD removes the closest friendly beacon within **500 m** of your aircraft —
it stops the transmissions and deletes the beacon. Fly near the one you want gone before
calling it. If nothing friendly is within range you get *"No Radio Beacons within 500m."*

**Activation:** F10 → CTLD → Radio Beacons → Remove Closest Beacon

## Listing beacons

**Utility:** Shows every active beacon for your coalition, with its name and frequencies, so
you can read back a channel without hunting for the original drop message.

**Activation:** F10 → CTLD → Radio Beacons → List Beacons

## The frequencies

Each beacon broadcasts on three channels simultaneously:

| Channel | Band | Notes |
| --- | --- | --- |
| VHF | low frequency, shown in **kHz** | The ADF (NDB) channel — swing your automatic direction-finding needle onto it to home in. |
| UHF | shown in **MHz** | Silent carrier (no audio tone), intended for FC3-style aircraft. |
| FM | shown in **MHz** | Audible tone; supports FM homing on aircraft that have it. |

The frequency string always reads `VHF kHz - UHF / FM MHz` (e.g. `245.00 kHz - 350.50 /
45.20 MHz`). Frequencies are assigned automatically — you cannot pick them from the cockpit.

!!! note "Audio requires embedded sound files"
    The beacon tones only play if the mission has the beacon sound files embedded. If you
    hear silence on the VHF and FM channels, that is a mission setup matter, not a fault on
    your end — see the [Mission Maker guide](../mission-maker/index.md). The ADF needle can
    still react to the beacon even when no tone is heard.

## Battery life

A dropped beacon lasts for its battery life — **30 minutes** by default. When the battery
runs out (or the beacon's units are destroyed), CTLD automatically stops the transmissions
and removes it; its frequencies are freed for reuse. The mission maker can change the battery
duration — see the [Mission Maker guide](../mission-maker/index.md).

## The beacon map layer

When the mission has the beacon map layer enabled, active beacons are drawn on the **F10 map**
as coloured circle icons, each labelled with the beacon name and its MGRS coordinates. The
layer keeps itself current: new drops are added, and icons for expired or removed beacons are
erased automatically. Whether the layer is on, and its colours and refresh rate, are set by
the mission — see the [Mission Maker guide](../mission-maker/index.md).

For revealing and marking *detected units* (rather than your own beacons) on the F10 map, see
[Recon](recon.md).
