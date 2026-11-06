# Art direction

First-party art (drawn for this pack under `assets/originals/art/`) and
every recolor of a baked tg sprite follow this file. The station is
drawn in tgstation's idiom at the revision `assets/tg-revision` pins
(`3c5ff70be69`); where this file diverges, chiefly in color identity
and indicator restraint, it wins. The unified palette is
[tales-from-space.gpl](art-reference/palettes/tales-from-space.gpl);
visual plates, coordinate tables, the file icon recipe and provenance
live in [art-reference](art-reference/README.md).

## tg's current direction

tg keeps the classic 32×32 top-down oblique view with visible front
faces. The Wallening's 3/4 tall walls (4b4e9dff1d7) were reverted twenty
days later (9a9b428b61f); what stayed is platforms as frames without
windows (7146a6bb105), signs (b3d0dfa40a0), TVs (c779d0fabd3) and
weather planes (22d319fa860). Its resprites since 2023 share four habits:

- Readability before detail: fewer shades and less noise (68032b2587c,
  ab90ddbf821), and crude old box art redrawn around real mechanisms
  (3286f3b5b42 space heater, 97c05fd7d57 bluespace scrubber/receiver,
  a4bfd0f8060 PLANKMAN generator).
- One family, one treatment: outlines match within a family (7f24072526b),
  wallmounts drop the hard outline (0d684300114, 50bd8054b44), and a
  family shares one palette (77a90bd99e6 circuit shells, 88fb9423904
  command blue, 9d045f7cb69 medbots matching medkits).
- Grayscale art colored by configuration (GAGS), clothing above all
  (2427db409ef, 38dc2369ef1), with job colors as defines
  (229910f33dd, `code/__DEFINES/preferences.dm:185-201`).
- Metal holds its hue and gains saturation as value drops (`lathes.dmi`:
  hue 228–232°, saturation 5% to 42%). Cloth hue-shifts, shadows toward
  violet and highlights toward yellow (`rsecurity` 330° to 3°, `centcom`
  150° to 120°); a reversed shift is a bug (ab90ddbf821). Department
  colors are settled (`COLOR_*` 86ef806f1ae; `CIRCUIT_COLOR_*` b7cb5cea163).

## Form and spatial geometry

Sprites are 32×32 RGBA on the tile grid (tall fixtures use 32×48 or
32×64; dual-bay lathes use 64×32). Solid sprites take binary alpha with
no anti-aliasing and no dithering; glass, gas, liquids, glows and emissives
may use partial alpha. Two solid strips are the exception, each on one
layer: `terrain_ice_sheet_smooth`'s submerged skirt is alpha 160 and
`terrain_cliff_stepped_smooth`'s base shadow alpha 96
([terrestrial-asset-guide.md](art-reference/terrestrial-asset-guide.md) §1).
Block the silhouette first so it reads in grayscale.
Light falls from the top of the screen: top faces take the highlight and
south faces sit darker, with no left/right bias. Using Rec.709 luma
(`0.2126 R + 0.7152 G + 0.0722 B`), across 1,363 south-facing tg
machine, storage and structure sprites the top third averages luma 103.5,
the bottom third 81.2, and the left and right thirds 91.2 and 90.4.

- **Oblique plane ratios**: Low floor items (`<=16 px` tall) show
  `65–75%` top plane and `25–35%` front lip. Waist-high tables, beds and
  consoles (`24–28 px`) split `40–50%` top plane and `50–60%` front
  face (`table.dmi` gives `75%` to its calm top surface so placed items
  stay legible). Full-tile cabinets (`28–32 px`) show `15–25%` top bevel
  and `75–85%` front face; tall `32×48` or `32×64` lockers and pods keep
  the top rim to `10–15%`.
- **Three-part functional hierarchy**: Every machine separates (1) a
  quiet structural housing (`50–70%` of opaque pixels in `4–6` metal or
  ceramic steps), (2) one primary working component (`15–30%`: a glass
  chamber, radiator fin bank, carafe bay, or screen), and (3) a
  concentrated control cluster (`5–15%`: a keypad, slot, or gauge). Open
  interior recesses (`sleeper-open`, `pod-open`) step `2–3` ramp values
  darker (`#151824`–`#2b2b2b`) than the outer shell.
