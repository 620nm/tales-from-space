# Programmable exterior airlocks

`maps/programmable_airlock.ron` assembles ordinary networked doors, two wall
buttons, a airlock pump and an access point. The interior opens west and
space is east. Initially the interior is closed and bolted, the exterior is
open and unbolted, and the chamber is empty.

The shared guest interface is in [controllers.md](controllers.md); preset
source authoring is in [reference-files.md](reference-files.md).

## Installation and assembly

Join both doors, both buttons and the vent through one powered access point
or air alarm. These hubs offer an internal file store and a `controller`
socket. A host commands its direct, joined, reachable members.

The atmos stock disk (`floppy_disk.atmos_stock`) contains fixed originals of `airlock.disl` and
`readme.md`, loaded by reference ID from `reference/manifest.ron`. Use
[laptop contact programming](../LAPTOP.md#contact-programming): insert the
orange disk into the host, hold an open, powered laptop and click the host.
Copy the program from B (the host's inserted disk) to A (the host's internal
store), then load the A copy into `controller`. Edit that copy in the same
workspace. The laptop's own disk is absent from this contact workspace. An
uninstalled host has no fallback program.

The demonstration also supplies a `disk_box` with eight blank floppy disks.
Its ordinary storage holds the disks loose, without tgstation's individual
wrappers. The atmos stock disk uses the orange `datadisk12` shell
from tgstation's floppy sheet, preserving its gray metal shutter.

The RPD and pipe dispenser supply `airlock_pump_fitting`; wrench it onto
plating or floor. Its supply is port 0 on layer 4 and its waste
is port 1 on layer 2. Both mouths face the declared direction and these layers
are fixed (tg `unary_devices/airlock_pump.dm:114-120`). Wire the vent and doors
to a powered room circuit and plug the hub into a live outlet.

The tool vendor supplies `airlock_button_fitting`; hold the fitting and
click an adjacent wall. Build the hub through the existing wall-frame,
board and network-card assembly path.

## Default cycle

`reference/scripts/airlock.luau` owns sequencing and permission policy.
It identifies the doors by west-to-east position and the vent by kind.
Both buttons advance the same sequence: the first accepted press requests
entry, the next exit, then entry again. Each accepted press advances it,
including during a cycle and when the same button is pressed repeatedly.
The latest accepted request replaces unsent commands and gets a new
correlation generation.

Entry unbolts and closes the exterior in one command packet, waits for the
actual motor completion, bolts it, fills through the intake to at least
100 kPa, then stops the vent, unbolts and opens the interior, waits, and
bolts it open. Exit reverses this sequence, draining through the effluent
main below 10 kPa before opening space. A bolted-open door resists autoclose.
Pressure thresholds use the vent's native sensor after atmosphere transport.

If the closing leaf is moving, a new request waits for its actual rest
before restarting. Old completions cannot advance later phases. Pressure
watches and the host deadline bound stalled cycles. A disconnected or
unpowered device cannot authorize progression. A fault can leave a door
where it stopped; the source reports the fault instead of assuming success.

The default `permitted(request)` accepts everyone. Returning
`request.engineering` restricts each press to engineering access. A denial
leaves the previous accepted request alone.

`tests/programmable_airlock_test.luau` operates the shipped bench through
player commands, copies and edits its reference files through laptop
contact, and checks real pressure and door completions. The companion
construction spec assembles and removes its fittings.

## tgstation reference

Paths are relative to the read-only tgstation checkout:

- `code/game/objects/items/storage/boxes/science_boxes.dm:27` declares the
  disk box and eight-disk roster; `_boxes.dm:5` supplies its base sprite and
  `_boxes.dm:38` layers the `disk_kit` illustration.
- `code/game/objects/items/floppy_disk.dm:6` declares precolored disk skins;
  `icons/obj/devices/floppy_disks.dmi` also contains the orange `datadisk12`.
- `code/modules/atmospherics/machinery/components/binary_devices/dp_vent_pump.dm:9`
  assigns intake and output ports; lines 29–38 select vent art and
  lines 48–100 transfer between each main and the room.
- `code/game/machinery/airlock_control.dm:17` implements secure opening and
  closing by changing bolts around door operations.
- `code/game/machinery/embedded_controller/airlock_controller.dm:37`
  binds specific doors, pump and sensor; its state machine at line 89
  owns the fixed cycle and pressure decisions.

TfS keeps the cycle in editable guest source. Pipe layers 2/4 and completion
thresholds of at least 100 kPa and below 10 kPa are this fixture's contract.
