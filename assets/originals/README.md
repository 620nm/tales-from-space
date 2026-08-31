# Originals — art the baker reads from this tree

A sprite roster in `../sprites/` names these files by a path **relative
to this directory** — forward slashes, and never `..`, which the baker
refuses. Two kinds of file live here: drawings made for this game, and
tgstation sheets converted into the same Aseprite format so they can be
edited without a `.dmi`.

## What the baker accepts

- **`.png`** — exactly one 32×32 still. No sheet, no strip, no frames.
  Anything else fails the bake, naming the file and the logical sprite.
- **`.ase` / `.aseprite`** — a 32×32 canvas from Aseprite, LibreSprite,
  Pixelorama, or anything else that writes the format. The document's
  **tags** are its states: a recipe names one, and an untagged file
  cannot be referenced at all. Tag names must be unique within a file —
  a recipe has no way to say which of two same-named tags it meant.

Visible layers are flattened per frame using the document's own blend
modes and opacity, so layered working files are fine; hidden layers are
dropped and never reach the atlas. Only forward-playing tags bake —
reverse and ping-pong are an error rather than a silent expansion into
twice the atlas cells.

A tag's frame durations come from the document, in milliseconds, and a
tag that repeats exactly once plays once and holds instead of looping.

## After editing anything here

```sh
cargo run -p xtask -- bake-atlas --tg <tgstation checkout>
```

The atlas is a checked-in build product, and these files are recorded in
its provenance: editing a pixel changes the record, and the gate notices
a bake that never happened.

## The files

- `soap.png`, `soap.aseprite` — a bar of soap. The same drawing in both
  formats, which is the point: it is what proves a PNG still, an
  Aseprite still, and an Aseprite animation all bake into one atlas
  beside the tgstation-derived sprites. The `.aseprite` carries `idle`
  (the bar alone) and `bubbles` (three frames, bubbles drifting up).
  Written by hand, pixel by pixel, not converted from anything.
- `bench/evaporator_{off,off_loaded,on,on_loaded}.png`,
  `bench/steam_generator_{off,off_loaded,on,on_loaded}.png` — the two
  line-dock machines, four stills each: a squat boxed chassis with a
  vessel slot on its left and a control face on its right, the beaker
  silhouette that appears in the slot when one is docked, the element
  glowing and the lamp lit when it is running, and — on the steam
  machine, which also wears a vent grille along its top — wisps rising
  off it while it works. Four names rather than one interpolated icon
  state because the atlas has none: the engine picks between them from
  `(loaded, running)` in one place, so a slot and a picture cannot
  disagree.

  **Generated rather than drawn by hand**, by a throwaway Python script
  that writes the PNGs a pixel at a time (this box has no Pillow and no
  ImageMagick); the script is not in the tree, because the artefact is
  the art. First-party all the same — nothing here is traced from or
  converted out of another game's sprites. They are STILLS on purpose:
  the running loop wants an `.aseprite` with a tag on it, which is an
  authoring tool an agent cannot drive, and swapping one in later is a
  changed row in `../sprites/95-originals.ron` and nothing else.

- `fx/wind_streak.png` — one soft white horizontal streak on a clear
  field, fading to nothing at both ends. The gas overlay lays it over a
  tile whose air is moving, turned to point down the wind and sliding
  along it; the fade at the ends is what hides the seam where the slide
  wraps. Untinted white on purpose: it is multiplied by whatever colour
  the gas under it already is. Effects sort under `fx/`; the logical
  name it bakes to is flat (`wind_streak`), because a baked name also
  becomes a vending CSS class.
- `turf/open_floor.aseprite` — a steel maintenance grate on a clear
  field: a two-pixel frame with plated corners, six one-pixel bars each
  way, and every cell between them open. One visible layer, `grate`, and
  one forward `open_floor` tag on its single frame. The client lays it
  over plating and the subfloor runs a player has uncovered, so the open
  cells are functional rather than decorative: what lies beneath shows
  through them, and the lattice is registered so the tile's centre band
  (rows and columns 14 through 17, where a straight cable or pipe run is
  drawn) is one clear cell rather than a bar.

  **Derived from a first-party concept picture** — a 1254-pixel render
  that is not integer-pitch pixel art — by a throwaway Python script,
  not in the tree for the same reason as the bench PNGs. The script maps
  each destination row and column onto the concept's measured frame,
  bar, and hole intervals, takes a pixel as opaque when the concept
  covers at least half of its cell, colours it from the lit pixels of
  that cell (the concept's dark outline has no room on a one-pixel bar),
  and quantises the result to an eight-colour palette of cool steel
  greys, `(72,74,79)` to `(132,135,140)`, so it reads as pixel art beside
  the tgstation-derived sprites. The concept's lattice is seven bars by
  six with a bar through its vertical midline; the script drops that
  centre bar and squares the count to six by six, which is what keeps
  the centre open.
- `pipes_n_cables/*.aseprite` — the pipe bitmask, cable, stub and
  wall-outlet sheets, converted from tgstation's matching `.dmi` files
  by `cargo run -p xtask -- convert-dmi`. Tags are `{state}-s` (and
  `-n`/`-e`/`-w` on the outlet). The pixels are tg's; the format is
  this engine's. Re-convert from the revision `../tg-revision` pins
  rather than tracing over them. The source sheets are CC-BY-SA 3.0.

  Each file names one sheet under tg's `icons/obj/pipes_n_cables/`, and
  four of the five convert whole:

  ```sh
  cargo run -p xtask -- convert-dmi <tg>/icons/obj/pipes_n_cables/\!pipes_bitmask.dmi           pipes_bitmask.aseprite
  cargo run -p xtask -- convert-dmi <tg>/icons/obj/pipes_n_cables/layer_cable.dmi               layer_cable.aseprite
  cargo run -p xtask -- convert-dmi <tg>/icons/obj/pipes_n_cables/layer_manifold_underlays.dmi  layer_manifold_underlays.aseprite
  cargo run -p xtask -- convert-dmi <tg>/icons/obj/pipes_n_cables/pipe_underlays.dmi            pipe_underlays.aseprite
  cargo run -p xtask -- convert-dmi <tg>/icons/obj/pipes_n_cables/structures.dmi                outlet.aseprite term
  ```

  `outlet.aseprite` is the filtered one: `structures.dmi` carries the
  whole family of pipe structures, and the trailing `term` argument
  takes that state alone, so the file holds the wall outlet and nothing
  else. Converting the sheet whole would vendor art no roster names.
