# Elemental asset guide

The art rules, layer stack, importer arms and tile-connectivity mechanisms behind the
ground, water, air and fire sprites. What tgstation offers per element, and what the
pack imports of it, is [elemental-source-inventory.md](elemental-source-inventory.md);
the tools that author and audit the elemental sprites are
[tools/art/elemental/README.md](../../tools/art/elemental/README.md). Engine contracts
are cited as the engine's `docs/…`; upstream paths are tgstation at the revision
[assets/tg-revision](../../assets/tg-revision) pins.

---

## 1. Art Direction, Palette, Layer Stack & Importer Pipeline

### 1.1 Core Art Rules ([`docs/ART.md`](../../docs/ART.md), [`tools/test-bake-art.mjs`](../../tools/test-bake-art.mjs))
- **Resolution & Anchoring**:
  - Standard cell size is `32×32` RGBA on the tile grid ([`docs/ART.md`](../../docs/ART.md)).
  - Oversized sprites (`32×48`, `32×64`, `64×32`, `64×64`, `96×96`, up to `512×512`) are supported when declared with `anchor: Center | Base` or sliced into a multi-tile grid via `Slice(cols, rows, ...)` (the engine's `docs/assets/rosters.md`, the engine's `docs/assets/importers.md`).
- **Alpha & Pixel Discipline ([`docs/ART.md`](../../docs/ART.md))**:
  - **Binary alpha (`0` or `255`)** for all solid sprites (turfs, walls, machines, items, debris chunks). No anti-aliased edge fringes against transparency, no checkerboard dithering, no pillow shading.
  - **Partial alpha (`1..254`)** is reserved strictly for glass panes, liquid puddles/streams, gas/mist/smoke/weather overlays, decals, and emissive glows.
- **Top-Down Oblique Projection & North-South Lighting ([`docs/ART.md`](../../docs/ART.md))**:
  - Camera views both the top horizontal plane and south-facing vertical front face (`~30–45°` oblique).
  - Light falls from **above and slightly north** (top of the screen):
    - Top horizontal bevels take brightest highlight (`step 6–7`).
    - South-facing front faces take mid-tones (`step 3–5`).
    - Bottom base lips and undercuts take deepest shadow (`step 1–2`).
    - Measured corpus luminance: top third avg `103.5`, bottom third `81.2`, left/right symmetric (`91.2` / `90.4`).
  - **4-Way Directional Rule ([`docs/ART.md`](../../docs/ART.md))**: Cardinal states (`_s`, `_n`, `_e`, `_w`, corresponding to DMI dirs `0, 1, 2, 3`) must be **four distinct drawings** under fixed north lighting — never 90° clockwise rotations of one drawing, except for radially flat top-down marks/splatters/projectiles (`Rotated(...)`, e.g. `blood_splatter`, `shrapnel`).
- **Animation Timing & Static Housing Invariant ([`docs/ART.md`](../../docs/ART.md))**:
  - Frame durations are multiples of `100 ms` (`1 ds` in BYOND DMI metadata); never `<100 ms`.
  - **Static housing invariant**: `0` housing pixels may shift during operating loops; motion stays inside the working bay, fluid surface, or flame/arc overlay.
- **Art Gate Tripwire ([`tools/test-bake-art.mjs`](../../tools/test-bake-art.mjs))**:
  - `no_sprite_is_a_bare_colour_mask`: Any sprite with `>=40` opaque pixels where `>=85%` of pixels share one exact achromatic RGB value fails `sh tools/check.sh` unless exempted in `FLAT_BY_DESIGN = ["white", "space", "ghost", "wind_streak"]` or `FLAT_FAMILIES = ["decal_"]`.
  - **Implication for greyscale runtime-tinted assets** (puddles, powders, crystals, smoke, foam): The greyscale source sprite **must preserve multi-step internal value shading** (highlights, midtones, dark edge/core) so that after `Luminance(...)` or runtime multiply tinting it still has depth and passes the gate.

