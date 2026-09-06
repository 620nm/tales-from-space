# Utility Outlet Port artwork

`utility_outlet_port.aseprite` is the editable
32×32 RGBA source, drawn in Aseprite through its WebSocket API. The gray
housing occupies a centered 20×14 footprint with two circular recessed ports.
Three two-pixel LEDs sit along the lower side, wire layers 1–2–3 left to right.

| Frame / tag | LEDs |
| --- | --- |
| 1 / `disconnected` | Unlit gray `#363c3e` |
| 2 / `inactive` | Dull blue `#4b617c`, red `#79504f`, yellow `#7b7047` |
| 3 / `starved` | Red `#c46d66`: connected and powered, receiving no power |
| 4 / `emergency` | Yellow `#c2a45e`: connected and powered, APC emergency |
| 5 / `nominal` | Green `#77a67a`: connected and powered nominally |
| 6 / `mixed` | Example: layer 1 inactive, 2 emergency, 3 nominal |

The `housing` layer is identical in every frame. `wire_1`, `wire_2`, and
`wire_3` contain only their LED pixels; select their states independently.
The engine's existing `AseLayer(file, layer, frame)` recipe can bake the
housing once and each LED state separately.

Style references: the pack's Air Vent and Air Scrubber source states
`vent_off` and `scrub_off` in tgstation's
`icons/obj/machines/atmospherics/unary_devices.dmi`, referenced by
`assets/sprites/21-atmos-thermal-room-and-canisters.ron`.

This asset is not registered in the sprite manifest. UOP gameplay and network
behavior are not implemented.
