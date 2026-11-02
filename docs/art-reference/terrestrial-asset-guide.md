# Terrestrial asset guide

The art rules, neutral-greyscale tint contract, 5-block seam invariants, 4-layer
shoreline stack and spectral anti-repetition constraints behind the planetary terrain,
ice, cliff, ocean, botanical decal and outcrop sprites. Core pack art direction lives in
[ART.md](../ART.md); bitmask connectivity mechanisms and elemental matter conventions
live in [elemental-asset-guide.md](elemental-asset-guide.md). The authoring, plate and
audit tools live in [tools/art/terrestrial/README.md](../../tools/art/terrestrial/README.md).
Engine contracts are cited as the engine's `docs/…`; upstream `tgstation` citations refer
to the checkout pinned by [assets/tg-revision](../../assets/tg-revision).

---

## 1. Scope & Roster

`assets/originals/art/terrestrial/*.aseprite` holds 11 first-party neutral-greyscale
originals rostered in [assets/sprites/94-terrestrial.ron](../../assets/sprites/94-terrestrial.ron).
They pair directly with `solid_debris_jagged_smooth`
(`assets/originals/art/matter/solids/solid_debris_jagged_smooth.aseprite` in
[assets/sprites/94-elemental.ron](../../assets/sprites/94-elemental.ron)), which uses the
same 4-connected basaltic slab grammar (`#2B2B2B..#D9D9D9`, binary `255` alpha) so loose
scree and rubble blend across planetary shelves.

| Sprite ID | Canvas / kind | Tag | Frames | Alpha tiers | Luma span | Role |
|---|---|---|---|---|---|---|
| `terrain_silicate_rough_smooth` | `160×32` smooth strip | `idle-s` | `1` | `255` | `68..217` (`#444444..#D9D9D9`) | Silicate regolith shelf with 4-connected plate seams |
| `terrain_ice_sheet_smooth` | `160×32` smooth strip | `idle-s` | `1` | `160, 255` | `68..255` (`#444444..#FFFFFF`) | Calving ice shelf with `@160` submerged skirt and pale seams |
| `terrain_cliff_stepped_smooth` | `160×32` smooth strip | `idle-s` | `1` | `96, 255` | `27..255` (`#1B1B1B..#FFFFFF`) | Stepped 3/4 oblique escarpment with `@96` base shadow |
| `ocean_body_smooth` | `160×32` smooth strip | `idle-s` | `12` (`200 ms`) | `112, 168, 216, 255` | `196..238` (`#C4C4C4..#EEEEEE`) | Cellular caustic liquid body and graded nearshore shallows |
| `ocean_backwash_smooth` | `160×32` smooth strip | `idle-s` | `12` (`200 ms`) | `44, 78, 110` | `43..98` (`#2B2B2B..#626262`) | Wet-shoreline soak glaze (`@110`), sheen (`@78`) and fringe (`@44`) |
| `ocean_swash_smooth` | `160×32` smooth strip | `idle-s` | `12` (`200 ms`) | `96, 152, 204, 255` | `170..255` (`#AAAAAA..#FFFFFF`) | Translucent swash tongue and unbroken `#FFFFFF` surf lip |
| `ocean_foam_lace_smooth` | `160×32` smooth strip | `idle-s` | `12` (`200 ms`) | `58, 112, 168` | `170..238` (`#AAAAAA..#EEEEEE`) | Secondary nearshore wave roller and dissolving foam veil |
| `decal_nature_grass_smooth` | `160×32` smooth strip | `idle-s` | `1` | `255` | `146..238` (`#929292..#EEEEEE`) | Broadband diagonal `/` and `\` meadow blade weave decal |
| `decal_nature_moss_smooth` | `160×32` smooth strip | `idle-s` | `1` | `255` | `146..217` (`#929292..#D9D9D9`) | Broadband bryophyte cushion mat decal with creeping lobes |
| `prop_rough_outcrop_1` | `32×32` single | `idle` | `1` | `255` | `43..196` (`#2B2B2B..#C4C4C4`) | Multi-stone matte fieldstone cluster and satellite cobbles |
| `prop_rough_outcrop_2` | `32×32` single | `idle` | `1` | `255` | `43..196` (`#2B2B2B..#C4C4C4`) | Single-piece craggy stepped basalt outcrop with talus base |

---

## 2. Neutral-Greyscale Multiply-Tint Contract

- **Strict achromatic palette membership (`R == G == B`, `max_chroma == 0`)**: Every
  active pixel uses one of the 12 neutral grey swatches in
  [palettes/tales-from-space.gpl](palettes/tales-from-space.gpl): Set 7 `#1B1B1B` (`27`),
  `#262626` (`38`); Set 3 `#1D1D1D` (`29`), `#2B2B2B` (`43`), `#444444` (`68`), `#626262`
  (`98`), `#929292` (`146`), `#AAAAAA` (`170`), `#C4C4C4` (`196`), `#D9D9D9` (`217`); Set 5
  `#EEEEEE` (`238`), `#FFFFFF` (`255`).
