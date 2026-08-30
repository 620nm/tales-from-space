# Originals — art drawn for this game

Everything here is first-party: sprites made for Tales from Space rather
than ported from tgstation. A sprite roster in `../sprites/` names these
files by a path **relative to this directory** — forward slashes, and
never `..`, which the baker refuses.

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
- `fx/wind_streak.png` — one soft white horizontal streak on a clear
  field, fading to nothing at both ends. The gas overlay lays it over a
  tile whose air is moving, turned to point down the wind and sliding
  along it; the fade at the ends is what hides the seam where the slide
  wraps. Untinted white on purpose: it is multiplied by whatever colour
  the gas under it already is. Effects sort under `fx/`; the logical
  name it bakes to is flat (`wind_streak`), because a baked name also
  becomes a vending CSS class.
- `turf/open_floor.aseprite` — a transparent steel maintenance grid with
  one forward `open_floor` tag. The client lays it over plating and visible
  subfloor runs, so the clear cells are functional rather than decorative.