- **Four-directional redraws & paper-doll coordinates**: `SOUTH`,
  `NORTH`, `EAST` and `WEST` are four distinct drawings (`computer.dmi`),
  never 90° rotations, so overhead lighting never flips. `NORTH` hides
  south-facing screens behind the rear casing; `EAST`/`WEST` narrow the
  horizontal footprint by `4–8 px`. World items (`icons/obj/`) sit
  centered on the canvas (`14–22 px` span), whereas worn clothing
  (`icons/mob/clothing/`) and inhands (`icons/mob/inhands/`) lock to the
  human paper-doll (`x=8..23`; coordinates in
  [art-reference](art-reference/README.md)).
- **Outlines**: A primary or material ramp's step 1 is its outline.
  Secondaries, glass and signals sit inside another ramp's outline.
  Wallmounts (`turret_control.dmi`, `wall_healer.dmi`, `vitals_monitor.dmi`)
  drop the hard outline and separate from the wall via a step-2 outer
  bevel and step-5/6 top highlight. Review every sprite at 1× on light
  and dark floors (`08-context.png`).

## Animation timing and LED restraint

Animation frame durations use BYOND deciseconds (`1 ds = 100 ms`). Never
author sub-tick durations below `100 ms`.

- **Static housing invariant**: During active work loops (`sheater-heat`,
  `bluespace_scrubber_1`, `portgen3_1`), **zero housing pixels move**.
  Motion stays inside the working component across `12–75 px` (`2–15%`
  of the 1,024-pixel canvas) over `2–4` frames at `100–200 ms` per
  frame.
- **Transitions, glints and cycles**: One-shot mechanical transitions
  (door open/close, pod sealing) use `6` frames at `100 ms` (`600 ms`
  total). Ambient screen or crystal glints hold a long pause frame
  (`[100 ms × N, 3000–5000 ms × 1]`). Heavy machinery splits loops into
  phase-matched `startup → active → shutdown` states.