### 1.2 Canonical Palette ([`docs/art-reference/palettes/tales-from-space.gpl`](../../docs/art-reference/palettes/tales-from-space.gpl))
20 named sets (155 unique colours):
1. **Set 1 — Structure steel** (cool blue-grey walls/airlocks/girders, 8 steps): `#26262c` -> `#3c3f48` -> `#535864` -> `#6d7381` -> `#89919f` -> `#a8b0bd` -> `#c6cdd7` -> `#e1e7ea`
2. **Set 2 — Machine steel** (navy-tinted bodies/frames, 8 steps): `#151824` -> `#262b3d` -> `#3b4158` -> `#535b76` -> `#6e7794` -> `#8e96b2` -> `#b1b7cc` -> `#d5d7e0`
3. **Set 3 — Neutral steel** (achromatic tools/pipes/ducts/flooring, 8 steps): `#1d1d1d` -> `#313131` -> `#484848` -> `#616161` -> `#7c7c7c` -> `#999999` -> `#b8b8b8` -> `#d9d9d9`
4. **Set 4 — Copper/brass** (`#3b1d11`, `#64331b`, `#955129`, `#c87d42`, `#f0b06e`) & **Dark rubber** (`#201d26`, `#35313e`, `#4f4a5a`)
5. **Set 5 — Panel glass & shared**: glass `#4a687b`, `#6d91a5`, `#a4bac6`; `black` `#0a0a0d`; `near-white` `#eeeeee`; `white-glint` `#ffffff`; `paper` `#f1ead4`; `paper-ink` `#202c2d`
6. **Set 6 — Wood** (`#3a2314`, `#5b3a24`, `#7d563c`, `#a07c59`) & **Ceramic beige** (`#6b5d4d`, `#968572`, `#bfb09c`)
7. **Set 7 — Safety paint** (`#1b1b1b`, `#262626`, `#b5b92b`, `#d2d53d`) & **Fire red** (`#4f011c`, `#66041b`, `#a2081b`, `#c61326`)
8. **Set 8 — Signals & emissives**: `led-green` `#50ff31`, `led-amber` `#ffd60e`, `led-yellow` `#ffff33`, `led-red` `#ff441b`, `screen-cyan` `#00ccff`, `screen-sky` `#8cd6fd`, `screen-ice` `#80ffff`, `plasma-core` `#c93cff`, `plasma-glow` `#f08cff`, `bluespace-core` `#2667d1`, `bluespace-glow` `#65b4ff`
9. **Sets 9–18 — Leadership & Department Ramps** (Command blue, CentCom green, Security navy+ice, Medical blue+sterile white, Science violet+orchid, Engineering hi-vis yellow+safety orange+atmos teal, Service leaf green+linen+botany blue+janitor purple, Cargo russet+khaki, Clown pink+coral)
10. **Sets 19–20 — Antagonist & Blood**: Void black (`#060508`..`#4c4656`) & Blood crimson (`#3f010d`, `#68021a`, `#9a0526`, `#d4143a`, `#ff3355`, `#f10303`, `#960000`)

### 1.3 World Visual Layer Stack ([`content/compositions.luau`](../../content/compositions.luau))
From bottom (drawn first) to top (drawn last):
1. `substrate` — Planetary/environment base (`space`, `ground`, `rock_floor`).
2. `cover` — Structural turf stack:
   - `support` (`station_base` plating, `lattice`, `catwalk`)
   - `exposed_cover` (`open_floor` / `reinforced_floor` when subfloor access is open)
   - `infrastructure` (`pipe`, `power` cable)
   - `cover` occupants (`floor_tiles`, `grid_cover`, `reinforcement`, `wall`, `reinforced_wall`, `rock`, `glass_floor`, `reinforced_glass_floor`, `plasma_glass_floor`, `reinforced_plasma_glass_floor`)
3. `decal` — Trimlines, floor tile paint overlays, hazard stripes, floor markings, blood splatters.
4. `residue` — Settled blast/volley fragments (`Kind 0`) and fallout dust (`Kind 1`) from [`content/residue_appearances.luau`](../../content/residue_appearances.luau).
5. `matter_ground` — Condensed liquid puddles/streams (drawn first) and solid powders/granules/crystals/chunks (drawn over liquids) from [`content/matter_appearances.luau`](../../content/matter_appearances.luau).
6. `fixture` — Floor drains, vents, scrubbers, wall frames, APCs, doors.
7. `low_object` — Tables, racks, chairs, closets, crates.
8. `item` — Loose items on the floor.
9. `large_object` — Girders, canisters, tanks.
10. `lying_mob` -> `standing_mob` -> `overhead_entities`.
11. `gas_haze` — Atmospheric visible gases + `wind_streak` overlay.
12. `effects` — Transient sprite effects (`sim.visual.spawn`, e.g., `blast_fire`, `spray_puff`) and procedural `scene_fx` (`field`, `plume`, `shimmer`, `sparks`, `ring`, `arc`, `flash`, `glow`, `flicker_glow`).

