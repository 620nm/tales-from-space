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
    -- The main this one will stand on, 1..=5, and it is the ENGINE's
    -- dial rather than this file's: `modes` mints it, the dispenser
    -- sets it before it hands the part over (tg's `set_piping_layer`
    -- off the RPD, RPD.dm:569), and `attach_pipe_device` reads it when
    -- the machine stands up. Every `/obj/item/pipe` in tg carries one.
    -- Starting on the distribution run, tg's PIPING_LAYER_DEFAULT
    -- (__DEFINES/atmospherics/atmos_piping.dm:80).
    modes = 5,
    mode = 2,
}
