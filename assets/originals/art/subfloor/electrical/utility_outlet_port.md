# Utility Outlet Port artwork

`utility_outlet_port.aseprite` is the editable 32×32 RGBA source, drawn
through the Aseprite MCP. The fitting is a flush rounded-square floor plate
with a round removable cap over a recessed socket, drawn straight from
above with no perspective, side wall or cast shadow.

The plate is a 16×16 footprint at `(8, 8)`. Opening it removes only the
12×12 cap at `(10, 10)`, so the silhouette never changes. Both pictures
keep the same floor anchor and transparent surroundings; no sprite offset
is required.

## Layers and frames

Layers, bottom to top: `housing`, `led_l1`, `led_l2`, `led_l3`, `cover`.
Every layer stays visible, because the bake refuses a hidden one. Frames are
alternatives for atlas baking, not an animation, and each tag covers one
frame:

| Frame / tag | `housing` | `led_l*` | `cover` |
| --- | --- | --- | --- |
| 1 / `disconnected` | Open socket | Blank | empty |
| 2 / `connected` | Open socket | Dull cable color | empty |
| 3 / `active` | Open socket | Bright cable color | empty |
| 4 / `closed` | Open socket | empty | Closed cap, whole plate |

## LEDs

One 2×1 LED per cable layer on row 13, each on its own layer and in its
cable's color. Together the layers give the nine LED pictures:

| Layer | Cable | Pixels | `disconnected` | `connected` | `active` |
| --- | --- | --- | --- | --- | --- |
| `led_l1` | Red | `(12, 13)` `(13, 13)` | `#2b2b2b` | `#c61326` | `#ff441b` |
| `led_l2` | Yellow | `(15, 13)` `(16, 13)` | `#2b2b2b` | `#d9c21a` | `#ffff33` |
| `led_l3` | Blue | `(18, 13)` `(19, 13)` | `#2b2b2b` | `#2667d1` | `#65b4ff` |

The prototype folds the engine's five channel states into these three
pictures: `disconnected` is itself, `inactive` and `starved` are `connected`,
and `emergency` and `nominal` are `active`. `channels_in_states = { "open" }`
draws the LEDs only while the cap is off, so the closed plate shows none of
them.

## Atlas

`assets/sprites/95-originals.ron` bakes one layer per sprite:
`utility_outlet_port` reads `cover` frame 4, `utility_outlet_port_open` reads
`housing` frame 1, and the nine `uop_led_{l1,l2,l3}_{disconnected,connected,active}`
sprites read each `led_l*` layer's frames 1–3. Runtime composition selects
each channel's LED independently and stacks it over the open housing.

The prototype is `content/structures/power/utility_outlet_port.luau`. The
engine's `docs/content-schema/fixture-states.md` defines channel selection.