- **Forbidden swatches**: Set 5 `black` `#0A0A0D` has chroma `3` (`B > R`) and is
  rejected; Set 19–20 `-reserved` antagonist void blacks (`#060508`, `#110E16`) and
  crimson reds (`#E01040`, `#F10303`, `#FF3355`) are never used ([ART.md](../ART.md)
  §What antagonists reserve).
- **Disjoint per-pixel layer occupancy**: Within any frame, each `(x, y)` pixel is
  populated on at most one layer (`normal` blend). Partial-opacity layers (`@44..@216`)
  never stack over opaque layers inside the `.aseprite` source, keeping flattened PNG
  exports 100% on-palette.
- **Multi-biome reuse under runtime multiply tinting**: Runtime sRGB byte multiply
  `((px * tint + 127) // 255)` lets one greyscale strip render distinct worlds without
  duplicate sprites:
  - **Martian cryo-ammonia sea**: liquid-ammonia sea (`#5EB5C4`) and pale ammonia surf
    (`#E6F7F5`) over iron-oxide silicate shelves and basaltic scree (`#B85C3C`, basin
    substrate `#82402A`, stepped cliffs `#9E482C`, wet backwash `#4A2218`).
  - **Cryovolcanic / polar ice shelf**: calving ice sheets (`#D4EFF7` / `#DCF2FA`) over
    dark basaltic crust (`#5E626E`) and frigid leads (`#4A95AC`).
  - **Earth-like coastal basin**: coastal waters (`#3889C9`) and foam (`#F4FAFF`) lapping
    weathered stone or sand (`#947B62` / `#CBB68C`) with meadow grass (`#86C44A`) and
    bryophyte moss (`#5A9842`) decals.

---

## 3. 5-Block `160×32` Smooth-Strip & Seam Contract

- **Block layout & quadrant stitching**: Each smooth strip measures `160×32` across five
  `32×32` blocks: `0` convex outer corners, `1` vertical (`N+S`), `2` horizontal (`E+W`),
  `3` concave inner elbows, `4` flat interior ([elemental-asset-guide.md](elemental-asset-guide.md)
  §2.1, §3). Diagonal bits (`NE=16, SE=32, SW=64, NW=128`) gate on both flanking cardinals
  (`N=1, S=2, E=4, W=8`), producing 47 canonical junctions (`0..255`).
- **Tag & baker slice**: Every smooth strip carries forward tag `idle-s` over frames
  `1..N`. [assets/sprites/94-terrestrial.ron](../../assets/sprites/94-terrestrial.ron)
  cuts each sheet via `Slice(5, 1, Sprite("<id>", "idle", s))` or
  `Slice(5, 1, Anim("<id>", "idle", s))` into `<id>_0_0` .. `<id>_0_4` (the engine's
  `docs/assets/rosters.md`).
- **Zero-step seam & bare-mask invariants**:
  - `alphaMAX == 0` across every intra-tile quadrant join (`x = 15|16`, `y = 15|16`) and
    inter-tile join (`x = 31|0`, `y = 31|0`) across all 47 junctions and all frames.
    Lone-pixel pruning bridges seam coordinates `{0, 15, 16, 31}` inward by 1 px rather
    than erasing boundary pixels asymmetrically; seam luma ratios stay `<= 2.75`.
  - `dominant_rgb_share < 0.85` holds on every raw block and every stitched junction tile
    with `>= 40` active pixels, passing `no_sprite_is_a_bare_colour_mask` in
    [tools/test-bake-art.mjs](../../tools/test-bake-art.mjs) with `lone_pixel_count == 0`.
  - Static `j=0` terrain, ice, cliff and scree islands preserve north-lit top-down shading
    (`luma_top > luma_bottom`).

---

## 4. 4-Connected Rock & Ice Seams (`tg_basalt` Grammar)

Modeled on `tgstation` `icons/turf/floors.dmi:basalt`, `terrain_silicate_rough_smooth`,
`terrain_ice_sheet_smooth`, the plateau of `terrain_cliff_stepped_smooth`, and
`solid_debris_jagged_smooth` partition the `32×32` periodic torus into discrete
multi-scale plates rather than raw Voronoi distance rings:

- **`2×2` orthogonal elbow completion**: Wherever a 1 px plate seam steps diagonally
  `(x, y) -> (x ± 1, y + 1)`, an orthogonal elbow pixel completes the `2×2` turn so
  crevices remain 4-connected with zero missing-pixel diagonal staircases or pepper noise.
- **1-step overhang & recovery cushioning**: Sun-facing NW seam lips take a 1-step
  highlight (`#D9D9D9` on silicate/scree, `#EEEEEE` on ice) while shadowed SE flanks ease
  through a 1-step recovery slope (`#AAAAAA` / `#929292` on rock, `#C4C4C4` on ice) into
  calm plate interiors (`#C4C4C4` rock, `#D9D9D9` ice). Ice shelves omit dark interior
  cracks (`#AAAAAA..#EEEEEE`) and rim outer edges with a `@160` submerged calving skirt.

---

## 5. 12-Frame 4-Layer Shoreline Stack (`12f @ 200 ms = 2.4 s`)

