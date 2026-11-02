# Art reference

Reference material behind [ART.md](../ART.md), which owns the art direction,
palette rules, animation timing and LED restraint policy. Nothing here ships.

## Reference organization and Aseprite setup

- `palettes/tales-from-space.gpl` is the unified GIMP/Aseprite palette
  ([ART.md](../ART.md) §Palette): 20 named sets and 155 unique colours
  covering station metals, copper/brass, dark rubber, panel glass, wood,
  ceramic beige, safety paint, signals/emissives, leadership gold,
  department primaries/secondaries, and antagonist reservations.
  - **Loading in Aseprite**: Symlink or copy `tales-from-space.gpl` into
    `~/.config/aseprite/palettes/tales-from-space.gpl` and load it from the
    Palette panel (`Presets` dropdown or `Palette Options > Load Palette`).
    Do not use `File > Open` (which treats `.gpl` as a sprite document) or
    drop bare `.gpl` files into `/usr/share/aseprite/data/extensions/`
    without a `package.json` entry.
  - **Swatch naming**: Aseprite's C++ `.gpl` loader reads swatch names with
    whitespace-delimited `operator>>`, so every swatch name is a single
    hyphenated token (`structure-1-outline`, `eng-yellow-3`).
- [elemental-asset-guide.md](elemental-asset-guide.md) holds the ground, water,
  air and fire art rules, importer arms and tile-connectivity mechanisms;
  [elemental-source-inventory.md](elemental-source-inventory.md) lists the
  tgstation art per element and what the pack imports. The tools that author
  and audit the elemental sprites are in
  [tools/art/elemental/](../../tools/art/elemental/README.md).
- [terrestrial-asset-guide.md](terrestrial-asset-guide.md) holds the
  neutral-greyscale planetary terrain, 12-frame 4-layer shoreline, broadband
  botanical decal and matte outcrop rules; the tools that author, render and
  audit them are in
  [tools/art/terrestrial/](../../tools/art/terrestrial/README.md).
- `palettes/file-icons/` holds the file-icon importer's fixed palette strips.
- `plates/01-medical.png` .. `09-information.png` are composite visual
  reference plates rendered from the pinned `tgstation` checkout
  (`3c5ff70be69`).
- `fonts/BoldsPixels.ttf` is a byte-for-byte copy of the supplied font;
  `examples/` holds the font chart, rasterized glyphs, and inspected TG
  stamp/sign examples.
- `file-icons/prompts.json`, `file-icons/machine-source.json`, and
  `file-icons/provenance.json` record file-icon prompts, composed context,
  and SHA-256 provenance.

## Visual reference plates (`plates/`)

| Plate | Focus and canonical examples |
| --- | --- |
| `01-medical.png` | Patient-scale forms: `medical_bed`, `surgery_table`, 2025 `sleeper`, 32×64 `cryogenics` pod, `dispenser`, `chemmaster`, `medicart`, and 2026 `vitals_monitor`. |
| `02-engineering.png` | Modern 2024–2026 mechanisms shaping the housing: 2025 `sheater-off` radiator, 2026 `bluespace_scrubber` and `bluespace_gas_receiver`, 2026 `portgen3_0` (`P.L.A.N.K.M.A.N.`), 2024 `port_smes`, 2024 `portagrav`, 2026 HFR `core`, and 2024 64×32 `h_lathe`. |
| `03-states.png` | State hierarchy: static housing invariant across `sheater-off` / `sheater-heat` / `sheater-cool` / `sheater-open`, localized work on `bluespace_scrubber_1` and `portgen3_1`, and silhouette changes on `emerg_folded` and `sleeper-open`. |
| `04-computers.png` | Shared console shells (`computer.dmi`), single dominant screen motifs (2026 `accounts` and `supply`, `crew`, `power`), 4 bespoke redrawn facings (`NORTH`/`EAST`/`WEST`), and outline-free 2025 `turret_control`. |
| `05-telecomms.png` | **The LED & animation anti-pattern (`telecomms.dmi`)**: box and dish silhouettes are structurally fine, but 7 of 8 machines blink `7–121 px` at `75–100 ms` across `6–16` frames while completely idle. Contrast with `broadcaster` (`1f` static idle, `6f` `broadcaster_send` on transmit). |
| `06-furniture.png` | Calm room surfaces: `table-0` (`75%` top plane), `glass_table-0`, 32×48 `med` and `eng` lockers, 2026 `medicalcrate`, 2024 `coffeemaker`, ceramic-beige `mw_complete`, and `autolathe`. |
| `07-palette.png` | All 20 sets (155 colours) of `tales-from-space.gpl` plus the pixel-budget breakdown of `sheater-off` (502 opaque pixels, 7 colours, 1 `#b91411` power LED pixel). |
| `08-context.png` | Contact test at 3× on `floors.dmi` (`white` and `floor`): medical and 2024–2026 engineering rows read clearly by silhouette and value, whereas a telecomms row drowns in blinking cyan/amber noise. |
| `09-information.png` | Informative displays: 2026 `vitals_monitor.dmi` (dark when idle; every lit region maps to a limb or vital) and 2025 `wall_healer.dmi` (4 substance bars drop as stock is spent). |

## Spatial, paper-doll and timing reference

World items (`icons/obj/`) are drawn larger and centered on the 32×32 canvas;
worn clothing (`icons/mob/clothing/`) and held items (`icons/mob/inhands/`)
are separate sprites locked to the human paper-doll:

| Asset class | Typical bbox (`x`, `y`) | Span (`W×H`) | Alignment rule |
| --- | --- | --- | --- |
| World item (`icons/obj/`) | `x=7..24, y=7..24` | `14–22 px` | Centered on tile; oblique top + front lip; step-1 outline |
| Worn head (`clothing/head/`) | `x=10..21, y=2..11` | `12×10 px` | Fits human head (`y=2..10`); `4` dirs |
| Worn mask/eyes (`masks/`, `eyes/`) | `x=11..20, y=5..11` | `10×6 px` | Aligns to eye/mouth row (`y=6..10`); `4` dirs |
| Worn uniform/suit (`under/`, `suits/`) | `x=8..23, y=9..27` | `16×19 px` | Torso (`x=10..21, y=9..20`), arms (`x=8..9, 22..23`), legs (`y=20..27`) |
| Worn gloves/hands (`gloves/`) | `x=8..23, y=15..21` | `16×7 px` | Split left/right hand clusters (`x=8..10` and `x=21..23`) |
| Worn belt/back (`belt/`, `back/`) | `x=9..22, y=10..21` | `13×9 px` | Belt waist strip (`y=18..21`); backpack (`x=10..21, y=10..21`) |
| Worn shoes (`feet/`) | `x=10..21, y=26..30` | `12×5 px` | Split left/right feet at bottom of mob (`y=26..30`) |
| Inhands (`inhands/*_lefthand`, `_righthand`) | `x=13..24` (L) / `x=7..19` (R), `y=11..22` | `10×10 px` | Drawn in Separate `lefthand` and `righthand` sheets across `4` dirs |

| Animation pattern | Frame count | Timing (`1 ds = 100 ms`) | Rule |
| --- | --- | --- | --- |
| Default idle / standby (`off`, `standby`, `broadcaster`) | `1` frame | Static (`--`) | Default state when no work is occurring; `1–4 px` static status LED |
| Localized active work (`sheater-heat`, `bluespace_scrubber_1`) | `2–4` frames | `100–200 ms` (`1–2 ds`) | `0` housing pixels move; `12–75 px` (`2–15%`) animate inside working bay |
| One-shot mechanical transition (`opening`, `closing`, `broadcaster_send`) | `4–6` frames | `100 ms` (`600 ms` total) | Plays once on state change, then settles into a `1`-frame state |
| Periodic ambient glint (`vend`, crystals, idle screens) | `4–8` frames | `[100 ms × N, 3000–5000 ms × 1]` | Short sweep followed by a `3–5 s` static hold |
| Phase-matched machine cycle (`startup → active → shutdown`) | `3–6` frames/phase | `100–200 ms` | Separate entry/exit tags from the steady work loop |

## File sprite recipe

The file family uses native 32×32 RGBA PNGs from
`assets/originals/art/computer/files/`. Production manifests assign the verified
sprite keys `file_disl`, `file_md`, `file_atmo`, and `file_pem`. PNGs carry their
lettering; the browser keeps its ordinary UI typography and receives no font.

Use a transparent 32×32 canvas with a 26×32 page centered at x=3, y=0.
Keep its stepped fold, square corners, dark outline and pale paper rim.
The fixed outline is `#202c2d`; paper and marks are `#f1ead4`.
Labels are blue `#426b9a` (DiSL), yellow `#bd9a31` (Markdown),
teal `#36877f` (ATMO), and violet `#795891` (PEM). The pressure gauge
also uses `#205458`. Alpha is binary. No smoothing or intermediate shades.

DiSL uses two left-aligned rows, `Di` and `SL`; Markdown uses `MD` above its
text rule. BoldsPixels is rasterized at 16 pixels, 72 dpi, without antialiasing.
The gauge and key remain pictograms. Each file is recognizable without color.
The runtime PNGs preserve the approved colors, outline and baked lettering.
The PEM icon labels ordinary editable access material and grants no authority.

## Reproduction

From the pack root, with Node and ImageMagick 7 installed:

```sh
node assets/originals/art/computer/files/import.mjs
```

The importer reads generated inputs from `assets/sources/computer/files/` and
fixed palettes from `docs/art-reference/palettes/file-icons/`, removes
the magenta key, samples with nearest-neighbor filtering, and centers the page.
`lettering.mjs` replaces only the DiSL/Markdown letter fields with the supplied
font and checks that pixels outside those fields are unchanged. The importer
then exports the exact palette and 32 indexed pixel rows beside each PNG.
Bake with `cargo run -p xtask -- bake-atlas` from the engine checkout,
with `LUNATIC_PACK` pointing to this pack and `LUNATIC_TG` to its pinned reference.

## Provenance

The approved file-icon input directory is `/tmp/tfs-terminal-frameset-NcP2SU/sprites/`.
Its four final PNGs are imported unchanged; generated inputs are retained under
`assets/sources/computer/files/`. The font source is `/home/josh/Downloads/BoldsPixels.ttf`.
File-icon TG reference citations (`icons/stamp_icons/font.png`,
`icons/stamp_icons/large_stamp-ce.png`, `icons/obj/signs.dmi`) were sampled at
`7cb126ac8864a0d0952c48d25375a5bebaef512b` and remain identical at the current
pinned revision `3c5ff70be69a66492cc95290b8161909c67ede98`. The machine the
file icons were drawn beside is `programming_terminal` (`computer`, `rd_key`,
and `rdcomp` in `icons/obj/machines/computer.dmi`).
