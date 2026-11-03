# Decks and infrastructure

`content/compositions.luau` declares the visual tree, substrate and installed
components, cover controls, network channels, and composition presets.
Maps retain an optional authored substrate and an ordered installed component
list. An omitted substrate inherits the selected environment. Installing or
removing deck components preserves that choice and the independently authored
outdoor flag.

Tiled flooring consists of station base and opaque removable floor tiles.
Grid flooring uses the same base with a transparent protective cover. Each
cover independently controls power and pipe disclosure and tool access. A
closed grid permits seeing and examining the runs beneath it, but prevents
tooling or installing them. Removing either cover leaves the base and opens
access. Reinforcement has the same physical properties in its closed and open
cover states. Bare space, ground, rock floor, and station base have no cover
controls.

The tiled and reinforced floor presets each ship an `, Exposed` variant that
is the same preset with the power and pipe controls opened; the palette folds
each under its base. An exposed tiled floor shows the pried-up subfloor art,
while exposed reinforcement keeps its own sprite with the runs over it.
Either open network control moves the whole cover artwork below infrastructure;
each network retains its independent disclosure and access policy. Grid covers
keep their original draw layer in every control state.

Removing bare base with a welder exposes the retained substrate. The action
uses the existing four-second, two-fuel welding step and returns no material.
An unsupported final network placement rejects the operation. Installing a
new supported component never exposes an intermediate unsupported state.

Lattice and catwalk supply support without sealing the substrate or changing
outdoors. Catwalk support is integrated. A power cable requires supporting
ground, station base, or catwalk; lattice alone does not permit it. Explicit
catwalk removal declares removal of power cables that lose support. Pipes
have no corresponding support requirement and remain installed. Both smooth
with each other and flow into adjacent floor and base tiles, joining them by
component though those tiles smooth nothing back.

The power network declares three channels and the pipe network five. Their
channel identities, preferences, kind connectivity, paints, and shape artwork
are content data. Heat-exchanging pipe fits channels two through four and
joins its own kind. Pipe paints preserve the existing same-colour and omni
connectivity rules. Maps and exports store authored network identities.

Thermal profiles retain the existing capacities, conductivities, and
emissivities. The last installed component declaring a profile supplies it;
otherwise the substrate does. Substrate vacuum boundaries are independent of
support, horizontal gas blocking, and outdoor forcing. Station base seals the
boundary; an exposed space substrate remains a boundary below a catwalk.

## Levels

Rock (tg `/turf/closed/mineral`) blocks movement, gas and sight, supports and
seals, and hides what is under it. It sits over the map's substrate (inherited
by default: ground on a planet, space in orbit), which removing it shows. It wears tg's
`smoothrocks` bitmask art (`minerals.dm:6-21`) and smooths with neighbouring
rock; each `rock-<junction>` frame is the 40x40 cell's centre 32x32 window, so
tg's 4 px overhang is lost, and the map edge is not a neighbour (no
`SMOOTH_BORDER`). Mining it is not implemented.

Rock floor (tg `/turf/open/misc/asteroid`, `asteroid.dm:5-14`) is a natural
substrate beside ground: it supports, receives the station field and is no
vacuum boundary, so a carved room in orbit holds a body with no station base.
Its picture is the asteroid sand state; tg's random floor variance is not drawn.
The `rock_floor` preset paints it and replaces the installed components; an
authored asteroid lays rock over it, because tg's mineral turf leaves asteroid
floor by default (`minerals.dm:29`). The editor's terrestrial subterrain fill
keeps the profile's cold ground, as the icemoon mineral leaves snow
(`minerals.dm:677`); its space subterrain fill is blank and inherits space
(`content/editor.luau`). Laying plating on rock floor is not ported.

