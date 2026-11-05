# Drainage asset guide

The art rules behind the liquid fixtures (`floor_drain`, `scupper`, `sump_pump`) and the
multi-Z intake head suite (`intake_head`, `intake_vault`, `intake_upper_deck`,
`intake_ceiling_below`, `vault_mouth_caps`). Core pack art direction lives in
[ART.md](../ART.md); the fixtures sit beside the air vents and scrubbers and borrow their
flat, subdued look. The specs and tools live in
[tools/art/drainage/README.md](../../tools/art/drainage/README.md), and `drainage_kit.py`
and `intake_validation.py` enforce every number below.

## 1. Roster

Sources are `assets/originals/art/machines/drainage/<name>.aseprite`, rostered in
[assets/sprites/21-atmos-thermal-room-and-canisters.ron](../../assets/sprites/21-atmos-thermal-room-and-canisters.ron)
and [assets/sprites/22-atmos-mouth-caps.ron](../../assets/sprites/22-atmos-mouth-caps.ron).

| Source | Frames | Tags | Atlas sprites |
|---|---|---|---|
| `floor_drain` | 5 | `idle`, `draining` | `floor_drain`, `floor_drain_draining` |
| `scupper` | 20 | `idle-<dir>`, `draining-<dir>` | `scupper` (flat), `scupper_<dir>`, `scupper_draining_<dir>` |
| `sump_pump` | 12 | `off-<dir>`, `pumping-<dir>`, `fault-<dir>` | `sump_pump_off_<dir>`, `sump_pump_pumping_<dir>`, `sump_pump_fault_<dir>` |
| `intake_head` | 1 | `idle` | `intake_head` |
| `intake_vault` | 4 | `closed`, `opening`, `open` | `intake_vault_closed`, `intake_vault_opening`, `intake_vault_open` |
| `intake_upper_deck` | 12 | `depressed`, `opening`, `elevated`, `closing` | `intake_upper_depressed`, `intake_upper_opening`, `intake_upper_elevated`, `intake_upper_closing` |
| `intake_ceiling_below` | 12 | `submerged`, `ascending`, `retracted`, `descending` | `intake_below_submerged`, `intake_below_ascending`, `intake_below_retracted`, `intake_below_descending` |
| `vault_mouth_caps` | 20 | `l1_1` .. `l5_8` | `pipe_cap_vault_l{1..5}_{1\|2\|4\|8}` |

`<dir>` is `n`, `s`, `e`, `w`, the suffix form the engine's `Directions` and `Anim` rows read
(`docs/assets/rosters.md`). Every canvas is 32×32 RGBA; every layer stays editable.

## 2. Seating

- **Compact floor fixtures** (`floor_drain`, `sump_pump`) span `19×19` at `x, y = 6..24`,
  centred on pixel 15, the footprint of `scrub_off`. That leaves y = 5 clear for a north
  mouth cap, so a pipe stub meets the body on every piping layer.
- **The floor drain** is 4-fold symmetric, so one picture serves every facing. It seats
  `mouth_cap = "scrub"`.
- **The sump pump** seats `mouth_cap = "vent"`. A solid steel manifold spine lies across the
  frame on the east and west facings (frames 1..6) and down it on the north and south
  facings (7..12), so a mouth always meets steel. The `e`/`w` tags share frames, as do
  `n`/`s`. Both axes keep the north-top lighting; the N-S axis is redrawn, never rotated.
- **The scupper** is drawn on the wall tile, against the edge beside the room: north `19×15`
  at (6, 17), south `19×14` at (6, 0), east `14×19` at (0, 6), west `14×19` at (18, 6). West
  mirrors east; no face is a plain rotation of another. Two 11 px `M1` slits run parallel
  to the wall on all four faces, as tg's `dirs=4` wallmounts do, over a 4-slot brass weir.
  The head roster's `offsets` displace `scupper_<dir>` and `scupper_draining_<dir>` by a
  whole tile (`±32`) toward the wall. The flat `scupper` carries no offset: it is what the
  fixture draws off its wall (`docs/construction/mounts.md`).
