# Utility Outlet Port artwork

`utility_outlet_port.aseprite` is the editable 32×32 RGBA source, drawn
through the Aseprite MCP. The fitting is a flush circular floor outlet
with a hinged metal lid and a recessed socket. The subdued metal uses
top-left lighting, a limited palette, and no antialiasing or glow.

The floor rim occupies a centered 16×11 footprint at `(8, 14)`. The
closed cover stays within that rim; the open lid extends to `y = 7`,
joined to the rim by its hinge. Both variants retain the same floor
anchor and transparent surroundings. No sprite offset is required.

## Cover and channel layers

| Layer / frame | Picture |
| --- | --- |
| `housing` / 1, tag `closed` | Closed metal cover |
| `housing` / 2, tag `open` | Raised lid and recessed socket |
| `housing` / 3–5 | Closed cover for status previews |

Three two-pixel lamps remain separate on `wire_1`, `wire_2`, and
`wire_3`, left to right at `(11, 23)`, `(15, 23)`, and `(19, 23)`.
Each layer's frames select its channel status independently of the cover:

| Frame / tag | Lamp |
| --- | --- |
| 1 / `disconnected` | Unlit gray `#363c3e` |
| 2 / `inactive` | Dull blue `#4b617c`, red `#79504f`, yellow `#7b7047` |
| 3 / `starved` | Red `#c46d66` |
| 4 / `emergency` | Yellow `#c2a45e` |
| 5 / `nominal` | Green `#77a67a` |

Frames are alternatives for atlas baking, not an animation. Cover tags
and channel tags share frame numbers; a preview's lamp colors do not
couple the cover state to power. Each tag covers exactly one frame.

`assets/sprites/95-originals.ron` registers seventeen `AseLayer` recipes:
`utility_outlet_port` reads `housing` frame 1, and
`utility_outlet_port_open` reads `housing` frame 2. The fifteen
`uop_wire_{1,2,3}_{disconnected,inactive,starved,emergency,nominal}`
recipes read the wire layers' frames 1–5. Runtime composition selects
each channel lamp independently and stacks it over the selected cover.

Style references are the pack's Air Vent and Air Scrubber states
`vent_off` and `scrub_off` in tgstation's
`icons/obj/machines/atmospherics/unary_devices.dmi`, referenced by
`assets/sprites/21-atmos-thermal-room-and-canisters.ron`.

The prototype is `content/structures/power/utility_outlet_port.luau`.
The engine's `docs/content-schema/fixture-states.md` defines channel
status selection.
