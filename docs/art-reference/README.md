# Art reference

The file family uses native 32×32 RGBA PNGs from
`assets/originals/art/computer/files/`. Production manifests assign the verified
sprite keys `file_disl`, `file_md`, `file_atmo`, and `file_pem`. PNGs carry their
lettering; the browser keeps its ordinary UI typography and receives no font.

## Reference organization

- `fonts/BoldsPixels.ttf` is a byte-for-byte copy of the supplied Downloads font;
  the Downloads original stays untouched.
- `palettes/chatgpt.gpl` and `palettes/claude.gpl` are the project's fixed GIMP
  palettes; `palettes/file-icons/` holds the sprite importer's palette strips.
  Reference palettes do not participate in runtime asset delivery.
- `examples/` holds the supplied font chart, rasterized glyphs, and inspected
  TG stamp/sign examples. These are reference images, not runtime sprites.
- `file-icons/prompts.json` preserves artwork prompts;
  `file-icons/machine-source.json` records the composed machine sprite the
  icons were drawn beside.
- `file-icons/provenance.json` records input and runtime SHA-256 identities.
- The rendered look of these sprites in the terminal is checked by the pack's
  UI fixtures (`ui/fixtures/`) through the engine's lab (the engine's
  `docs/pack-ui/lab.md`).

Runtime wallpapers, sounds, sprite PNGs, pixel matrices, generated artwork inputs,
production preparation scripts and Aseprite documents stay under `assets/`.

## File sprite recipe

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
Review each icon at 1× on light and dark backgrounds before accepting changes.

The prepared PNGs are authoritative bake inputs; reproduction requires no image
service. Bake with `cargo run -p xtask -- bake-atlas` from the engine checkout,
with `LUNATIC_PACK` pointing to this pack and `LUNATIC_TG` to its pinned reference.

## Provenance

The approved input directory is `/tmp/tfs-terminal-frameset-NcP2SU/sprites/`.
Its four final PNGs are imported unchanged. Generated artwork inputs are retained
under `assets/sources/computer/files/`; the prompt record captures their origin.
The font source is `/home/josh/Downloads/BoldsPixels.ttf`.
TG reference revision is `7cb126ac8864a0d0952c48d25375a5bebaef512b`:
`icons/stamp_icons/font.png`, `icons/stamp_icons/large_stamp-ce.png`, and
`icons/obj/signs.dmi`. The machine the icons were drawn beside is the existing
composed `programming_terminal` sprite, from states `computer`, `rd_key`, and
`rdcomp` in `icons/obj/machines/computer.dmi`. Production titles resolve the
owner's sprite.

These notes describe sources and preparation, without changing licensing
or attribution declarations.
