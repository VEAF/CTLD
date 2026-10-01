# 06 — Native crate load and release read from the on-board cargo list

**Status:** ✅ done · **Type:** AFK

## Parent

[PRD — FIX-NATIVE-CARRY-DETECTION](../PRD.md). [ADR 0022](../../../dev/adr/0022-native-carry-detected-from-dcs-on-board-cargo-list.md).
Stories 2, 5, 6, 20, 21, 27.

## What to build

The crate manager's native detection follows the same rules as the vehicle scan, reusing the list
reading from ticket 03. The crate's bounding-box entry test, its ground-speed guard, its local-frame
drift reference and the native link table are **replaced**:

- **Entry.** A tracked crate that appears on a candidate aircraft's list becomes native carry
  (`OnCrateLoaded`, method `dcs_native`, payload unchanged). A crate is matched by its object name;
  untracked entries are ignored with a debug trace.
- **Release.** A crate that leaves the list is released. Transport on the ground: the crate is
  `LANDED`. Transport airborne: the crate goes to its existing falling state and stays there until
  it touches the ground (existing behavior). `OnCrateUnloaded` with method `dcs_native` as today.
- **Transport lost.** A native-carry crate whose transport no longer exists is reset to the ground
  state, as today.
- **Conversion kept.** For types with `convertNativeLoadToCTLD` (UH-1H and CH-47Fbl1 by default),
  the trigger is the crate appearing on the list; the conversion (release the DCS load, then a
  CTLD load after the short delay) is unchanged. A "conversion in progress" mark stops the same
  crate from being handled twice during that delay, since it is still listed until DCS processes
  the release.
- The spawn-time check that keeps a freshly spawned crate out of a neighbouring aircraft's volume is
  unrelated to detection and is left untouched.

## Acceptance criteria

- [ ] A tracked crate appearing on the list becomes native carry; its position is irrelevant.
- [ ] A crate leaving the list is released: `LANDED` on the ground, falling then ground in flight.
- [ ] For a converting type, the crate is converted once, even though it stays listed during the
      delay.
- [ ] An untracked entry changes nothing and leaves a debug trace.
- [ ] The box test, speed guard, drift reference and native link table are gone; luacheck clean.
- [ ] Existing crate specs unrelated to detection stay green; new busted cases cover each rule.
- [ ] `CHANGELOG.md` `[Unreleased]` has a `Changed` entry.

## Blocked by

- [03 — Native vehicle entry](03-native-vehicle-entry-on-board-list.md)
