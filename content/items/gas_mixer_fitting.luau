-- A gas mixer fitting. tg's `/obj/item/pipe/trinary/flippable`
-- (mixer.dm:9, `construction_type`), drawn from that machine's own
-- `pipe_state` "mixer" in pipe_item.dmi.
--
-- The same round trip every atmospherics device takes: this goes down
-- on a run and a wrench stands the machine up
-- (structures/gas_mixer.luau).
return {
    id = "gas_mixer_fitting",
    name = "gas mixer fitting",
    sprite = "mixer_fitting",
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
