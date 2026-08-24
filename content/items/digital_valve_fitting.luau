-- A digital valve, in your hands.
--
-- tg's `/obj/item/pipe/binary` pointed at
-- `.../binary/valve/digital` (valve.dm:78). Same fitting family as the
-- manual valve's, a different picture, and a different machine at the
-- far end of the wrench -- which is the whole of the difference between
-- the two in tg as well.
return {
    id = "digital_valve_fitting",
    name = "digital valve fitting",
    sprite = "digital_valve_loose",
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
