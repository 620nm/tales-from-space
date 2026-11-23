# Staff tools

BWOINK has two workspaces: **Live station** and **Cases**. Account profiles
open from shared identity cards showing an avatar, username and server role.
Character name, Mind, body, job and antagonist state remain distinct.

Live station is the current game world with an independent staff camera.
The inspector offers input Freeze, full Restore and temporary Drive before
separate Kill, Delete and Gib actions. Property editors show supported writable
state and distinguish derived readouts. Spawn preparation, Move and Duplicate
use authoritative live operations rather than local editor undo.

Create case and Attach to case are available from any typed inspected subject.
Creation anchors the exact subject's recorded history and discovers handlers
as context. Participants' unrelated histories enter evidence only when their
account or Mind is explicitly attached. Cases show unified history, notes,
warnings and account-specific outcomes. Outcomes are records; no penalty
enforcement or round-service counting is implied.

Staff contact uses the original `sound/effects/adminhelp.ogg` from the reference
checkout through the `bwoink` sound key. Incoming message delivery triggers the
sound once; opening history and repainting do not. Its source SHA-256 is
`f83e661f5dddfb5e2035ffa27c54d0110c1aab9a25dc9ba23e2c0bd859350e33`.

Open conversations refresh after committed player replies and delivery
receipts. The newest 16 messages appear first, with older history available
through pagination. Refresh messages rereads history without resending text.

Every round keeps one durable log of every row the engine announces:
`content/ledger.luau` declares the `audit` stream (`scope = "round"`, the
`all` group), so each round's segment is the whole audit and replay record
of that round, genesis included. Nothing else is declared durable. The
engine's `docs/ledger/streams.md` owns the roster, segment and retention
contracts.

The engine's `docs/STAFF.md` owns authority, control and audit contracts.
This pack owns workspace composition, labels and content-specific behavior.
Director and punishment enforcement have no interface here.

Inspect staff fixture captures at 1024×768, 1366×768 and 1600×1000 using the
engine's UI lab. A connected station capture checks that the canvas remains
readable and staff operations affect real entities. See [UI workflow](UI.md).

## Observing

Staff whose account holds `engine.staff.control` get an observe panel
in both modes (`content/lib/observe.luau`). Leaving spawns an `observer`
body (`content/bodies/observer.luau`: the ghost picture, unseen by the
crew, through every wall) on their tile and moves their own Mind into it;
returning moves it back and removes the observer. Name, job, memory and
vars stay with the Mind throughout (the engine's `docs/control/seat.md`).
The body left behind stands where it was.

- A disconnect changes nothing: a staff member who reconnects while
  observing is still the observer and is offered the way back.
- A left body that is gone, dead or ridden by someone else cannot be
  returned to: the observer stays and the panel says so.
- Only a live, animate body can be left: a corpse, or the engine's
  reconnect viewpoint over one, spawns nothing.
- The way back needs no grant. A revoked grant takes effect within two
  seconds, the modes' sweep period: any press of the panel, any reconnect
  while observing, or the sweep sends the observer home, and the panel
  closes there. With no living body to go home to, the sweep stops the
  observer instead (a dead body, the panel closed): the player is then
  any dead player of the mode, under its respawn policy, and the sweep
  removes the stopped observer once nobody rides it.
- A grant made mid-round shows the panel at the next connect.
- Specs: `tests/rounds/observe_free_build_test.luau`,
  `tests/rounds/observe_station_test.luau`,
  `tests/rounds/observe_refusals_test.luau`.
