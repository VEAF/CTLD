# FIX-CANCELPENDING-URGENT-TIMER — cancelPending leaves the urgent timer running

**Status:** 🔄 in-progress (implemented, PR pending)

Closes #152, filed by Zip out of an automated review of the VEAF-Mission-Creation-Tools PR that
vendors rc10. Polish, not a field report — but see *Why it is worth doing now*.

## The deviation

`ctld.MenuManager:cancelPending(groupId)` cancels the **ambient** rebuild properly, because the
ambient path stores its timer id ([CTLD_menu.lua:192](../../src/CTLD_menu.lua#L192)):

```lua
self._pendingAmbient[groupId] = { timerId = timerId }
```

The **urgent** (debounced) path stores only a flag ([:165](../../src/CTLD_menu.lua#L165)):

```lua
self._pendingRefresh[groupId] = true
timer.scheduleFunction(function() ... end, nil, timer.getTime() + DEBOUNCE_S)
```

so `cancelPending` clears the flag and the timer fires anyway.

### What it takes to be visible

The callback re-checks `selfRef.menus[groupId]` before rebuilding, so a group that has left
triggers nothing at all — which covers most of the field. To get an effect, all of this has to
line up: a new occupant takes the **same numeric group id**, **already has a menu**, and does so
inside the **0.15 s** debounce window. The consequence is then one unsolicited wipe-and-rebuild in
that player's first 150 ms — which is precisely the misfire ADR 0015 and #147 exist to prevent.

### Why it is worth doing now

`cancelPending` only started being **reached** with #151. Before it, `onPlayerLeaveUnit` raised on
its third line whenever DCS delivered a released initiator — i.e. on every slot and coalition
change, the exact situation a recycled group id comes from. So this is the second half of a
mechanism whose first half has just begun to run.

### The test that agreed with the bug

`menu_manager_spec.lua`'s *"cancelPending clears a pending urgent debounce"* asserts only that the
flag is cleared, and explains in a comment that `cancelPending` *"cannot retract a call already
handed to timer.scheduleFunction"*. The ambient path in the same function does exactly that, ten
lines below. The comment rationalised the defect rather than recording it; the case is rewritten
here.

## The fix

Store the urgent timer's id the way the ambient one is stored, and remove it in `cancelPending`:

```lua
self._pendingRefresh[groupId] = { timerId = timerId }
```

Every read of `_pendingRefresh` is a truthiness test (`if self._pendingRefresh[groupId] then`), so
moving from `true` to a table changes no call site; no spec asserts `== true` — checked. The value
now carries what it needs, symmetrically with `_pendingAmbient`.

## Definition of done

- `cancelPending` removes the urgent timer through `timer.removeFunction`, as it already does for
  the ambient one.
- A new occupant of a recycled group id gets no unsolicited rebuild from the previous occupant's
  debounce.
- The debounce itself is unchanged: a second refresh inside the window still coalesces, and the
  callback still clears its own entry.
- Specs green, `CTLD.lua` rebuilt and loading under Lua 5.1, `CHANGELOG.md` entry.

## Testing decisions

The seam is `ctld.MenuManager` with `timer.scheduleFunction` / `timer.removeFunction` mocked —
exactly what `menu_manager_spec.lua` already does, recording scheduled ids and removed ids.

- `cancelPending` after an urgent refresh calls `timer.removeFunction` with **that** id (the
  rewritten case).
- The end-to-end shape from #152: urgent refresh pending → `cancelPending` → the callback fires
  anyway (a mocked timer cannot really retract it) → **no** rebuild happens, because the entry is
  gone. This is what the reported symptom needs.
- Negative controls: the debounce still coalesces a second refresh inside the window, and
  `cancelPending` on a group with nothing pending removes nothing.

No live DCS scenario: the trigger is a 0.15 s window on a recycled group id, which cannot be
scheduled on demand, and the observable is timer bookkeeping a spec reads directly.

## Found while implementing

- **The callback had no claim on the group.** Removing the timer covers the reported case, but the
  spec written from #152's own scenario stayed red: if the callback runs anyway it rebuilds, because
  it only checks that a menu exists — and in the reported case the *new* occupant has one. The entry
  now doubles as the callback's claim: it refuses to act when the entry it finds is not its own.
  Three lines, and the guarantee stops depending on `timer.removeFunction` behaving.
- **`cancelPending` could raise on the teardown path.** Reading `.timerId` off whatever sits in
  `_pendingRefresh` raises if it is not a table, and `cancelPending` is called from
  `_forgetPlayer` — a raise there aborts the cleanup and leaves the player registered, which is the
  defect #151 just fixed. The read is now type-checked. Surfaced by a spec from that lot which
  injected a bare `true`; that shortcut is corrected too, since it mirrored the old implementation
  rather than the manager's own shape.

## Out of scope

- The debounce duration and the ambient delay. Untouched.
- `_urgentGroupId` auto-detection. Untouched.
