# Station editor declarations

`editor/manifest.json` configures both station modes using the engine's
`docs/mapping/manifest.md` declarative schema. Prototype `previews` are ordered
rules: the first matching `when` selects a bottom-to-top `layers` stack.
Conditions read placement properties over the roster's defaults, including
variant defaults. Editing a placement overrides those defaults directly.

Airlock previews cover public, engineering and interior paint, glass, open
position and bolts. Open rules precede bolted rules: an open leaf has no bolt
lamp. Closed bolted rules place the paint's bolt lamp over the selected leaf.
These are authored editor appearances; live power and motion are simulation
state. `content/structures/access/airlock.luau` owns the corresponding runtime art.
The same rules are declared for each airlock variant in both modes.

To add a preview for another structure, add its `kind` and `id` to each
relevant mode's `prototypes`, then write specific property combinations before
broader fallback rules. A rule needs only conditions and atlas layers:

```json
{"when": {"paint": "engineering", "glass": true, "open": true}, "layers": ["door_eng_glass_open"]}
```

Use `state` for a prototype's named state and `direction` for facing when
needed. No callback or new engine behavior is needed for these combinations.
Keep the sprite names aligned with the runtime prototype and run
`node tools/test-editor-previews.mjs`; the matrix checks defaults and explicit
overrides across the shipped paints and variants.

`lattice` and `catwalk` are composition presets (`content/compositions.luau`),
not manifest prototypes: the palette offers them as turf, the roster supplies
their art, and no `prototypes` entry admits them to placement checks.

## Air in the editor

A turf brush auto-paints air as well as substrate: painting an indoor holds-air
composition (floor, plating) over a blank tile fill-if-blanks it with the
breathable pack default `breathable_air` (`content/blends/breathable_air.luau`,
`default = true`, 21/79 at 293.15 K), so fresh indoor turf opens breathable
with an explicit entry rather than by inheritance. Blank is the only thing a
turf stroke fills: painting floor over a painted tile keeps its entry, while a
`wall`, `reinforced_wall` or bare `space` stroke clears the entry outright
(`seat_default_air` in the engine's `doc/placed.rs`) — a wall holds no cell and Space is
boundary vacuum, so the claim cannot legally stay. The engine's
`docs/map-properties/blends.md` owns the lens and `docs/atmos/blends.md` owns
what an unpainted tile opens holding.

The Matter Blend lens (Q, `blend` in both modes) tints every tile that holds a
cell, over a dimmed station: painted floor its id-hashed hue with alpha by gas
moles, unpainted floor the default's faint blue, rowless blends and `Space`
near-black vacuum. Walls read as nothing — a gas-blocking tile opens with no
cell, so the lens leaves the dimmed station showing and a sealed room's
atmosphere reads from its floors alone.

The palette's Matter Blends section folds temperature variants under their
base: `refrigerated_air` — the same 21/79 mixture held at 259.15 K — is
offered under the breathable default's foldout rather than as a lone swatch,
so a walk-in is one gesture from the room it chills (roster `variant_of`,
protocol 107).

An entry is an explicit override: `painted: [(x, y, id)]` replaces inheritance
for that tile, and the eraser (unpainted swatch, right button, Delete) removes
the entry to restore it. Explicit `breathable_air` breathes like unpainted but is
map data: it survives a default change and counts in `tiles_with`. A placement
`blend` likewise replaces prototype contents (precedence placement, variant,
base); a canister ships empty and its `{ "blend": "canister_air", "open": true }`
is per-map authorship (`content/structures/atmos/canister.luau`).

Map atmosphere is the eraser: clearing an entry restores
inherit, which indoors is the pack default, outdoors the map's fixed
`environment.atmosphere_blend` or the selected profile's ambient, and on Space
boundary vacuum. The environment panel offers `Game chooses` or one fixed
recipe, and renaming a blend updates the saved reference (the engine's
`docs/mapping/environment.md`). There is no inherit swatch to paint — the
eraser is the inherit: clear the entry and the tile breathes whatever its
exposure inherits.

## Decals in the editor

The Decal brush paints one of the roster's decals onto a tile; the seam pieces
are derived from the neighbours it now has, so a room is trimmed by painting the
room and never by choosing corners. The palette drawer offers the twelve paints
of `content/lib/decal_paints.luau` in that file's `defaults` order, then the
rest, and — because `decal_colors.free.map` is true — a free colour widget
beside them. An in-game painter has no such widget: `free.play` is false and a
raw colour from a script effect is refused.

Right-click or the erase modifier removes the decal under the cursor. A decal is
pickable in the editor and not in play, which is the one place the two pictures
of a tile deliberately differ.

## Map markers

`player_spawn` and `threat_spawn` are structures under the top-level
`Map Markers` section. They use the `clone` and ordinary placement tools, so copy,
paste, move and undo preserve their properties just like a regular entity.
Their dummy marker icons are authored in `assets/originals/art/markers/`; the
runtime structures are invisible and never appear in a player's world view.

`player_spawn` exposes `weight`, `jobs` and `roles`. `threat_spawn` exposes
`weight`. The number rows run from `0` through `1,000,000`; the words rows are
comma-separated filters and default to empty. These editor defaults match the
placement declarations in `content/structures/spawns/player_spawn.luau` and
`content/structures/spawns/threat_spawn.luau`. Runtime selection and handler behavior
are documented in [`MAP-MARKERS.md`](MAP-MARKERS.md).