Open sky above ground and what seals it are the engine's contract (the
engine's `docs/content-schema/compositions.md` "Tile values and replacement"
and `docs/mapping/environment.md` "Exposure"). Station base and rock seal the
substrate, so either one roofs open sky. The `open` preset cuts a hole on any
level, ground-level terrain included, but not on the lowest. `bare` and `rock`
write the `inherit` substrate, so painting either over a hole at or below ground
closes it; above ground it is open sky, so a hole there stays open.

The four glass floors (tg `glass.dm`) are floor windows over an open substrate.
They hold a body and the air, show the level below, and show runs beneath
without tool access. All four smooth as one group. Their presets open the
substrate, so they cannot go on the lowest level of a closed environment; the four
space environments declare `beyond = { below = "empty", above = "closed" }`, where
an Open tile on the lowest level is legal and vents, and an Open tile on the top
level holds its air: the roof over a map is always closed, and gas leaves
downward. With a level above, that level's floor decides, and an open floor there
shares its air with the tile below it. A power cable needs
supporting ground, station base or catwalk, so none runs on glass, and the
glass preset is refused over a cable run (tg refuses cable where the underfloor
is only visible, `cable.dm:692`); pipes have no such need. A crowbar pries a glass
floor up at once for its one glass tile and leaves plating, as tg does
(`floor.dm:144-174`, `glass.dm:16,74,92,108`). Laying a glass tile, crafting one
from sheets and the starlight glow are not implemented.

