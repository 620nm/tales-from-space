# Elemental source inventory

Per element (ground, water, air, fire): what the pack imports from tgstation and the
tgstation art it leaves unimported. Rules and mechanisms are in
[elemental-asset-guide.md](elemental-asset-guide.md). Upstream paths are tgstation at the
revision [assets/tg-revision](../../assets/tg-revision) pins; sprite rosters are
`assets/sprites/*.ron`.

---

## 1. Ground (Terrain, Turfs, Walls, Decals, Dirt, Residue, Solid Matter)

### 1.1 Imported in the pack

#### A. Substrates & Backdrop
| Sprite ID | Manifest Location | Source (`tgstation/icons/...` or `assets/originals/...`) | Content Usage |
|---|---|---|---|
| `space_backdrop` (`_0_0`..`_14_14`) | [`assets/sprites.ron`](../../assets/sprites.ron) | `effects/parallax.dmi` (`"layer1"` Over + `"layer2"` Add + `"layer3"` Add, 15×15 grid) | `content/environments/space.luau`, `meadow.luau` |
| `space` | [`10-turf-fixtures-and-tools.ron`](../../assets/sprites/10-turf-fixtures-and-tools.ron) | `turf/space.dmi` `"space"` | `substrate` in [`compositions.luau`](../../content/compositions.luau) |
| `ground` | [`10-turf-fixtures-and-tools.ron`](../../assets/sprites/10-turf-fixtures-and-tools.ron) | `turf/snow.dmi` `"snow"` | `substrate` in [`compositions.luau`](../../content/compositions.luau) (`#C8C0B0`) |
| `rock_floor` | [`10-turf-fixtures-and-tools.ron`](../../assets/sprites/10-turf-fixtures-and-tools.ron) | `turf/floors.dmi` `"asteroid"` | `substrate` in [`compositions.luau`](../../content/compositions.luau) (`#4B3E38`) |

#### B. Covers, Floors, Supports, Walls & Rock
| Sprite ID | Manifest Location | Source | Content Usage |
|---|---|---|---|
| `plating` | [`10-turf-fixtures-and-tools.ron`](../../assets/sprites/10-turf-fixtures-and-tools.ron) | `turf/floors.dmi` `"plating"` | `station_base` (`support`) & `grid_cover` (`cover`) |
| `lattice-0`..`255` (47 states) | [`90-smooth-structures.ron`](../../assets/sprites/90-smooth-structures.ron) | `obj/smooth_structures/lattice.dmi` `Junctions("lattice", "lattice")` | `lattice` (`support`, `smooth_group = "lattice"`) |
| `catwalk-0`..`255` (47 states) | [`90-smooth-structures.ron`](../../assets/sprites/90-smooth-structures.ron) | `obj/smooth_structures/catwalk.dmi` `Junctions("catwalk", "catwalk")` | `catwalk` (`support`, `smooth_group = "catwalk"`) |
| `floor` | [`10-turf-fixtures-and-tools.ron`](../../assets/sprites/10-turf-fixtures-and-tools.ron) | `turf/floors.dmi` `"floor"` | `floor_tiles` (`cover`) |
| `open_floor` | [`95-originals.ron`](../../assets/sprites/95-originals.ron) | `originals/art/turf/open_floor.aseprite` `"open_floor"` | `floor_tiles` when `controls = "open"` (`exposed_cover`) |
| `reinforced_floor` | [`10-turf-fixtures-and-tools.ron`](../../assets/sprites/10-turf-fixtures-and-tools.ron) | `turf/floors.dmi` `"engine"` | `floor_tiles` variant & `reinforcement` (`cover`) |
| `wall` | [`10-turf-fixtures-and-tools.ron`](../../assets/sprites/10-turf-fixtures-and-tools.ron) | `turf/walls/wall.dmi` `"wall-0"` (unsmoothed single state) | `wall` (`cover`) |
| `reinforced_wall` | [`10-turf-fixtures-and-tools.ron`](../../assets/sprites/10-turf-fixtures-and-tools.ron) | `turf/walls/reinforced_wall.dmi` `"reinforced_wall-0"` (unsmoothed) | `reinforced_wall` (`cover`) |
| `reinforced_wall_1`..`6` | [`10-turf-fixtures-and-tools.ron`](../../assets/sprites/10-turf-fixtures-and-tools.ron) | `turf/walls/reinforced_states.dmi` `"r_wall-1..6"` | [`reinforced_wall_frame.luau`](../../content/structures/construction/reinforced_wall_frame.luau) |
| `rock-0`..`255` (47 states) | [`90-smooth-structures.ron`](../../assets/sprites/90-smooth-structures.ron) | `turf/smoothrocks.dmi` `"smoothrocks-<n>"` (`DmiWindow` 32×32 at `(4,4)` from 40×40) | `rock` (`cover`, `smooth_group = "rock"`) |
| `glass_floor-0..255`, `reinforced_glass_floor-0..255`, `plasma_glass_floor-0..255`, `reinforced_plasma_glass_floor-0..255` | [`90-smooth-structures.ron`](../../assets/sprites/90-smooth-structures.ron) | `turf/floors/{glass,reinf_glass,plasma_glass,reinf_plasma_glass}.dmi` | Transparent floor windows in `cover` |