### 1.4 Importer Arms Available in `assets/sprites/*.ron` (the engine's `docs/assets/importers.md`)
- **DMI single/animated**: `Dmi("@sheet", "state", dir)`, `DmiAnim("@sheet", "state", dir)` (looping), `DmiAnimOnce("@sheet", "state", dir)` (one-shot), `DmiRewind("@sheet", "state", dir)` (ping-pong loop), `DmiFrame("@sheet", "state", dir, frame)`.
- **DMI cropping & compositing**: `DmiWindow("@sheet", "state", dir, x, y, w, h)` (used to crop `32×32` out of `40×40` or `48×48` smoothed DMIs), `DmiBlend([Layer("@sheet", "state", dir, Over | Add | Multiply | Under), ...])`, `Overlay(base, top)`.
- **Bitmask smoothing (47 canonical diagonal-aware states `0..255`)**: `Junctions("prefix", "dmi_state")` (for `32×32` DMIs with states `dmi_state-0..255`).
- **Colour & orientation transforms**: `Luminance(inner)` (converts greyscale luminance to alpha-weighted white for runtime tinting), `Tinted(inner, "#RRGGBB" | (r,g,b))`, `Rotated(inner, quarter_turns_cw)`.
- **First-party Aseprite / PNG**: `Ase("@sheet", "tag")`, `AseAnim("@sheet", "tag")`, `AseAnimOnce("@sheet", "tag")`, `AseLayer("@sheet", "layer", "tag")`, `Png("path.png")`, `Slice(cols, rows, inner)`.

---

## 2. Connectivity-Driven Tilesets (Autotiling, Bitmask Smoothing & Networks)

