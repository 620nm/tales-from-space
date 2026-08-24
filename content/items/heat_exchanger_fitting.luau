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