#### C. Decals ([`assets/sprites/11-decals.ron`](../../assets/sprites/11-decals.ron), [`content/lib/decal_paints.luau`](../../content/lib/decal_paints.luau))
- **Trimlines & Fills**: `decal_trim_line_*`, `decal_trim_end_*`, `decal_trim_box`, `decal_trim_corner_*`, and `decal_trim_fill_*` from `turf/decals.dmi`.
- **Floor Tile Paint Overlays**: `decal_tile_half_*`, `decal_tile_three_quarter_*`, `decal_tile_four_corners`, `decal_tile_corner_*` from `turf/decals.dmi`, tinted by 12 swatches (`neutral`, `dark`, `white`, `blue`, `red`, `yellow`, `green`, `purple`, `Mime`, `bar`, `freezer`, `hydro`).
- **Hazard Stripes & Markings**: `decal_hazard_*` (yellow, red, white), `decal_mark_{delivery,bot,loading_*,arrows_*,caution_*,stand_clear_*}`.
- **Blood Splatter Decal**: `blood_splatter_{n,e,s,w}` (`effects/blood.dmi` `"gibbl1"` rotated 0..3, painted `#AA1010`).

#### D. Dirt, Blast Residue & Solid Condensed Matter
- **Residue ([`assets/sprites/13-dirt.ron`](../../assets/sprites/13-dirt.ron), [`content/residue_appearances.luau`](../../content/residue_appearances.luau))**:
  - `Kind 0` (fragments): `dirt_flat_0` (`at = 1`) -> `dirt_flat_1..3` (`at = 15`, from `effects/dirt_misc.dmi`) -> `blast_shards` (`at = 40`, from `obj/debris.dmi` `"shards"`).
  - `Kind 1` (cloudy fallout): `dust` (`at = 1`, from `effects/dirt_misc.dmi` `"dust"`).
  - **Also baked in `13-dirt.ron`**:
    - `dirt-0..255` (47 smoothed states from `effects/dirt.dmi`).
    - `scorch_{s,n,e,w}` (`effects/effects.dmi` `"scorch"`).
- **Solid Condensed Matter ([`assets/sprites/93-matter.ron`](../../assets/sprites/93-matter.ron), [`content/matter_appearances.luau`](../../content/matter_appearances.luau))**:
  - `powder` (default solid): `matter_dust` (`dirt_misc.dmi` `"dust"`, `at_ml = 1`) -> `matter_powder` (`obj/debris.dmi` `"concrete_dust"`, `at_ml = 10`).
  - `granular` (ash/charcoal): `matter_granular_small` (`obj/debris.dmi` `"ash"`, `at_ml = 1`) -> `matter_granular_large` (`"big_ash"`, `at_ml = 30`).
  - `crystalline` (ice/salt/sugar): `matter_crystalline_1..4` (`obj/debris.dmi` `"tiny"` dirs `0..3`, `at_ml = 1`) -> `matter_crystalline_large` (`"shards"`, `at_ml = 25`).
  - `amorphous` (gels/fats/soap/wax): `matter_amorphous_small` (`effects/effects.dmi` `"molten"`, `at_ml = 2`) -> `matter_amorphous_large` (`"big_molten"`, `at_ml = 30`).
  - `chunks` (rubble/slag): `matter_granular_small` (`at_ml = 2`) -> `matter_granular_large` (`at_ml = 15`) -> `matter_chunks` (`obj/debris.dmi` `"rubble"`, `at_ml = 40`).