There are **three distinct connectivity mechanisms** in the engine and the pack (plus `tgstation`'s upstream `cutter` pipeline):

### 2.1 Mechanism A: 47-State Diagonal-Aware Bitmask Smoothing (`Junctions` + `smooth = { ... }`)
- **How the Bitmask Works** (tg `code/__HELPERS/icon_smoothing.dm`, the engine's `docs/content-schema/structures.md`, the engine's `crates/xtask/src/roster/group.rs`):
  - Checks the 4 cardinal neighbors (`N=1, S=2, E=4, W=8`) and only checks a diagonal corner (`NE=16, SE=32, SW=64, NW=128`) when **both** of its flanking cardinals are connected.
  - Because diagonal bits are gated on their cardinals, exactly **47 of the 256 byte values** are reachable:
    `[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 21, 23, 29, 31, 38, 39, 46, 47, 55, 63, 74, 75, 78, 79, 95, 110, 111, 127, 137, 139, 141, 143, 157, 159, 175, 191, 203, 207, 223, 239, 255]`.
- **How the pack bakes and declares it**:
  - **Atlas Bake**:
    - For standard `32×32` DMI sheets: `Junctions("prefix", "dmi_state")` in a `groups` entry (e.g. [`assets/sprites/90-smooth-structures.ron`](../../assets/sprites/90-smooth-structures.ron)) automatically expands all 47 sprites `prefix-0` .. `prefix-255`.
    - For oversized overhanging DMI sheets (`40×40` like `smoothrocks.dmi` or `48×48` like `shale.dmi`): `Junctions` refuses non-`32×32` cells, so the 47 states are listed with `DmiWindow([("@sheet", "state-<n>")], 0, x, y)` (e.g. `4, 4` for `40×40` in [`90-smooth-structures.ron`](../../assets/sprites/90-smooth-structures.ron)).
  - **Luau Declaration** (`content/structures/**/*.luau`):
    ```luau
    sprite = "lattice-0",
    turf = "component:lattice", -- optional: binds this structure to a turf composition component
    smooth = {
        group = "lattice",                -- group this tile announces
        with = { "lattice", "catwalk" },  -- groups it smooths toward (defaults to { group })
        flow = { "station_base", "floor_tiles" }, -- asymmetric: smooths into these turf components without smoothing them back
        sprites = "lattice",              -- resolves "lattice-<junction>"
    },
    ```
- **Imported 47-State Smoothed Families in the pack**:
  1. `lattice-0..255` (`90-smooth-structures.ron` <- `obj/smooth_structures/lattice.dmi`, wired in [`lattice.luau`](../../content/structures/construction/lattice.luau))
  2. `catwalk-0..255` (`90-smooth-structures.ron` <- `obj/smooth_structures/catwalk.dmi`, wired in [`catwalk.luau`](../../content/structures/construction/catwalk.luau))
  3. `table-0..255` (`90-smooth-structures.ron` <- `obj/smooth_structures/table.dmi`, wired in [`table.luau`](../../content/structures/furniture/table.luau))
  4. `reinforced_table-0..255` (`90-smooth-structures.ron` <- `obj/smooth_structures/reinforced_table.dmi`, wired in [`reinforced_table.luau`](../../content/structures/furniture/reinforced_table.luau))
  5. `wood_table-0..255` (`90-smooth-structures.ron` <- `obj/smooth_structures/wood_table.dmi`, wired in [`wood_table.luau`](../../content/structures/furniture/wood_table.luau))
  6. `rock-0..255` (`90-smooth-structures.ron` <- `turf/smoothrocks.dmi` cropped 32×32, wired in [`rock.luau`](../../content/structures/construction/rock.luau))
  7. `glass_floor-0..255` (`90-smooth-structures.ron` <- `turf/floors/glass.dmi`, wired in [`glass_floor.luau`](../../content/structures/floor_windows/glass_floor.luau))
  8. `reinforced_glass_floor-0..255` (`90-smooth-structures.ron` <- `turf/floors/reinf_glass.dmi`, wired in [`reinforced_glass_floor.luau`](../../content/structures/floor_windows/reinforced_glass_floor.luau))
  9. `plasma_glass_floor-0..255` (`90-smooth-structures.ron` <- `turf/floors/plasma_glass.dmi`, wired in [`plasma_glass_floor.luau`](../../content/structures/floor_windows/plasma_glass_floor.luau))
  10. `reinforced_plasma_glass_floor-0..255` (`90-smooth-structures.ron` <- `turf/floors/reinf_plasma_glass.dmi`, wired in [`reinforced_plasma_glass_floor.luau`](../../content/structures/floor_windows/reinforced_plasma_glass_floor.luau))
  11. `dirt-0..255` ([`13-dirt.ron`](../../assets/sprites/13-dirt.ron) <- `effects/dirt.dmi`, baked into the atlas).

- **Unimported 47-State Smoothed Tilesets in `tgstation` (and how upstream authors them)**:
  - Upstream generates `.dmi` files from a **5-tile-wide strip PNG (`160×32` for `32×32` tiles)** + a `.png.toml` cutter recipe (tg `icons/Cutter.md`): `[None, N+S, E+W, N+S+E+W, All]`.
  - **Unimported `32×32` `Junctions`-Ready Terrain & Liquid/Lava Sheets**:
    - **Liquids & Magma**: `turf/floors/water_lavaland.dmi` (47 states), `turf/floors/lava.dmi` (47 states, each **4-frame animated**) + `turf/floors/lava_mask.dmi` (47 emissive masks).
    - **Shoreline Outlines (Inverse Bitmask)**: `turf/floors/basalt_outline.dmi`, `turf/floors/shale_outline.dmi`, `turf/floors/siderite_outline.dmi` (47 states each — drawn around water/lava tiles so the surrounding rock forms a stepped shoreline lip).
    - **Planetary & Station Floors**: `turf/floors/snow_turf.dmi`, `turf/floors/ice_turf.dmi`, `turf/floors/chasms.dmi`, `turf/floors/icechasms.dmi`, `turf/floors/junglechasm.dmi`, `turf/floors/hexacrete.dmi`, `turf/floors/bamboo_mat.dmi`, `turf/floors/carpet*.dmi` (20+ colors).
    - **Walls & Barriers**: `turf/walls/wall.dmi` & `reinforced_wall.dmi` (only `-0` is imported), `rusty_wall.dmi`, `rusty_reinforced_wall.dmi`, `concrete.dmi`, `sandstone_wall.dmi`, `snow_wall.dmi`, `reinforced_rock.dmi` (`porous_rock-*`), `titanium_wall.dmi`, `plastitanium_wall.dmi`, `obj/smooth_structures/{window,reinforced_window,plasma_window,reinforced_plasma_window,titanium_window,plastitanium_window,sandbags,boulder_platform,hedge,alien_weeds,grave_overlay}.dmi`.
  - **Unimported Overhanging (`40×40` / `48×48` / `50×50`) 47-State Terrain Sheets** (importable via `DmiWindow` like `smoothrocks.dmi`):
    - `40×40` (crop `4, 4`): `turf/floors/ash.dmi`, `turf/floors/rocky_ash.dmi`, `turf/walls/rock_wall.dmi`, `turf/walls/mountain_wall.dmi`, `turf/walls/icerock_wall.dmi`, `turf/cliff/icerock_cliff.dmi`.
    - `48×48` (crop `8, 8`): `turf/floors/shale.dmi`, `turf/floors/siderite.dmi`, `turf/walls/red_rock.dmi`, `turf/walls/shale.dmi`.
    - `50×50` (crop `9, 9`): `turf/floors/grass.dmi`, `turf/floors/grass_damaged.dmi`, `turf/floors/junglegrass.dmi`.

### 2.2 Mechanism B: 16-State Cardinal Topology Networks (`0..15` Masks + Port Stubs)
- **How It Works** (the engine's `docs/content-schema/composition-networks.md`, [`content/compositions.luau`](../../content/compositions.luau)):
  - Used for subfloor/surface networks (`power` cables across channels `l1..l3`, `pipe` standard & `radiator_pipe` across channels `l1..l5`).
  - Uses a 4-bit cardinal mask `0..15` (`N=1, S=2, E=4, W=8`) resolved by the server from reciprocal neighbor connectivity (`shapes_by_channel[channel][mask]`), plus 4-direction `port_shapes` (`connected`, `exposed`, `half`) underlaid beneath inline/unary machines.
  - Imported in [`assets/sprites/50-pipes-and-cable.ron`](../../assets/sprites/50-pipes-and-cable.ron) and [`51-heat-exchange.ron`](../../assets/sprites/51-heat-exchange.ron).

### 2.3 Mechanism C: Directional Edge / Corner / Shoreline Transitions (4-Dir & 8-Dir Manual / Map-Authored Borders)
- **How It Works**:
  - Rather than full 47-state auto-smoothing, many transitions in the pack and `tgstation` are authored as **directional border overlays or decals** (`4d` cardinals or `8d` cardinals + diagonals, plus inner/outer corner states):
  - **In the pack ([`11-decals.ron`](../../assets/sprites/11-decals.ron))**:
    - `decal_trim_line_{s,n,e,w,se,sw,ne,nw}` + `decal_trim_corner_{s,n,e,w}` + `decal_trim_end_{s,n,e,w}`.
    - `decal_hazard_{s,n,e,w,se,sw,ne,nw}` + `decal_hazard_corner_{s,n,e,w}` + `decal_hazard_end_{s,n,e,w}`.
    - `decal_tile_{half,three_quarter,corner}_{s,n,e,w}` + `decal_tile_four_corners`.
  - **Unimported in `tgstation`**:
    - **Beach / Surf Shoreline (`icons/turf/beach.dmi`)**: `"beach"(8d,8f)` and `"beach-corner"(4d,8f)` (animated waves lapping onto sand in all 8 directions + 4 inner corners).
    - **Snow Drifts & Corners (`icons/turf/snow.dmi`, `icons/turf/overlays.dmi`)**: `"snow_corner"(8d)`, `"snow_surround"(4d)`, `"gravsnow_corner"(8d)`, `"gravsnow_surround"(4d)`, `"platingdrift"(4d)`, `"snowfloor_{e,n,s,w}"`, `"snowwall_{e,n,s,w}"`.
    - **Dirt & Siding Borders (`icons/turf/decals.dmi`)**: `"dirt_side"(8d)`, `"siding_plain"(8d)` + `"siding_plain_corner"(4d)` + `"siding_plain_corner_inner"(4d)` + `"siding_plain_end"(4d)`, `"siding_wood*"`, `"siding_thinplating*"`, `"siding_wideplating*"`.
    - **Rock Cliff Faces (`icons/turf/mining.dmi`)**: `"rock_side_{s,n,w,e}"`, `"redrock_side_{w,e,n,s}"`.

---

## 3. Authored smooth strips

The elemental matter and fire sprites under `assets/originals/art/matter/` and
`assets/originals/art/fx/fire/` are authored as one `.aseprite` per sprite by
[tools/art/elemental/](../../tools/art/elemental/README.md):

- A `single` sprite is one 32×32 cell per frame. A `smooth_strip` is the 160×32
  five-block strip of Mechanism A (`0:convex 1:vertical 2:horizontal 3:concave 4:flat`);
  each junction tile takes each 16×16 quadrant from the block its two cardinals and
  corner select (`NE=16, SE=32, SW=64, NW=128`).
- The roster cuts a strip with `Slice(5, 1, <row>)`. On an Aseprite original the inner
  row names a state and the baker reads the tag `<state>-s`: `Slice(5, 1, Anim("name",
  "idle", s))` reads the tag `idle-s`, and the canvas must be exactly 160×32.
- Every colour is a swatch of `tales-from-space.gpl`. A `colorable` sprite is neutral
  grey (R = G = B) so the runtime tint multiplies it; it still keeps several grey steps
  so it is never a bare colour mask (`tools/test-bake-art.mjs`).
