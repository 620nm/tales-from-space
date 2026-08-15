-- A pressure valve, in your hands.
--
-- tg's `/obj/item/pipe/directional` pointed at
-- `.../binary/pressure_valve` (pressure_valve.dm:128), picture from its
-- `pipe_state`, `"pvalve"` (pressure_valve.dm:129).
return {
    id = "pressure_valve_fitting",
    name = "pressure valve fitting",
    sprite = "pressure_valve_loose",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
}
