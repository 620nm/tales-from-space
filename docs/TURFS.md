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
cover states. Bare space, ground, and station base have no cover controls.

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

## Gravity and handholds

Station base and walls receive the station gravity field. Uncovered space,
lattice, and catwalk do not. Terrestrial environments have gravity everywhere,
including authored vacuum tiles; an explicit microgravity space environment
disables gravity throughout. The station field is assumed enabled until
generator control is implemented.

In zero gravity, a body can brace against a wall, lattice, catwalk, or blocking
object on its tile or any of its eight neighbours. A bare floor supplies no
handhold. Pushing off a movable blocking object sends that object oppositely.
Structural support, handholds, gravity reception, and atmosphere sealing are
independent composition properties.

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
vendor and both stand on the atmospherics bench of `maps/chillstation.ron`.

## Residue

A blast leaves three things that are not decals: shards where pellets
landed and cloudy fallout over the blast area, both engine residue as
counts on tiles (the engine's `docs/physics/residue.md`), and ash, which
is ordinary solid matter. `content/residue_appearances.luau` dresses the
two kinds `content/lib/residue_kinds.luau` declares, drawn on the
`residue` layer between paint and spills. Residue is never pickable and
never covered by the eraser; every mop stroke sweeps its tile's every
kind as the stroke's silent half, whether or not the head lifts anything.
