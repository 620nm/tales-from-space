# Levels

What stands on, under and between a map's levels; decks and covers are
`docs/TURFS.md`.

Rock (tg `/turf/closed/mineral`) blocks movement, gas and sight, supports and
seals, and hides what is under it. It sits over the map's substrate (by
default the generated ground on a planet, open in space), which removing it shows. It wears tg's
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
floor by default (`minerals.dm:29`). Laying plating on rock floor is not
ported.

Open sky above ground and what seals it are the engine's contract (the
engine's `docs/content-schema/compositions.md` "Tile values and replacement"
and `docs/mapping/environment.md` "Exposure"). Station base and rock seal the
substrate, so either one roofs open sky. The `open` preset cuts a hole on any
level, ground-level terrain included, but not on the lowest. `bare` and `rock`
write the `inherit` substrate: at or below ground it stands on a ground block
beneath, else it is open; above ground it is open sky.

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

Stairs (tg `stairs.dm`) are one structure, `stairs`, whose `dir` is the way
up: a flight on plating and an undrawn top cell over open space a level up
(the engine's `docs/sim/step-links.md`). Leaving the flight forward climbs to
the tile ahead a level up, unless that landing is open or the space over the
flight closed; stepping back onto the top walks down; stepping onto the flight
from ahead is refused. A one-level fall onto the flight is caught without a
landing line, and tumbles a body out cold or staggered that nobody pulled as it
fell: knocked down, staggered and bruised (`content/lib/fall.luau`). Standing
on the flight shows the landing ahead and puts it in reach (`view_landing`;
`content/lib/level_crossing.luau` allows a reach only from a flight), beyond
tg's arrow. Merged art, chained flights, the roll down and frames are not ported. `tests/maps/stairwell.ron` is a walkable pair.

Seeing down has tg's multi-z look (`levels.view` in `content/capabilities.luau`;
the engine's `docs/architecture/map-instancing/levels.md` "Seeing down"): three
levels below the eye, each 0.9 darker and 0.965 smaller about it, straight down.
Because a lower level draws smaller, an opening also shows a sliver of the tile
beyond it.

Across levels, sound and speech pass an open hole or a glass floor both ways;
text, throws and machine feedback reach only viewers above, and a
hand reaches another level only from a flight (`content/lib/level_crossing.luau`,
bound by both modes).

The level specs live in `tests/levels/`.
