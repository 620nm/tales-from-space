# Aseprite document layout

How a first-party `.aseprite` under `assets/originals/art/` is built, layer by
layer and tag by tag. [ART.md](../ART.md) owns what the pixels look like; the
engine's `docs/assets/importers.md` owns how the bake reads them.

## Mimic a converted DMI

The engine's `convert-dmi` (`crates/xtask/src/convert.rs`, `push_state`) turns
a tg sheet into one tag per state and direction, and gives each tag ONE layer
with cels on that tag's frames and nowhere else. A drawn original keeps that
shape while splitting a state into parts:

- **A tag is a DMI state.** Name it for the state the prototype asks for
  (`powered_active_ns`, `pumping-e`). A direction or axis is a tag suffix.
  Tags are `Forward`.
- **A layer has cels only on the frames of the tags that show it.** A panel
  exists on the closed tags, a bay on the open tags, a blink on its own
  frames. A part hidden under another part on a frame (a cell under a shut
  panel) has no cel there.
- **One drawing is one image.** A part that does not change across frames is
  ONE cel image linked across those frames (Timeline › Link Cels, or Lua
  `app.range.frames = {...}` then `app.command.LinkCels()`), never a copy
  per frame. Only a part that animates carries a distinct image per frame;
  link its repeats too.
- **One layer, one drawing per direction.** A part drawn differently per axis
  or facing is one layer per direction (`housing_ns`, `housing_ew`), never one
  layer that swaps drawings between tags.
- **Every layer stays visible and uniquely named.** The bake drops hidden
  layers from `Ase`/`AseAnim` and refuses them in `AseLayer`.

## Draw only what the sprite owns

Bake a part into the body only if no other sprite or system draws it at
runtime. Draw the body bare, leave the seat for each runtime part empty, and
align the seat to where that part lands:

| Runtime part | Who draws it | Body leaves |
| --- | --- | --- |
| Pipe mouths and layer stubs of an atmos device | the engine, per port and network state: `pipe_intact_*` / `pipe_exposed_*` (`assets/sprites/50-pipes-and-cable.ron`) | no pipe, manifold band or stub at any edge |
| A seated power cell | tg `icons/obj/machines/cell_charger.dmi` `cell`/`hcell`/… overlaid at no offset (`code/game/machinery/cell_charger.dm:21`); every cell spans `x=10..21, y=11..20` | an empty bay under that box |
| Cable or channel lamps | `Layer`/`LayerFrames` sprites stacked by the prototype ([utility_outlet_port.md](../../assets/originals/art/subfloor/electrical/utility_outlet_port.md)) | the housing alone |

## Check before handing off

Print each layer's cel frames and image ids. Every layer's frames must be
exactly the union of its tags' frames, and repeated ids must mark the static
parts:

```lua
local s = app.activeSprite
for _, l in ipairs(s.layers) do
  local row = {}
  for f = 1, #s.frames do
    local c = l:cel(f)
    row[#row + 1] = c and tostring(c.image.id) or "-"
  end
  print(l.name, table.concat(row, " "))
end
```

## Worked example

`machines/life_support_power_unit.aseprite`, 22 frames, eight tags per axis:

| Layer | Frames | Images |
| --- | --- | --- |
| `bay_ns` / `bay_ew` | the two `open_*` tags of its axis | 1, linked |
| `housing_ns` / `housing_ew` | every tag of its axis | 1, linked |
| `panel_ns` / `panel_ew` | the six closed tags of its axis | 1, linked |
| `status_led_ns` / `status_led_ew` | every tag of its axis | 1 per LED picture; `open_*` link the closed tags' LEDs |

The body carries no pipe and no cell. The engine underlays the pipe mouths,
and the prototype overlays the cell into the bay. `open_cell` and
`open_empty` differ only in the LED.
