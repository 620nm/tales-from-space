# Ground

The generated ground a map's tiles stand on, and what lies on it; decks and
covers are `docs/TURFS.md`.

A tile's ground material is a blend it names on its own substrate
(`substrate: Named("ground"), material: Named("sand_ground")`) or the block
under it; a blank tile names none, its column's ground hint does (the
engine's docs/mapping/format.md §Ground). A ground environment's `ground`
(`content/environments/`) generates blocks under the map, `surface` atop each
column over `deep` `basalt_ground`: `sheet_ice` for `cold_outdoors`,
`soil_ground` for `warm_outdoors`, `basalt_ground` for the rest.

Roles: a hint names a role, never a world's rock. The engine's `surface` and
`deep` and the pack's `rock` (`content/rosters/ground_roles.luau`, bedrock
for a ridge or outcrop column) are filled by every ground environment:
`rock` is `silica_ground` in `warm_outdoors`, `basalt_ground` elsewhere. A
map naming a role an environment leaves unfilled is refused there. The
editor draws a `rock` column with `terrain_silicate_rough_flat_1`
(`content/editor.luau` `ground_roles`). A blank tile over a block stands
on its blend's terrain `floor` and shows its face; with no ground (space) a
blank tile is open onto the beyond. Blends `silica_ground`, `basalt_ground`,
`sand_ground` and `soil_ground` are each one solid at its real bulk density.
`content/terrain.luau` gives them one profile, `bare_ground`, whose
`ground_shell` look (`content/matter_appearances.luau`) draws on the
`ground_face` layer: over the substrate, under cover, decals, residue and
matter. A plated tile draws none. `sheet_ice` has its own profile: it
stands on the `ice_floor` floor and its face is the `ice_shell` look, the
smooth ice sheet, whose translucent skirt shows that floor 0.7 darker at a
shell's edge. A profile without `face_tint` takes its material's colour, so
ice, basalt and soil read apart; only a sea's bed is tinted sand.
`warm_outdoors` and `mars_surface` have `sink_k` equal to
`surface_temperature_k`, so dry ground sleeps; no mode rolls `mars_surface`
yet. Specs: `tests/matter_look/ground_face_test.luau`,
`tests/matter_look/environment_ground_test.luau`,
`tests/terrain/ice_sheet_test.luau`.

A cliff (tg `/turf/open/cliff`) is ground laid by the `cliff` terrain profile:
its `floor` is the `cliff` substrate and its face the `cliff_shell` look, the
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
basalt's and a map may override. Both sit in the Terrain section's Natural category.
Mining one is not implemented. Spec: `tests/terrain/cliff_test.luau`.

Plants are cell matter over the ground, never ground: a mapper paints the
`meadow` or `moss_carpet` blend, breathable air plus a litre-thin coat of
`grass` or `moss` (`content/substances/plants/`), drawn by the `grass` and
`moss` looks. A flame latches a plant tile like any fuel
(`content/lib/ignition.luau`); `grass_fire` and `moss_fire` burn the coat to
CO2, steam and ash, and the fire spreads tile to tile until the ground is
bare. Spec: `tests/terrain/meadow_fire_test.luau`.