---

### 1.2 Unimported Ground Material in `tgstation`

1. **Planetary & Natural Turfs (`icons/turf/floors.dmi`, `icons/turf/mining.dmi`, `icons/turf/sand.dmi`, `icons/turf/snow.dmi`)**:
   - **Asteroid / Moon / Wasteland / Iron Sand (`code/game/turfs/open/asteroid.dm:10-200, 570-610`)**:
     - `icons/turf/floors.dmi`: `"asteroid_dug"`, `"asteroid0"`..`"asteroid12"` (13 pebble/crater scatter states; only base `"asteroid"` is imported), `"ironsand1"`..`"ironsand15"`, `"moon"`, `"moon_dug"`, `"moon0"`..`"moon12"`, `"wasteland"`, `"wasteland_dug"`, `"wasteland0"`..`"wasteland12"`.
   - **Basalt & Magma-Cracked Basalt (`code/game/turfs/open/basalt.dm:5`, `asteroid.dm:240-360`)**:
     - `icons/turf/floors.dmi`: `"basalt"`, `"basalt_dug"`, `"basalt0"`..`"basalt12"` (where `"basalt1"`, `"basalt2"`, `"basalt3"`, `"basalt5"`, `"basalt9"` are 4-frame animated glowing ember/magma cracks).
   - **Ash, Shale, Siderite, Permafrost & Watery Rock (`code/game/turfs/open/ashplanet.dm`, `asteroid.dm:371-394`)**:
     - `icons/turf/mining.dmi`: `"ash"`, `"rockyash"`, `"wateryrock"`, `"wateryrock1"`..`"wateryrock9"`, `"spring"`, `"permafrost"`, `"shale"`, `"volcanic_biome"`, `"basalt_biome"`.
     - Smoothed sheets in `icons/turf/floors/`: `ash.dmi` (`40×40`, 47 states), `rocky_ash.dmi` (`40×40`, 47 states), `shale.dmi` (`48×48`, 47 states) + `shale_variants.dmi` (`"shale1..8"`, `"shale_dug"`) + `shale_outline.dmi` (`32×32`, 47 states), `siderite.dmi` (`48×48`, 47 states) + `siderite_variants.dmi` + `siderite_outline.dmi` (`32×32`, 47 states), `basalt_outline.dmi` (`32×32`, 47 states).
   - **Dirt, Grass, Sand, Snow, Ice & Chasms**:
     - `icons/turf/floors.dmi`: `"dirt"`, `"greenerdirt"`, `"grass"`, `"grass0..3"`, `"fairygrass"`, `"fairygrass0..3"`, `"junglegrass"`, `"sand"`, `"sandmoving"(1d,18f)`, `"sandmovingfast"(1d,8f)`, `"hay"`, `"asphalt"`, `"stone_floor"`, `"sandstone_floor"`.
     - `icons/turf/sand.dmi`: `"sand_dug"`, `"sand"`, `"sand1..3"`, `"sand4"(4d)`.
     - `icons/turf/snow.dmi`: `"snow_dug"`, `"snow0..12"`, `"snow_corner"(8d)`, `"snow_surround"(4d)`, `"gravsnow_corner"(8d)`, `"gravsnow_surround"(4d)`, `"ice"`, `"snow-ice"`, `"snowplating"`, `"platingdrift"(4d)`.
     - `icons/turf/floors/snow_turf.dmi` (`32×32`, 47 states), `ice_turf.dmi` (`32×32`, 47 states), `grass.dmi` (`50×50`, 47 states), `junglegrass.dmi` (`50×50`, 47 states).
     - `icons/turf/floors/chasms.dmi` (`32×32`, 47 states `chasms-*`), `icechasms.dmi` (`32×32`, 47 states), `junglechasm.dmi` (`32×32`, 47 states).
     - `icons/turf/floors/concrete.dmi` (`32×32`, 19 states: `"conc_smooth*"`, `"conc_slab_1..4"`, `"conc_tiles"`, `"concdam_1..4"`, `"pavement*"`), `hexacrete.dmi` (`32×32`, 47 states).
