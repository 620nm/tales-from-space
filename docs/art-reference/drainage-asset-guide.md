# Drainage asset guide

The art rules behind the three liquid fixtures: `floor_drain`, `scupper` and `sump_pump`.
Core pack art direction lives in [ART.md](../ART.md); the fixtures sit beside the air vents
and scrubbers and borrow their flat, subdued look. The specs and tools live in
[tools/art/drainage/README.md](../../tools/art/drainage/README.md), and `drainage_kit.py`
enforces every number below.

## 1. Roster

Sources are `assets/originals/art/machines/drainage/<name>.aseprite`, rostered in
[assets/sprites/21-atmos-thermal-room-and-canisters.ron](../../assets/sprites/21-atmos-thermal-room-and-canisters.ron).

| Source | Frames | Tags | Atlas sprites |
|---|---|---|---|
| `floor_drain` | 5 | `idle`, `draining` | `floor_drain`, `floor_drain_draining` |
| `scupper` | 20 | `idle-<dir>`, `draining-<dir>` | `scupper` (flat), `scupper_<dir>`, `scupper_draining_<dir>` |
| `sump_pump` | 12 | `off-<dir>`, `pumping-<dir>`, `fault-<dir>` | `sump_pump_off_<dir>`, `sump_pump_pumping_<dir>`, `sump_pump_fault_<dir>` |

`<dir>` is `n`, `s`, `e`, `w`, the suffix form the engine's `Directions` and `Anim` rows read
(`docs/assets/rosters.md`). Every canvas is 32×32 RGBA; every layer stays editable, bottom
to top a static body, an animated flow layer, and static bars.

## 2. Seating

- **Floor fixtures** span `19×19` at `x, y = 6..24`, centred on pixel 15, the footprint of
  `scrub_off`. That leaves y = 5 clear for a north mouth cap, so a pipe stub meets the body
  on every piping layer.
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

## 3. Value and palette

Colours come only from `docs/art-reference/palettes/tales-from-space.gpl`.

- **Flat like a vent.** Housing mean luma stays in `68..118`, maximum `148`. Chrome, whites,
  neon signals and loud orange or gold are banned swatches.
- **Soft outer bevel.** The outer perimeter uses step-2 or step-3 swatches, never black or a
  `*-1-outline`.
- **North-top light.** The top of a body reads brighter than its bottom; a scupper by 2 to 38
  luma, a sump pump by 2.5 to 38.
- **Colour count.** 5 to 14 colours on a still frame, 18 on an animated one.
- **One piece.** A frame is a single connected shape with no lone pixels.

## 4. Animation

- Frame durations are multiples of 100 ms: the flow loops run four frames at 200 ms.
- Only the flow layer moves. The housing and bars are identical across a tag.
- Flow stays inside a dark throat (luma under 36): it never overwrites metal or brass and
  never hides under a bar. Between 6 and 65 pixels change across a loop.
- No two adjacent frames match, and the idle frame of the drain carries no flow.

## 5. Status lights

The sump pump alone carries LEDs. `off` lights none, `pumping` shows 1 to 4 subdued teal
pixels, and `fault` shows 1 to 4 subdued red pixels and no teal. `fault` is the picture of a
pump that cannot move liquid.
