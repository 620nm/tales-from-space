-- A temperature gate, in your hands.
--
-- tg draws every `/obj/item/pipe` from its machine's own
-- `pipe_state` in `pipe_item.dmi` (construction.dm:17,216) --
-- `"tgate"` here (components/binary_devices/temperature_gate.dm:8).
return {
    id = "temperature_gate_fitting",
    name = "temperature gate fitting",
    sprite = "temperature_gate_loose",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
}