2. **Smoothed Walls, Mineral Walls, Ore Veins & Cliffs**:
   - **Station Walls**: `icons/turf/walls/wall.dmi` and `reinforced_wall.dmi` have all **47 bitmask-smoothed states** (`wall-0..255`, `reinforced_wall-0..255`) in `32×32` (`Junctions` ready); only state `-0` is imported. Also `rusty_wall.dmi`, `rusty_reinforced_wall.dmi`, `titanium_wall.dmi`, `plastitanium_wall.dmi`, `concrete.dmi`, `sandstone_wall.dmi`, `snow_wall.dmi`.
   - **Mineral/Rock Walls & Cliffs**: `icons/turf/walls/rock_wall.dmi` (`40×40`, 47 states), `mountain_wall.dmi` (`40×40`, 47 states), `icerock_wall.dmi` (`40×40`, 47 states), `red_rock.dmi` (`48×48`, 47 states), `reinforced_rock.dmi` (`32×32`, 47 states), `icons/turf/cliff/cliff.dmi` (`32×32`), `icons/effects/ore_visuals.dmi` (`32×32`, 11 ore vein overlays: `"rock_iron"`, `"rock_titanium"`, `"rock_silver"`, `"rock_gold"`, `"rock_uranium"`, `"rock_plasma"`, `"rock_diamond"`, `"rock_bscrystal"`, `"rock_boulder"`, etc.).
3. **Floor Damage, Cracks, Rust, Weather Transitions & Debris**:
   - `icons/turf/damaged.dmi` (`32×32`, 78 states): `"floorscorched1..2"`, `"damaged1..5"`, `"wood-broken*"`, `"glass-damaged1..3"`, `"noslip-damaged1..3"`, `"sand_damaged"`, `"grass_damaged"`.
   - `icons/effects/cracks.dmi` (`32×32`, 10 states): `"crack1"`..`"crack10"`.
   - `icons/effects/rust_overlay.dmi` (`32×32`): `"rust_default"`.
   - `icons/turf/decals.dmi` (`code/game/objects/effects/decals/turfdecal/weather.dm:1-19`): `"sandyfloor"`, `"sandyplating"`, `"ashyfloor"`, `"ashyplating"`, `"moonsandfloor"`, `"moonsandplating"`, `"dirt_side"(8d)`, `"siding_plain*"`, `"siding_thinplating*"`, `"siding_wideplating*"`, `"ast_warn*"`, `"derelict1..16"`.
   - `icons/obj/debris.dmi`: `"large"`, `"medium"`, `"plasmalarge..tiny"`, `"titaniumlarge..tiny"`, `"plastitaniumlarge..tiny"`, `"paper_shreds"`, `"garbage"(1d,6f)`, `"rubble_bounce"(1d,4f)`.
   - `icons/effects/web.dmi`: `"cobweb1"(1d,15f)`, `"cobweb2"(1d,35f)`, `"sticky_overlay"`.
   - `icons/effects/effects.dmi`: `"dent"`, `"bullet_hole"`, `"shreds"`, `"paper_scatter"(1d,5f)`.

---

## 2. Water and liquids (Puddles, Flowing Water, Blood, Foam, Substances)

### 2.1 Imported in the pack
- **`liquid` Condensed Matter Profile ([`assets/sprites/93-matter.ron`](../../assets/sprites/93-matter.ron), [`content/matter_appearances.luau`](../../content/matter_appearances.luau))**:
  - `matter_liquid_3` (`at_ml = 2`), `matter_liquid_2` & `matter_liquid_5` (`at_ml = 10`), `matter_liquid_1` & `matter_liquid_6` (`at_ml = 25`) — imported via `Luminance(Dmi("@blood", "floor*", 0))` from `icons/effects/blood.dmi` and tinted at runtime by the substance mixture's weighted `color` (`alpha = 0.85`, `full_volume_ml = 50`).
