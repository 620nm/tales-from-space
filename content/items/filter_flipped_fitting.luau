-- The mirrored filter, as a fitting. tg's
-- `/obj/item/pipe/trinary/flippable/filter` with its `flipped` var
-- turned over (construction.dm; the machine is filter.dm:202-204).
--
-- Same picture as the unflipped one, because tg's item art does not
-- distinguish them either: what differs is which side of the flow the
-- filtered outlet ends up on once it is bolted down, and that is a
-- fact about the MACHINE. See items/filter_fitting.luau for why
-- this is a second item rather than a click on the first.
return {
    id = "filter_flipped_fitting",
    name = "flipped filter fitting",
    sprite = "filter_fitting",
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
