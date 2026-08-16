-- An air vent, in your hands.
--
-- tg draws every `/obj/item/pipe` from its machine's own `pipe_state`
-- in `pipe_item.dmi` (construction.dm:17,216) -- `"uvent"` here
-- (components/unary_devices/vent_pump.dm:16), and names the loose form
-- "air vent fitting" (construction.dm:53).
return {
    id = "vent_fitting",
    name = "air vent fitting",
    sprite = "vent_loose",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
}
