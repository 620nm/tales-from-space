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
}
