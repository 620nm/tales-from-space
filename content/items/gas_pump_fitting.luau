-- A gas pump, in your hands.
--
-- tg's `/obj/item/pipe/directional` pointed at `.../binary/pump`
-- (pump.dm:19, `construction_type`). The commonest thing an engineer
-- carries out of the pipe dispenser: a distribution loop is mostly
-- pump, and every one of them starts as one of these lying on a floor
-- tile waiting for a wrench.
return {
    id = "gas_pump_fitting",
    name = "gas pump fitting",
    sprite = "gas_pump_loose",
    category = "fittings",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
}