- **`flowing` Condensed Matter Profile ([`assets/sprites/93-matter.ron`](../../assets/sprites/93-matter.ron), [`content/matter_appearances.luau`](../../content/matter_appearances.luau))**:
  - Used by `water` (`#AAAAAA`) and `heavy_water` (`#99AABB`).
  - `at_ml = 2`: `matter_liquid_3` -> `at_ml = 15`: `matter_liquid_2`, `matter_liquid_5` -> `at_ml = 50`: `matter_water` (`turf/floors.dmi` `"riverwater_motion"`, 8-frame loop) -> `at_ml = 150`: `matter_deep_water` (`turf/floors.dmi` `"deep_riverwater_motion"`, 8-frame loop).
- **Decals, Drains & Tools**:
  - `blood_splatter_{n,e,s,w}` (`11-decals.ron` <- `effects/blood.dmi` `"gibbl1"`).
  - `floor_drain` (`21-atmos-thermal-room-and-canisters.ron` <- `obj/pipes_n_cables/hydrochem/plumbers.dmi` `"disposal"`).
  - `mop` (`10-turf-fixtures-and-tools.ron` <- `obj/service/janitor.dmi` `"mop"`).
  - `soap_bar`, `soap_wet`, `soap_bubbles` (`95-originals.ron` <- `originals/art/items/debug/soap.png` & `.aseprite`, unwired in `content/`).

### 2.2 Unimported Water & Liquid Material in `tgstation`
1. **Smoothed Water Turfs, Beaches, Pools & Immersion Masks**:
   - `icons/turf/floors/water_lavaland.dmi` (`32×32`, 47 bitmask states `water_lavaland-*`, `code/game/turfs/open/water.dm:141-196`) — smoothed water body designed to pair with `basalt_outline.dmi`, `siderite_outline.dmi`, and `shale_outline.dmi`.
   - `icons/turf/floors.dmi`: `"riverwater"` (static), `"pool_1"`..`"pool_4"` (hot spring / pool tiles, `water.dm:215`), `"liquidplasma"(4d,11f)`.
   - `icons/turf/beach.dmi` (`32×32`, `water.dm:110-128`, `sand.dm:66`): `"water"(1d,3f)`, `"deepwater"(1d,3f)`, `"beach"(8d,8f)` (animated surf shoreline), `"beach-corner"(4d,8f)`, `"tizira_water"(1d,3f)`.
   - `icons/effects/effects.dmi`: `"immerse"(1d,6f)` & `"immerse_deep"(1d,6f)` (wading masks, `water.dm:21, 94`), `"splash"(1d,10f)`, `"splash_floor"(1d,10f)`, `"splash_hydroponics"(1d,11f)`, `"bubbles"(1d,5f)`.
2. **Wet Floor & Ice Overlays (`icons/effects/water.dmi`, `32×32`, `code/datums/components/wet_floor.dm:7-10`)**:
   - `"wet_floor"(1d,8f)` (sparkling wet floor), `"wet_floor_static"`, `"wet_static"`, `"ice_floor"` (frozen slip overlay).
3. **Viscous/Oil Puddles, Caustic Spills, Geysers & Showers**:
   - `icons/obj/watercloset.dmi` (`32×32`, `code/game/objects/structures/shower.dm:207`): `"puddle"`, `"puddle-splash"(1d,2f)`, `"puddle-oil"(1d,9f)`, `"puddle-oil-splash"(1d,5f)`, `"water"(4d,4f)` (falling shower spray).
   - `icons/effects/effects.dmi` (`32×32`): `"fuel_pool"` & `"fuel_pool_hivis"` (`cleanable/fuel.dm:1-118`), `"waste_spill"` & `"waste_spill_active"(1d,5f)` (bubbling caustic sludge, `cleanable/toxic.dm:3-73`), `"greenglow"` (`mess.dm:113-144`).
   - `icons/obj/mining_zones/terrain.dmi` (`32×64`, `lavaland/geyser.dm:7-44`): `"geyser"`, `"geyser_acid"(1d,5f)`, `"geyser_soup"(1d,6f)` (greyscale tintable bubbling spring), `"well"(1d,5f)`.
