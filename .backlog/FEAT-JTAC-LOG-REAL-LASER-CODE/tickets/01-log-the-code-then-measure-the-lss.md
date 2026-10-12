# 01 — Log the real code and the spot, then find why the LSS saw nothing

Status: ⬜ ready

- Add at `INFO`: the JTAC's laser code and radio when it registers (`_resolveLaserCode`, `spawnJTAC`), and the code, the target and the range from the drone at each `startLase`, plus whether `Spot.createLaser` returned a spot.
- Then **measure** the reported case: Sinai OT, Medium zone of Gizeh, A-10C_2, TGP LSS on 1511 at 15 nm, nothing found in a minute while Reaper 1 lased a target.
  Hypotheses to test one at a time, each outcome written down with what it concludes:
  a. the code actually lased is not 1511 (the new log line settles it);
  b. the spot is on but the LSS range is shorter than 15 nm in this configuration (repeat at 5 and 10 nm, with a mate lasing at a fixed distance);
  c. the spot is created but not visible to the player because of the drone's line of sight to the target (`checkLOS`) or its altitude;
  d. a second JTAC holds 1511 (`FIX-JTAC-IMPOSED-CODE-AND-RADIO` should have closed this; check the vendored version carries it).
- The outcome is a fix, or a measured range / behaviour handed to VMCT for `known-limitations.yaml` (`kind: dcs`, dated) and the mission briefing.
