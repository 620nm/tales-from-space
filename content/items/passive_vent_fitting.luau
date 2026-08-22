-- A passive vent, in your hands.
--
-- tg draws every `/obj/item/pipe` from its machine's own `pipe_state`
-- in `pipe_item.dmi` (construction.dm:17,216) -- `"pvent"` here
-- (components/unary_devices/passive_vent.dm:12).
return {
    id = "passive_vent_fitting",
    name = "passive vent fitting",
    sprite = "passive_vent_loose",
    category = "fittings",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
}