4. **Extinguisher & Metal Foam (`icons/effects/effects.dmi`, `32×32`, `effect_system/fluid_spread/effects_foam.dm:13-360`)**:
   - `"foam"` (greyscale extinguisher foam billow), `"foam-disolve"(1d,6f)`, `"mfoam"`, `"mfoam-disolve"(1d,6f)`, `"metalfoam"`, `"ironfoam"`.
5. **Blood Splatters, Drips, Trails, Footprints & Organic Messes**:
   - `icons/effects/blood.dmi` (`32×32`, 160 states): `"splatter1..6"`, `"hitsplatter1..3"(4d,11f)`, `"drip1..5"`, `"tracks"(8d)`, `"trails_1..2"(8d)`, `"gibbl2..5"`, `"gib1..6"`, `"remains*"`, `"vomit_1..4"`, `"vomittox_1..4"`.
   - `icons/effects/footprints.dmi` (`32×32`, 14 states): `"blood1..2"(4d)` (entering/exiting footprints), `"footprint1..2"(4d)`, paw/claw/bot variants.

---

## 3. Air, mist and clouds (Gas Haze, Wind, Smoke, Steam, Weather)

### 3.1 Imported / Rendered in the pack & the engine
1. **Gas haze + wind streaks (`gas_haze` layer, the `haze` profile of [`content/matter_appearances.luau`](../../content/matter_appearances.luau))**:
   - Every visible gas in `content/substances/*.luau` (`water` steam `#C8D4E0`, `plasma` `#E03997`, `chlorine` `#B8E986`, `ammonia` `#D8E8D0`, `iodine` `#9B30FF`, `uf6` `#C8D8A0`) draws the profile's one rung, a flat `white` tile quad tinted by `visible.tint`, with alpha climbing from `.05` to full at the substance's `visible.factor`.
   - When an `AirCell.wind` is non-zero, the profile's `streak` sprite `wind_streak` ([`assets/sprites/95-originals.ron`](../../assets/sprites/95-originals.ron) <- `assets/originals/art/fx/wind_streak.png`) is rotated along the velocity vector and scrolled across the tile on a sawtooth phase, solid at `full_alpha_mps = 8`.
2. **Spray Puffs**:
   - `spray_puff` (the `92-*-fillings.ron` roster <- `obj/medical/chempuff.dmi` `""`), used by `fire_extinguisher.luau` and `spray_bottle.luau`.
3. **Engine Density Plume Automaton (`sim.visual.plume`, the engine's `crates/lunatic-client/src/scene_fx/density.rs`, the engine's `docs/luau-api/effects.md`)**:
   - `sim.visual.plume({ at, strength, speed?, color?, direction_x?, direction_y?, duration? })`: 32×32 cellular density advection field that rises, drifts with wind `lean` (`±2 px`), and rasters translucent smoke/steam/mist plumes. 

### 3.2 Unimported Air, Mist, Cloud & Weather Material in `tgstation`
1. **Animated Atmospheric Gas Overlays (`icons/effects/atmospherics.dmi`, `32×32`, 21 states, `code/modules/atmospherics/gasmixtures/gas_types.dm:55-340`)**:
   - `"water_vapor"(1d,8f)` (`#b0c4de` rolling mist/steam cloud), `"plasma"(1d,3f)`, `"nitrous_oxide"(1d,12f)`, `"freon"(1d,8f)`, `"nitrium"(1d,12f)`, `"tritium"(1d,5f)`, `"miasma"(1d,8f)`, `"fusion_gas"(1d,6f)`, `"healium"(1d,12f)`, `"proto_nitrate"(1d,12f)`, `"zauker"(1d,12f)`, `"halon"(1d,12f)`, `"antinoblium"(1d,6f)` + 8 `*_old` variants.
