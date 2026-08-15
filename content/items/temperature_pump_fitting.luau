-- A temperature pump, in your hands.
--
-- tg draws every `/obj/item/pipe` from its machine's own
-- `pipe_state` in `pipe_item.dmi` (construction.dm:17,216) --
-- `"tpump"` here (components/binary_devices/temperature_pump.dm:8).
return {
    id = "temperature_pump_fitting",
    name = "temperature pump fitting",
    sprite = "temperature_pump_loose",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
}