Planetary surf replaces manual 8-direction shoreline tiles (`tgstation`
`icons/turf/beach.dmi:beach`, `code/game/turfs/open/sand.dm:63-73`) with four synchronized
`12f @ 200 ms` (`2.4 s` loop) smooth strips composited in strict order:

1. **`ocean_body_smooth`** (drawn beneath dry coastal terrain and extended 1 tile under
   calving ice edges over neighboring-quadrant land/ice underlays): steps nearshore alpha
   (`112 -> 168 -> 216 -> 255`) so coastal margins refract the shore substrate with zero
   bare-substrate gaps.
2. **`ocean_backwash_smooth`** (blocks `0..3` over dry shore): lays a dark wet-substrate
   soak (`#2B2B2B..#626262` across `@110`, `@78` and `@44` soaked-glaze, backwash-sheen
   and drying-fringe alpha tiers) as waves crest and drain down-slope.
3. **`ocean_swash_smooth`** (blocks `0..3`): sweeps a translucent water tongue
   (`@96 -> @152 -> @204`) and unbroken curved `#FFFFFF` / `#EEEEEE` (`255`) leading lip
   along a harmonic cosine turnaround with symmetric longshore phase lag (`sym_cos`),
   eliminating high-water piston stalls and pixel shatter.
4. **`ocean_foam_lace_smooth`** (blocks `0..3`): rolls a phase-offset secondary nearshore
   crest (`@168/@112`) shoreward while dissolving a `@58` high-water foam veil behind the
   receding swash lip. Block `4` stays empty across `backwash`, `swash` and `foam_lace`
   so open ocean remains free of whitecap clutter.
- **Turnaround & loop telemetry gates**: Across all 12 frames, every active junction tile
  requires `zero_delta_count == 0` (zero frozen transitions), step-to-step RGBA byte MAE
  ratio `max/min <= 3.0`, and seamless `F12 -> F1` loop closure `0.45 <= wrap_ratio <= 1.75`.

---

## 6. Anti-Repetition Spectral Rule for Periodic `32×32` Organic Fill

Repeating `block 4` (`j=255`) across `4×4+` expanses amplifies low-frequency harmonics
and over-relaxed point lattices into visible `32 px` grid bands or hexagonal polka dots:

- **Zero `k in {1, 2}` macro-harmonics**: Periodic Fourier fields zero all modes below
  `k_min >= 2.8`, suppressing `32 px` (`k=1`) and `16 px` (`k=2`) grid striping.
- **Mildly relaxed multi-scale Poisson seeds (`<= 4` Lloyd iterations)**: `>= 10` Lloyd
  passes crystallize centroids into honeycombs. `ocean_body_smooth` caps relaxation at
  `4` iterations across 17 multi-scale (`0.82..1.26`), `1.58×` vertically foreshortened
  torus seeds with `k in {3, 4, 5}` edge curvature (`tgstation`
  `icons/turf/floors.dmi:riverwater_motion`, `code/game/turfs/open/water.dm:1-7`),
  yielding `#C4C4C4` cells, continuous 1 px `#D9D9D9` caustic lace and `#EEEEEE` cusps.
- **Broadband `k >= 2.8` fields with anisotropic tuft/cushion shading**:
  `decal_nature_grass_smooth` pairs a `k = 2.9..14.2` field with `/` and `\` diagonal
  blade correlation (`#929292 : #C4C4C4 : #EEEEEE` = `1.00 : 1.34 : 1.63`, matching
  `icons/turf/floors/grass.dmi:grass`, `code/game/turfs/open/grass.dm:1-22`) and breaks
  `>= 4 px` orthogonal bars; `decal_nature_moss_smooth` shades a `k = 2.8..13.0` bryophyte
  heightfield from the NNW (`#929292..#D9D9D9`, matching
  `icons/turf/floors/grass_damaged.dmi:grass_damaged`, `code/game/turfs/open/grass.dm:20-26`)
  with zero repeating substrate holes and deeply scalloped creeping lobes on blocks `0..3`.

---

## 7. Matte Outcrop Props

- **Binary solid alpha & grounded silhouettes**: `prop_rough_outcrop_1` and
  `prop_rough_outcrop_2` are `32×32` `1f` (`idle`) props with binary `255` alpha
  ([ART.md](../ART.md) §Form and spatial geometry — zero translucent drop-shadow ovals).
  `prop_rough_outcrop_1` clusters a flat-topped hero boulder with companion cobbles and
  two satellite stones (`tgstation` `icons/obj/fluff/flora/jungleflora.dmi:rock1..3`);
  `prop_rough_outcrop_2` forms a single connected (`pieces == 1`) stepped basalt peak with
  a 45° NW slab and nestled southern talus (`icons/obj/fluff/flora/rocks.dmi:basalt2`).
- **Matte 5-step stone ramp (`#2B2B2B..#C4C4C4`)**: Sunlit upper rims and internal 1 px
  joint clefts use `#444444` and `#626262` (never full-perimeter black outlines), top
  tables stay matte `#AAAAAA` / `#929292` with sparse `#C4C4C4` NW bevels (never
  `#FFFFFF` chrome spikes), and `#2B2B2B` is reserved strictly for southern contact
  shadows and deep undercuts.