2. **Billowing Smoke, Steam Wisps, Mist & Dust Clouds**:
   - `icons/effects/96x96.dmi` (`96×96`, `effect_system/fluid_spread/effects_smoke.dm:4-15`): `"smoke"(4d,3f)` (3×3 billowing greyscale smoke cloud, tintable), `"smoke2"(1d,3f)`.
   - `icons/effects/effects.dmi` (`32×32`): `"smoke"(4d,4f)` (1-tile directional smoke), `"smoke_trail"(1d,11f)` (`effects_trail.dm:111`), `"extinguish"(8d,4f)` (extinguisher mist burst), `"dust_cloud"(1d,7f)` & `"light_dust_cloud"(1d,7f)` (ore-vent dust clouds, `vent_misc.dm:16-19`).
   - `icons/effects/steam.dmi` (`32×32`, `components/grillable.dm:201`): `"steam_single"(1d,8f)`, `"steam_triple"(1d,8f)` (rising steam wisps).
   - `icons/obj/watercloset.dmi` (`32×32`, `structures/shower.dm:413-420`): `"mist"` (translucent tile mist overlay).
   - `icons/effects/eldritch.dmi` (`32×32`): `"smoke"(1d,10f)`, `"cloud_swirl"(1d,5f)`, `"cosmic_cloud"(1d,8f)`.
3. **Smoke, Steam, Fog & Ash Particle Sprites (`icons/effects/particles/smoke.dmi`, `32×32`, 17 states, `effects/particles/smoke.dm:1-135`)**:
   - `"smoke_1..3"`, `"steam_1..3"`, `"steam_cloud_1..5"` (hot-spring steam clouds), `"ash_1..3"`, `"chill_1..3"` (cold breath / frost fog).
4. **Weather Overlays (`icons/effects/weather_effects.dmi` & `glow_weather.dmi`, `32×32`, `code/datums/weather/weather_types/*.dm`)**:
   - `"light_ash"(1d,32f)` & `"ash_storm"(1d,8f)` (plus matching glowing ember layers in `glow_weather.dmi`).
   - `"light_snow"(1d,16f)` & `"snow_storm"(1d,16f)` (plus `glow_weather.dmi`).
   - `"rain_low"(1d,32f)`, `"rain_med"(1d,32f)`, `"rain_high"(1d,32f)`.
   - `"dust_low"(1d,8f)`, `"dust_med"(1d,8f)`, `"dust_high"(1d,8f)` (sand/dust storm).
   - `"void"`, `"void_storm"`, `"nebula_radstorm"`.

---

## 4. Fire, flames and heat (Hotspots, Lava, Scorch, Doom-Fire, Shimmer)

### 4.1 Imported / Rendered in the pack & the engine
1. **Explosion & Tool Flames**:
   - `blast_fire` ([`assets/sprites/13-dirt.ron`](../../assets/sprites/13-dirt.ron) <- `effects/effects.dmi` `"explosion"`, 9-frame `AnimOnce`), spawned by [`content/lib/blast.luau`](../../content/lib/blast.luau) alongside `flash`, `ring`, `sparks`, `shake`, `glow`.
   - `scorch_{s,n,e,w}` ([`assets/sprites/13-dirt.ron`](../../assets/sprites/13-dirt.ron) <- `effects/effects.dmi` `"scorch"`), baked in atlas.
   - `welder_lit` & `welder_flame` ([`10-turf-fixtures-and-tools.ron`](../../assets/sprites/10-turf-fixtures-and-tools.ron), `emissive: ["welder_flame"]` in [`sprites.ron`](../../assets/sprites.ron)).
   - `burner_lit` ([`10-turf-fixtures-and-tools.ron`](../../assets/sprites/10-turf-fixtures-and-tools.ron) <- the `obj/medical/` burner sheet `"burner-on"`).
   - `paperplane_onfire` ([`41-writing.ron`](../../assets/sprites/41-writing.ron) <- `obj/service/bureaucracy.dmi` `"paperplane_onfire"`).
