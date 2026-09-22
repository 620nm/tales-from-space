# Programmable exterior airlocks

`tests/maps/programmable_airlock.ron` assembles ordinary networked doors, two wall
buttons, a bidirectional vent and an access point. The interior opens west and
space is east. Initially the interior is closed and bolted, the exterior is
open and unbolted, and the chamber is empty.

The map opens commissioned. Its `links` table joins both doors, both buttons
and the vent to the access point. The access point's
`"file.airlock_controller": true` row puts an editable copy of that reference,
`airlock.disl`, on its store, and `"program.controller": "airlock_controller"`
binds that copy to `controller` at boot (the engine's
`docs/map-properties/stores.md`). The first press cycles the room.

The shared guest interface is in [controllers.md](controllers.md); preset
source authoring is in [reference-files.md](reference-files.md).

## Rebuilding and reprogramming

A host commands its direct, joined, reachable members. Access points and air
alarms offer an internal file store and a `controller` program slot. To rebuild the
network, hold an open, powered laptop and click the access point. Its lock
boots shut, so the laptop first shows the lock screen; Unlock, then release
members and rejoin them from the candidate list in the same workspace. A
button joined to nothing says nobody answered. A host with an empty
`controller` program slot has no fallback program and says no program is loaded.

The atmos stock disk (`floppy_disk.atmos_stock`) contains fixed originals of
`airlock.disl` and `readme.md`, loaded by reference ID from
`reference/manifest.ron`. To reinstall, use
[laptop contact programming](../LAPTOP.md#contact-programming): insert the
orange disk into the laptop and copy `airlock.disl` from B: to the laptop's
A: on its desktop, then hold the laptop and click the host. An unpowered host
refuses the contact and says so. The host already holds the map's
`airlock.disl`; a copy cannot take a name A already holds, and a bound file
cannot be deleted. Unload `controller`, delete the old copy, copy the program
from the laptop's A: to the host's A: (its internal store), then load
the new copy into `controller`. Edit that copy in the same workspace.

The demonstration also supplies a `disk_box` with eight blank floppy disks.
Its ordinary storage holds the disks loose, without tgstation's individual
wrappers. The atmos stock disk uses the orange `datadisk12` shell
from tgstation's floppy sheet, preserving its gray metal shutter.

The RPD and pipe dispenser supply `bidirectional_vent_fitting`; wrench it onto
plating or floor. Its supply is port 0 on layer 4 and its waste
is port 1 on layer 2. Both mouths face the declared direction and these layers
are fixed (tg `unary_devices/airlock_pump.dm:114-120`). Wire the vent and doors
to a powered room circuit and plug the hub into a live outlet.

The tool vendor supplies `airlock_button_fitting`; hold the fitting and
click an adjacent wall. It also supplies `air_sensor_fitting`, the wall
mount for the standalone air-sensor endpoint: a `sensor`-class instrument
that reads its own tile, reports the band onto its network, and joins an
access point's open roster. An air alarm refuses it; its roster is plumbing
and buttons. Build the hub through the existing wall-frame,
board and network-card assembly path.

## Default cycle

`reference/scripts/airlock.luau` owns sequencing and permission policy.
It learns home by tasting air, never by place. Each door reports
directional samples from its own tile, and a side counts as station air
when some kept sample reads hazard `none` at or above 85 kPa, breath at or
above 16 kPa, and 253.15–323.15 K. The host knocks once at boot, map- and
player-built alike, and the program latches what it found; a commissioned
host meets an empty room, so the first press probes again.
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
The sensor is the vent's own tile, and the vent works the whole chamber
evenly: `spread = "adjacent"` fills and siphons its tile and every tile open
air joins to it (tg `unary_devices/airlock_pump.dm:207-254` over `check_turfs`,
`:472-476`). It meters 800 L/s of each 1000 L tile, the fraction tg's
`volume_rate` 2000 (`:55`) takes of its 2500 L turf, so every chamber tile
stays level with the sensor and both thresholds hold for all four tiles.

One station side names the vent cycle's home leaf. Both station sides run
interlock-only: the far leaf closes and bolts, the near leaf opens, and no
pressure watch ever fires. Neither side breathing seals both leaves: unbolt
and close each, raise door emergency mode, halt the fan, sound the failsafe
line, and latch until an engineer presses a joined button. Every press
re-reads the air, and a wrong roster, a stranger's completion, a dead
sample or a silent watch faults instead of guessing.
If the closing leaf is moving, a new request waits for its actual rest
before restarting. Old completions cannot advance later phases. Pressure
watches and the host deadline bound stalled cycles. A disconnected or
unpowered device cannot authorize progression. A fault can leave a door
where it stopped; the source reports the fault instead of assuming success.

The default `permitted(request)` accepts everyone. Returning
`request.engineering` restricts each press to engineering access. A denial
leaves the previous accepted request alone.

`tests/devices/programmable_airlock_ready_test.luau` cycles the bench exactly
as its fixture authors it. `tests/devices/programmable_airlock_test.luau` releases, rejoins
and reinstalls it through player commands, edits its program through laptop
contact, and checks real pressure and door completions. The companion
construction spec assembles and removes its fittings.
`tests/devices/airlock_autodetect_vacuum_test.luau` and
`airlock_autodetect_terrestrial_test.luau` prove the layout learns home from
the air on each side, `airlock_autodetect_both_air_test.luau` proves both
sides breathing runs interlock-only, `airlock_autodetect_neither_test.luau`
proves neither side seals until an engineer resets it, and
`airlock_autodetect_faults_test.luau` proves a short roster refuses aloud
and cycles again after rejoining.

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
- `code/modules/atmospherics/machinery/components/unary_devices/airlock_pump.dm:199-254`
  processes a cycle: it fills and siphons its own turf and every atmos-adjacent
  one (`check_turfs`, lines 472–476) at `volume_rate` 2000 (line 55) of a 2500 L
  turf (`code/__DEFINES/atmospherics/atmos_core.dm:152`).
- `code/game/machinery/airlock_control.dm:17` implements secure opening and
  closing by changing bolts around door operations.
- `code/game/machinery/embedded_controller/airlock_controller.dm:37`
  binds specific doors, pump and sensor; its state machine at line 89
  owns the fixed cycle and pressure decisions.

TfS keeps the cycle in editable guest source. Pipe layers 2/4 and completion
thresholds of at least 100 kPa and below 10 kPa on every chamber tile are this
fixture's contract.