- **LED and display restraint**: Bright indicator pixels and animated
  displays are used sparingly (`1–4 px` per fixture, such as
  `sheater-off`'s single `#b91411` power pixel out of 502 opaque pixels)
  and strictly to report real state (power, access, active work, fault,
  or live patient/stock telemetry as in `vitals_monitor.dmi` and
  `wall_healer.dmi`).
- **The `telecomms.dmi` anti-pattern (`05-telecomms.png`)**:
  `icons/obj/machines/telecomms.dmi` is what **NOT** to do with LEDs and
  animation. Its cabinet and dish silhouettes (`relay`, `processor`,
  `bus`, `hub`, `comm_server`, `message_server`, `broadcast receiver`)
  are structurally sound, but 7 of the 8 machines pepper dark housings
  with dozens of bright cyan and amber pixels that blink and sweep
  continuously at `75–100 ms` across `6–16` frames while completely idle
  (`relay` loops 16 frames at `100 ms`; `message_server` flickers at
  `0.75 ds` / `75 ms`). Placed together (`08-context.png`), they turn a
  room into visual noise. Only `broadcaster` follows the rule: a
  `1-frame` static idle state that plays `broadcaster_send` (`6` frames)
  only when transmitting.

## Palette (`tales-from-space.gpl`)

All station materials, department colors and antagonist reservations
live in one unified GIMP/Aseprite palette,
[tales-from-space.gpl](art-reference/palettes/tales-from-space.gpl)
(`20` sets, `155` unique colors; visualized in `07-palette.png`). Swatch
names use single hyphenated tokens (`structure-1-outline`) because
Aseprite's `.gpl` reader truncates swatch names at the first space.

| Sets in `tales-from-space.gpl` | Holds | Use for |
| --- | --- | --- |
| Sets `1–8` (Station & materials) | structure, machine and neutral steel; copper/brass (`#3b1d11`–`#f0b06e`); dark rubber (`#1d1d1d`–`#4f4a5a`); panel glass, blacks, whites and paper; wood and ceramic beige (`#6b5d4d`–`#bfb09c`); safety paint; signals and plasma/bluespace emissives | every station object, housing, cable, coil, appliance and status light |
| Sets `9–18` (Leadership & departments) | leadership gold; Command; CentCom; Security; Medical; Science; Engineering + Atmos; Service + Botany + Janitor purple (`#391b49`–`#9042a3`); Cargo; Clown | crew character designs, signage, department-tinted machines |
| Sets `19–20` (Antagonists) | void blacks (`#060508`–`#4c4656`); blood crimson (`#3f010d`–`#ff3355`, `#960000`) | antagonist character designs |

Every ramp runs dark to light, and each set header names its tg source or
says TfS. A department primary has five steps and its secondary three;
gold has five; structural metal has eight. File icons keep their own
fixed colors ([art-reference](art-reference/README.md)).

## Departments

The pack declares no department roster; these are identities for art.
tg runs Cargo as its own department under the Quartermaster
(`code/modules/jobs/departments/departments.dm:166`), and this pack
counts it as a Service trade. A department is a primary (uniform body,
sign field, stripe, `CIRCUIT_COLOR_*` machine tint) and a secondary
(collars, cuffs, piping, lettering).

| Department | Primary | Secondary | Its head wears |
| --- | --- | --- | --- |
| Command | command blue | gold | Captain: command blue + gold |
| Security | navy | ice white | Head of Security: navy + gold |
| Medical | medical blue | sterile white (`#f2f4f7`) | Chief Medical Officer: medical blue + gold |
| Science | research violet | orchid | Research Director: violet + gold |
| Engineering | hi-vis yellow | safety orange | Chief Engineer: yellow + gold |
| Service | leaf green | linen | Head of Personnel: green + gold |
| Cargo (Service) | russet | khaki | Quartermaster: russet + gold |
| CentCom (roleplay) | military green | gold | all CentCom staff |

A trade keeps its department's primary and swaps the secondary: Botany
is leaf green with apron blue, Janitorial adds janitor purple, and
Atmospherics is hi-vis yellow with atmos teal. Cargo is the one trade
with its own primary. The clown is a motley of pink and coral that
borrows engineering yellow.

Leadership swaps its secondary for gold. Gold is trim, insignia and rank
marks, never a field, and stays 20 ΔE2000 from the field's steps 2–4
(on engineering yellow use gold 1; on cargo russet use gold 4–5). Each
department's secondary stays at least 12 ΔE2000 from gold 2–4, and no
other department color is amber (hue 30–45° at `>=50%` saturation).
Captain, HoS and CMO part by value (navy dark, command blue mid, medical
blue light, 16–39 ΔE2000 apart); HoP leaf green and CentCom forest green
part by hue (21 ΔE2000).

## What antagonists reserve

The reservation covers character designs (mobs, uniforms, suits, armor):

- **Black**: Antagonists build on black from set 19 (`void-1`..`5`). Crew
  designs keep black to outlines and small accents (boots, gloves, belts)
  from sets 1–5, never the main field; sets 9–18 hold no color with max
  channel below `0x20`.
- **Black with red**: The antagonist signature (syndicate MOD lays
  crimson over near-black). No crew design pairs a black field with red.
- **Brightest reds**: Hue 345–10°, saturation `>=70%`, value `>=76%`.
  Crew paint stays out of that band and `>=10` ΔE2000 from set 20's
  reserved reds; the clown's red is coral. Objects keep every black and
  red (extinguisher cabinets supply set 7's fire red).

## Where TfS diverges from tg

| tg at the pinned revision | Tales from Space |
| --- | --- |
| Security red (`COLOR_SECURITY_RED` `#cb0000`, `rsecurity`) | navy + ice white (`officerblueclothes`, `blueshift`) |
| Captain in navy-violet `#3d4379`, matched by HoP (88fb9423904) | Captain in command blue `#1b67a5`; HoP in leaf green + gold; navy is Security's |
| Gold on command radio `#fcdf03`, captain trim, magnate MOD | gold identity paint is leadership's alone |
| CentCom green uniforms, blue ID trim (`COLOR_CENTCOM_BLUE`) | military green + gold throughout |
| Engineering amber `#ffa62b`, ochre airlock `#a28226` | hi-vis yellow + safety orange |
| Cargo khaki `#b7793d`, beside gold | khaki drab, clear of gold |
| Roboticist in black with dark red (`rnd.dmi` `robotics`) | no crew design pairs black with red |
| Clown in pure `#ff0000` | coral |

Baked tg sprites keep tg's pixels until redrawn or recolored (`Tinted`
recipe or new source under `assets/originals/art/` registered in an
`assets/sprites/*.ron` roster). Bake from the engine checkout
(`README.md` §Running).
