# 01 — Log the real code and the spot, then find why the LSS saw nothing

Status: 🟡 waiting-human — logging done 2026-11-04; the measurement below needs DCS (Zip)

- Add at `INFO`: the JTAC's laser code and radio when it registers (`_resolveLaserCode`, `spawnJTAC`), and the code, the target and the range from the drone at each `startLase`, plus whether `Spot.createLaser` returned a spot.
- Then **measure** the reported case: Sinai OT, Medium zone of Gizeh, A-10C_2, TGP LSS on 1511 at 15 nm, nothing found in a minute while Reaper 1 lased a target.
  Hypotheses to test one at a time, each outcome written down with what it concludes:
  a. the code actually lased is not 1511 (the new log line settles it);
  b. the spot is on but the LSS range is shorter than 15 nm in this configuration (repeat at 5 and 10 nm, with a mate lasing at a fixed distance);
  c. the spot is created but not visible to the player because of the drone's line of sight to the target (`checkLOS`) or its altitude;
  d. a second JTAC holds 1511 (`FIX-JTAC-IMPOSED-CODE-AND-RADIO` should have closed this; check the vendored version carries it).
- The outcome is a fix, or a measured range / behaviour handed to VMCT for `known-limitations.yaml` (`kind: dcs`, dated) and the mission briefing.

## Logging — done

`CTLDJTACManager:_logRegistered` and `_logLaseStart`, tested in `tests/ci/functional/jtac_manager_spec.lua`.
The lines, as they read in `dcs.log` (see [the developer page](../../../docs/developer/subsystems/troops-jtac.md#what-the-log-says-about-a-jtac)):

```
[JTAC] register: 'Reaper 1', code 1511 (imposed), radio 36.0 FM
[JTAC] lase: 'Reaper 1', code 1511 on 'BMP-2 #1' (BMP-2), range 5000 m, JTAC at 3000 m, spot created
```

Hypothesis a is settled by the `lase` line's code, c in part by its range and altitude, and d by a second `register` line on the same code.
