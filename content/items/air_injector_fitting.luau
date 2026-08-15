-- An air injector, in your hands.
--
-- tg draws every `/obj/item/pipe` from its machine's own
-- `pipe_state` in `pipe_item.dmi` (construction.dm:17,216) --
-- `"injector"` here (components/unary_devices/outlet_injector.dm:11).
return {
    id = "air_injector_fitting",
    name = "air injector fitting",
    sprite = "air_injector_loose",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
}
