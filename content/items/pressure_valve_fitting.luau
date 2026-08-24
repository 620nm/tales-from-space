-- A pressure valve, in your hands.
--
-- tg's `/obj/item/pipe/directional` pointed at
-- `.../binary/pressure_valve` (pressure_valve.dm:128), picture from its
-- `pipe_state`, `"pvalve"` (pressure_valve.dm:129).
return {
    id = "pressure_valve_fitting",
    name = "pressure valve fitting",
    sprite = "pressure_valve_loose",
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
