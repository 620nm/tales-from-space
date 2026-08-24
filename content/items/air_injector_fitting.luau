-- An air injector, in your hands.
--
-- tg draws every `/obj/item/pipe` from its machine's own
-- `pipe_state` in `pipe_item.dmi` (construction.dm:17,216) --
-- `"injector"` here (components/unary_devices/outlet_injector.dm:11).
return {
    id = "air_injector_fitting",
    name = "air injector fitting",
    sprite = "air_injector_loose",
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