2. **Engine Fire Cellular Automaton, Heat Shimmer & Flicker Glow (the engine's `crates/lunatic-client/src/scene_fx.rs`, the engine's `docs/luau-api/effects.md`)**:
   - **`sim.visual.field({ at, palette, strength, duration })`**: 32×32 Doom-fire cellular automaton stepping every `40 ms` (`FIELD_STEP_MS = 40.0`), leaning with wind and indexing into a named color ramp in `sprites.ron` `palettes: [...]`.
   - **`sim.visual.shimmer({ at, strength, duration })`**: Per-texel horizontal sine wave heat-haze displacement column rising `0.5..4` tiles above `at`.
   - **`sim.visual.flicker_glow({ at, strength, range?, color?, duration? })`**: Dynamic point light with a 50 ms flickering envelope (`0.55..1.0`).

### 4.2 Unimported Fire, Lava & Thermal Material in `tgstation`
1. **Atmospheric Hotspot & Turf Flames (`icons/effects/fire.dmi`, `32×32`, 5 states, `code/modules/atmospherics/environmental/LINDA_fire.dm:64-351`)**:
   - `"light"(4d,6f)`: Low-intensity tile fire (`volume <= 0.4 * CELL_VOLUME`).
   - `"medium"(4d,14f)`: Medium-intensity tile fire (`volume > 0.4 * CELL_VOLUME`).
   - `"heavy"(4d,14f)`: Full-tile roaring inferno (`volume > 0.95 * CELL_VOLUME`).
   - `"fire"(1d,3f)`: Generic burning object/component overlay (`components/burning.dm:1`).
   - `"overcharged"(1d,9f)`: Additive plasma/arc overlay for ultra-hot fires (`>400,000 K`, `LINDA_fire.dm:254`).
   - *(Upstream tints greyscale/base fire across temperature ramps: red-orange at `1000–3000 K`, white-blue at `>40,000 K`, or cyan for cold freon fires.)*
2. **Lava Turfs & Emissive Masks (`icons/turf/floors.dmi`, `icons/turf/floors/lava.dmi`, `lava_mask.dmi`, `code/game/turfs/open/lava.dm:7-105, 373-435`)**:
   - Unsmoothed (`icons/turf/floors.dmi`): `"lava"(1d,32f)` + `"lava-lightmask"`.
   - Smoothed (`icons/turf/floors/lava.dmi`, `32×32`, 47 bitmask states `lava-*`, each `1d,4f` animated) + `icons/turf/floors/lava_mask.dmi` (47 emissive masks), paired with inverse shore outlines `basalt_outline.dmi`, `siderite_outline.dmi`, `shale_outline.dmi`.
3. **Burning Mob Overlays (`icons/mob/effects/onfire.dmi`, `32×32`, 5 states)**:
   - `"human_small_fire"(4d,20f)`, `"human_big_fire"(4d,20f)`, `"monkey_small_fire"(4d,20f)`, `"monkey_big_fire"(4d,20f)`, `"generic_fire"(4d,20f)`.
4. **Bonfires, Fireplaces, Jet Plumes, Scorch, Sparks & Acid Sizzle**:
   - `icons/effects/particles/bonfire.dmi` (`32×32`, `"bonfire"`), `icons/obj/mining_zones/legionnaire_bonfire.dmi` (`32×32`, `"bonfire"(1d,2f)`), `icons/obj/fluff/fireplace.dmi` (`64×64`, `"firepit"`, `"firepit-active"(1d,3f)`, `"fireplace*"`).
   - `icons/effects/effects.dmi` (`32×32`): `"jetfire"(4d,4f)`, `"jet_plume"(1d,7f)`, `"mech_fire"(1d,4f)`, `"thermite"`, `"light_scorch"`, `"sparks"(4d,8f)`, `"mech_sparks"(1d,4f)`.
   - `icons/effects/welding_effect.dmi` (`32×32`, `"welding_sparks"(1d,60f)`).
   - `icons/effects/acid.dmi` (`32×32`, `""(1d,3f)`, `"default"(1d,6f)` — melting acid sizzle overlay).
