# IV drip

The stand transfers matter between its native chemical dock and a connected body. The shared
connection lifecycle and flow loop live in `content/lib/medical/iv_line.luau` and
`content/lib/medical/iv_flow.luau`. Blood typing and transfusion response are documented in
[Blood types](blood-types.md).

## Use and connection

The panel has no Connect action or patient picker: insert or eject a vessel through the native
dock, then drag the stand onto the intended body to connect. The drag supplies that body as the
explicit target to the shared guarded connection.

A connection requires an extant Body, a live docked vessel, and an actor who can reach and see
both stand and patient. The stand and patient must be on the same plane and at most one tile
apart. Attachment waits one second, then repeats the relevant checks, including exact vessel
identity in the dock. `iv_line.connect` returning `true` means the attempt is queued; it does not
mean attachment completed. A replacement leaves the old active line running until the new
attempt commits. An explicit call to `iv_line.disconnect` cancels pending and active work.

## Flow and blood

The panel retains `Disconnect`, switches between `inject` and `draw`, and sets a rate from 0 to 5
units per second in 0.01-unit steps. The default is 5. These bounds, step, and default follow tg
(`code/game/machinery/iv_drip.dm:1-8`). One tg unit is 0.025 mol (`../CHEMISTRY.md` §4). The IV
task wakes every two seconds, matching the machine interval
(`code/controllers/subsystem/machines.dm:7,149`): at 5 units per second, a full stroke moves up
to 10 units (0.25 mol), or 1.25 mol over five strokes in ten seconds. This task runs
independently of the body's `mob.life` cadence. Once started, flow continues while its initiating
actor moves, becomes medically dead, or disconnects, provided both endpoints remain valid.

Injection transfers liquid and solid phases. The IV does not cap injection at `blood_normal`;
when the body's `blood_harmony` life handler runs, it removes blood above normal on that body
pass, independently of the drip task (`content/lib/blood_harmony.luau:53-78,105-120`). Drawing
transfers liquid only, so liquid medicine moves with the drawn mixture. A positive-rate draw at
or below 40% of the body's `blood_normal` sends one low-blood notice for that flow task and does
not draw. The beep check uses the 85% safe fraction and a 5% chance per positive-rate draw
stroke (`code/__DEFINES/mobs.dm:20-24`; `code/game/machinery/iv_drip.dm:262-265`). A full draw
vessel, with at most 1 mL of headspace, sets the rate to zero and sends a full notice. Raise the
rate to resume. The default human normal is 13.75 mol (550 units); the draw floor uses each
body's `blood_normal` value. See [Blood types](blood-types.md) for blood identity and dose
effects.

Ordinary matter completions run synchronously. Their records contain moved amount but no
endpoints. `iv_flow` therefore keeps one issue-order FIFO for the `iv_drip` issuer across
stands. Draws consume a matching blood-identity note too, with no donor or receiver type and
no toxin reaction. Notes survive disconnect and replacement so already-issued transfers stay
paired with their receipts. Injection receipts settle using the actual moved amount; an
incompatible dose requests toxin at half that amount, bounded by native holder capacity. A
receipt for a patient Handle that no longer exists consumes its note with zero moved. A
medically dead body that still has its Handle and Body record passes the existence check; that
is a consequence of the guard, not a separate corpse-flow rule.

## Movement and removal

The flow checks that the line generation, body, stand, vessel, placement, and exact docked vessel
are still current before each stroke. It does not poll distance. A settled
`entity.location.changed` for either endpoint triggers an adjacency check, including at rate
zero, so a pair pulled together remains connected when it settles within range. If the endpoints
separate, the line is retired and one 3-brute damage command is issued; the ordinary bloodshed
handler owns the wound. The IV code does not add a second explicit wound
(`code/game/machinery/iv_drip.dm:228-233`).

If a map-instance change leaves the pair adjacent, the line safely disconnects and asks for
reconnection. A separated pair rips as usual; the line does not continue seamlessly across map
instances. Native Eject has no immediate dock observer: the next two-second flow check notices
the exact vessel mismatch and disconnects, so the line may remain attached until then
(`code/game/machinery/iv_drip.dm:326-341`). The once-per-second handler only cleans up stale
handles and map instances; it does not poll distance or dock state and does not promise general
same-instance install or reload cancellation.

The stand can be removed only with an empty dock. Removal requires a four-second wrench chore
and final reach, line-of-sight, instance, and empty-dock checks. The shared deconstruction
helper awards one metal only after removal completes; the duration and reward are pack choices,
while tg yields one sheet of iron (`code/game/machinery/iv_drip.dm:217-218`). The conditional
mixed-material construction recipe is omitted. Nearby messages use a five-tile radius as a pack
choice.

## Appearance

The stand uses four mode states: `iv_drip_injecting`, `iv_drip_donating`, `iv_drip_injectidle`,
and `iv_drip_donateidle`, following tg's state selection
(`code/game/machinery/iv_drip.dm:135-145`). There is no bag-fill overlay, line beam, or tug image.
