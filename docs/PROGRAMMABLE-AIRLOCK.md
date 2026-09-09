# Programmable exterior airlocks

`maps/programmable_airlock.ron` is a working bench assembled from ordinary
networked airlocks, two wall buttons, a dual-port vent and an access point.
The interior opens on the west; space is east. The initial interior leaf is
closed and bolted, the exterior leaf open and unbolted, and the chamber empty.

## Installation and assembly

Join both doors, both buttons and the vent through one access point or air
alarm. These existing hubs offer an internal file store and the `controller`
socket. A host commands only its direct joined members that currently answer
on its network. Devices on another host cannot receive its commands.

The `airlock_program_disk` carries the fixed original `airlock.disl`. Seat it
in a laptop, open and power the laptop, hold it and click the host. Select the
laptop's removable medium in the contact workspace, copy the source onto the
host store, and load that host copy into `controller`. Edit the copy through
the same contact workspace. The disk does not execute and the host does not
run an uninstalled fallback program.

The RPD and pipe dispenser supply `dual_port_vent_fitting`; wrench it onto
plating or floor. Its intake is the back port on layer 2 and its effluent is
the front port on layer 4. The layers are fixed. Wire the vent and doors to a
powered room circuit, and plug the hub into a live outlet. The tool vendor
supplies `airlock_button_fitting`; hold the fitting and click an adjacent wall. The hub itself uses
the existing wall-frame, board and network-card assembly path.

## Guest contract

`content/lib/controller.luau` is a bounded network/socket bridge.
`content/lib/airlock_program.luau` contains the distributable guest source and
all airlock sequencing and permission policy. `content/lib/device_queue.luau`
paces real network messages with one task and at most four queued packets per
sender. Button and completion packets batch up to sixteen events; presses retain guest permission review. Its sleeps are transmission deadlines, not per-tick polling.

The guest receives `event`, `devices` and its persistent `mem` capsule.
`devices` contains only live, reachable direct members: address, kind,
coordinates and native door or vent readouts. An address is an identifier;
the host never resolves an arbitrary address into a world capability.

Events are button requests, door completions, pressure completions and a
bounded timeout. A button supplies `engineering`, a verified access check on
the clicking actor. The default `permitted(request)` accepts everyone; an
engineering policy returns `request.engineering`. Every press consults it,
including repeats. A denial leaves the previous accepted request alone.

The guest returns `{ commands, status?, timer?, replace?, accepted? }`. A command names `mac`, a
bounded correlation `id`, and one operation:

| Operation | Fields |
|---|---|
| `open`, `close` | no extra fields |
| `bolt` | `bolted` boolean |
| `vent` | `on`; while on, `direction = "fill" | "drain"`, `target` kPa |
| `watch` | `target` kPa, `comparison = "at_least" | "below"`, `ticks` |

`replace = true` discards unsent plans from an earlier request. `accepted = true`
advances the host's per-button duplicate watermark. Button presses carry an authoritative
sequence and batches preserve up to sixteen pending requests for permission
checks; excess presses receive a busy refusal. Every unique admitted press advances the shared sequence, even when another
button's newer packet arrives first; duplicate presses from the same sender do
not advance it twice. Timers use cancellable native task identities so
an edited guest may replace a deadline with an earlier one without polling.
Plans contain at most six commands. Host fault-stop envelopes can address all
64 direct children; each receiving device still validates at most six commands. The bridge validates every command before
queuing the plan; each device independently validates its addressed commands
and requires the emitter to be its current parent. Completions travel back as
real network messages. A malformed or faulted guest stops reachable vents and
reports a fault. The bridge imposes no airlock sequencing interlock: editing
the installed guest changes the policy while native power and bolt mechanics
remain authoritative.

## Default cycle

The source identifies the two doors by west-to-east position, and its vent by
kind. Both buttons advance the same sequence: the first accepted press requests
entry, the next exit, then entry again. Every accepted press advances it, even
while a cycle is active and even when the same button is pressed twice. The
latest accepted request replaces unsent earlier commands and receives a new
correlation generation.

Entry unbolts and closes the exterior in one command packet, waits for the actual motor completion,
bolts it, fills through the intake to at least 100 kPa, then stops the vent,
unbolts and opens the interior, waits, and bolts it open. Exit performs the
reverse sequence, draining through the effluent main below 10 kPa before
opening space. An open bolted door remains open against autoclose.

A request meeting a moving leaf waits for its actual rest before restarting
under the new generation. Old completions cannot advance later phases.
Pressure watches and the host deadline bound a stalled cycle; a disconnected
or unpowered device cannot authorize progression. Timeout, network loss or
power loss can leave a door where it stopped, and the source reports a fault
instead of guessing that an operation completed.

`tests/programmable_airlock_test.luau` operates the shipped bench through
player commands, installs and edits its source through laptop contact, and
checks both cycles against actual room pressure and door state.

## Reference

The tgstation checkout supplies the device art and reference mechanics:

- `code/modules/atmospherics/machinery/components/binary_devices/dp_vent_pump.dm:9`
  assigns separate intake and output ports; lines 29–38 select vent art and
  lines 48–100 transfer between each main and the room.
- `code/game/machinery/airlock_control.dm:17` implements secure opening and
  closing by changing bolts around door operations.
- `code/game/machinery/embedded_controller/airlock_controller.dm:37`
  binds its specific doors, pump and sensor; its state machine at line 89
  owns the fixed cycle and pressure decisions.

TfS keeps that cycle in the editable disk source. The fixed pipe layers 2/4
and completion thresholds of at least 100 kPa and below 10 kPa are this
fixture's contract, rather than tg's controller thresholds.
