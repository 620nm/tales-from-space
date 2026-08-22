-- A heat exchanger, in your hands.
--
-- tg draws every `/obj/item/pipe` from its machine's own
-- `pipe_state` in `pipe_item.dmi` (construction.dm:17,216) --
-- `"heunary"` here (components/unary_devices/heat_exchanger.dm:16).
return {
    id = "heat_exchanger_fitting",
    name = "heat exchanger fitting",
    sprite = "heat_exchanger_loose",
    category = "fittings",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
}