- **The intake head multi-Z suite** pairs a full-tile top-down orthographic vault
  (`intake_vault` and `intake_upper_deck`, `32×32`, `1,024` opaque pixels with a `3 px`
  stationary outer curb at `0..2` and `29..31` and a `24×24` hexagonal shaft aperture at
  `4..27`) on deck `z` with an independent 3/4th-perspective undertile ceiling rig
  (`intake_ceiling_below`, `28×32` at `x = 2..29, y = 0..31` when lowered and `28×5` at
  `x = 2..29, y = 0..4` when retracted on `f7`) on deck `z - 1`. The isolated 3/4th
  hexagonal concrete-and-brass crown (`intake_head`) spans `24×24` at `x = 4..27, y = 3..26`
  with zero internal water animation.
- **Vault mouth caps** (`vault_mouth_caps`, `mouth_cap = "vault"`) seat `5×3` (`N`/`S`) or
  `3×5` (`E`/`W`) `S2..S6` structure-steel collars on the `3 px` stationary vault curb across
  piping tracks `l1..l5` (`shift = (ch - 3) * 5`, track spans `3..7`, `8..12`, `13..17`,
  `18..22`, `23..27`), with zero pairwise pixel overlap across all 20 ports.

## 3. Value and palette

Colours come only from `docs/art-reference/palettes/tales-from-space.gpl`.

- **Flat like a vent (`floor_drain`, `scupper`, `sump_pump`).** Housing mean luma stays in
  `68..118`, maximum `148`, with 5 to 14 colours on a still frame and up to 18 on an animated
  one. Their outer perimeter uses step-2 or step-3 swatches, never black or a `*-1-outline`.
- **Warm Hexacrete & Brushed Brass (`intake_*`, `vault_mouth_caps`).** The intake suite pairs
  warm ceramic-concrete (`CE1..CE3`), brushed khaki-brass (`CK1..CK3`, `EY1..EY2`), burnished
  copper (`CU2..CU5`), and structural/machine steel (`S1..S7`, `M1..M3`, `BLK`), using 14 to 24
  colours on the vault/head/undertile frames and 5 (`S2..S6`) on each `5×3` vault mouth cap.
  The isolated `intake_head` uses a dark `S1`/`M2` outer contour so it shares `0` boundary
  hexes with the open `intake_vault` (`f4`) at `dy = 0`.
- **North-top light.** The top of a body reads brighter than its bottom: a scupper by 2 to 42
  luma, a floor drain or sump pump by 2.5 to 38, `intake_head` by at least 20, and each
  `vault_mouth_caps` collar by at least 15.
- **Connected pieces and zero lone pixels.** Every frame has `lone_pixels == 0`. Every
  fixture and mouth cap frame is a single connected component (`pieces == 1`), except
  `intake_ceiling_below` frames `f1..f6` and `f8..f12`, where the upper ceiling rig
  (`y < 30`) and the floor drop-shadow (`y = 30..31`) each form 1 connected piece separated
  by the `y = 29` hover gap.

## 4. Animation

- Frame durations are multiples of 100 ms: the drain/scupper/pump flow loops run four frames
  at 200 ms; the intake transitions (`opening`, `closing`, `ascending`, `descending`) run at
  100 ms between 1-frame static holds (`depressed`/`elevated`, `submerged`/`retracted`).
- On `floor_drain`, `scupper`, and `sump_pump`, only the flow layer moves and stays inside a
  dark throat (luma under 36), changing 6 to 65 pixels across a loop.
- On `intake_upper_deck`, the `3 px` outer vault curb stays stationary while the bisected
  hexagonal cover unlocks with a `90°` rotary brass cam-latch twist (`f2`) and retracts into
  side pockets (`f3..f4`) before the `24×24` 3/4th `intake_head` rises (`f4..f7`,
  `dy = +13, +7, +2, 0`) and recedes (`f8..f9`, `dy = +5, +11`) ahead of cover closure
  (`f10..f12`).
- On `intake_ceiling_below`, the `24×24` `intake_head` hangs from a central `6 px`
  (`x = 13..18`) steel/brass hydraulic piston inside a `24 px` (`x = 4..27`) recessed ceiling
  throat with bolted outer collar cheeks (`x = 2..3, 28..29`), rising from `dy = +2` (`f1`)
  to `dy = -22` (`f7`) while its floor drop-shadow (`y = 30..31`) shrinks monotonically.

## 5. Status lights

The `sump_pump` alone carries status LEDs: `off` lights none, `pumping` shows 1 to 4 subdued
teal pixels (`AT2`/`AT3`), and `fault` shows 1 to 4 subdued red pixels (`FR2..FR4`) and no
teal. Every other drainage and intake source carries zero LED pixels.