Stairs (tg `stairs.dm`) are a climb passage: a flight on plating, one per way
up and drawn that way, under the top of the stairs on the level above, an
undrawn, unsealed component over an open substrate that holds a body. Stepping
onto the flight climbs to the top over it and stepping onto the top climbs back
down, at a human step's pace; a flight with no top over it refuses the step
(the engine's `docs/sim/level-movement.md`). tg's climb onto the tile ahead,
merged art, tumbling and stairs frames are not ported.
`tests/maps/stairwell.ron` is a walkable pair.

Seeing down has tg's multi-z look (`levels.view` in `content/capabilities.luau`;
the engine's `docs/architecture/map-instancing/levels.md` "Seeing down"): three
levels below the eye, each 0.9 darker and 0.965 smaller about it, straight down.
Because a lower level draws smaller, an opening also shows a sliver of the tile
beyond it.

Across levels, sound and speech pass an open hole or a glass floor both ways;
text, throws and machine feedback reach only viewers above, and a
hand never reaches another level (`content/lib/level_crossing.luau`, bound by
both modes).

The level specs live in `tests/levels/`.

## Gravity and handholds

Station base and walls receive the station gravity field. Uncovered space,
lattice, and catwalk do not. Terrestrial environments have gravity everywhere,
including authored vacuum tiles; an explicit microgravity space environment
disables gravity throughout. The station field is assumed enabled until
generator control is implemented. A bare Open tile has no weight of its own: it
borrows the deck below it, so a body over a hole in a room with weight falls, and
a gravity battery's field runs up and down through such holes to the decks they
join (the engine's `docs/netcode/gravity.md`).

In zero gravity, a conscious body can brace against a wall, lattice, catwalk, or
anchored blocking object on its tile or any of its eight neighbours, on its own
level (`content/lib/brace.luau`, the mode's `move.brace`). It cannot push off an
anchored object it is stepping into. A bare floor supplies no handhold, and a
corpse, crit or sleeper grips nothing. Pushing off a movable blocking object
sends that object oppositely.
Structural support, handholds, gravity reception, and atmosphere sealing are
independent composition properties.

## Ground

A tile's ground material is a blend it names (`material = Named("sand_ground")`)
or its environment names (`material` in `content/environments/`). Blends
`silica_ground`, `basalt_ground`, `sand_ground` and `soil_ground` are each one
solid at its real bulk density. `content/terrain.luau` gives them one profile,
`bare_ground`, whose `ground_shell` look
(`content/matter_appearances.luau`) draws on the `ground_face` layer: over the
substrate, under cover, decals, residue and matter. A plated tile draws none.
`warm_outdoors` and `mars_surface` are the skies for soil and basalt; their
`sink_k` equals `surface_temperature_k`, so dry ground sleeps. No mode rolls
them yet. Spec: `tests/matter_look/ground_face_test.luau`.

A cliff (tg `/turf/open/cliff`) is ground laid by the `cliff` terrain profile:
its bed is the `cliff` substrate and its face the `cliff_shell` look, the
stepped escarpment, joined to cliff of the same tint. Blends `basalt_cliff` and
`silica_cliff` take it, coloured by their rock, so the terrain brush paints a
cliff in one stroke. It is a solid barrier: dense as tg's (`cliff.dm:5`), so no
body steps onto it, and there is no fall from its top edge; real height is
levels. As tg's is an open turf, air, sight and shots pass it. Thrown items
stop at it, unlike tg's (`cliff.dm:79`): the engine sweeps a throw against
`movement_blocking`, and no primitive lets one mover pass. Climbing and mining
it are not implemented.

A boulder, `outcrop` (tg `/obj/structure/flora/rock`, `flora.dm:1027-1041`), is
a dense, bolted structure that sight passes; `outcrop.cluster` is its
fieldstone-cluster art. The art is greyscale under a `color` that defaults to
basalt's and a map may override. Both sit in the editor's Natural section.
Mining one is not implemented. Spec: `tests/terrain/cliff_test.luau`.

Plants are cell matter over the ground, never ground: a mapper paints the
`meadow` or `moss_carpet` blend, breathable air plus a litre-thin coat of
`grass` or `moss` (`content/substances/plants/`), drawn by the `grass` and
`moss` looks. A flame latches a plant tile like any fuel
(`content/lib/ignition.luau`); `grass_fire` and `moss_fire` burn the coat to
CO2, steam and ash, and the fire spreads tile to tile until the ground is
bare. Spec: `tests/terrain/meadow_fire_test.luau`.

## Decals

`content/compositions.luau` declares eleven floor decals on a `decal` visual
layer between the deck and everything lying on it. A trim decal names no shape:
it names one sprite per seam piece, and the seam is derived from which
neighbouring tiles hold the same decal in the same colour. A mark decal names
one sprite per facing, or one sprite and no facing at all. Decals paint onto
station base, floor tiles and reinforcement; gratings and walls are not decks.

`content/lib/decal_paints.luau` owns the twelve paints and their order. Trim and
tiling are greyscale art tinted at runtime and drawn at opacity 110; hazard
stripes and painted marks carry their own colours and take no paint. The map and
the editor may name a raw `#RRGGBB`; an in-game tool may not.

A decal belongs to the deck component under it and goes with it: prying the
floor takes the paint. Decals are cosmetic and never cleanable — space cleaner
and the mop are for spills, and paint that is supposed to be there is not a
spill.

`content/items/tools/decal_painter.luau` is how a crewman lays one down: three
dials (decal, paint, facing), free and unlimited, palette only. Its counterpart
`decal_eraser.luau` takes one back off, newest first, and is the only thing that
removes a decal from a deck that still exists. Both are stocked by the tool
vendor (`tests/vendor/tool_vendor_test.luau`); `tests/decals/` covers their use.

## Residue

A blast leaves three things that are not decals: shards where pellets
landed and cloudy fallout over the blast area, both engine residue as
counts on tiles (the engine's `docs/physics/residue.md`), and ash, which
is ordinary solid matter a mop scrapes into its head
(`docs/janitorial/mop.md`). `content/residue_appearances.luau` dresses the
two kinds `content/lib/residue_kinds.luau` declares, drawn on the
`residue` layer between paint and spills as one composite — a part
per resting kind, messier as each cakes. Residue is never pickable and
never covered by the eraser; every mop stroke sweeps its tile's every
kind as the stroke's silent half, whether or not the head lifts anything.
