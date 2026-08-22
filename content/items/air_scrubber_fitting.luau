-- An air scrubber, in your hands.
--
-- tg draws every `/obj/item/pipe` from its machine's own
-- `pipe_state` in `pipe_item.dmi` (construction.dm:17,216) --
-- `"scrubber"` here (components/unary_devices/vent_scrubber.dm:17).
return {
    id = "air_scrubber_fitting",
    name = "air scrubber fitting",
    sprite = "air_scrubber_loose",
    category = "fittings",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
}
