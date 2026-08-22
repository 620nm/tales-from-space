-- A gas filter fitting: the machine before anyone has bolted it down.
--
-- tg's `/obj/item/pipe/trinary/flippable/filter`
-- (code/game/machinery/pipe/construction.dm, the PIPE_TRIN_M family).
-- Every atmospherics device in the game arrives this way and none of
-- them is a special case: you drop the fitting on the run and wrench
-- it, and `/obj/item/pipe/wrench_act` deletes the item and stands the
-- machine up in its place (construction.dm:268-312). Taking one apart
-- runs the trade backwards -- see structures/gas_filter.luau, where the
-- expert on what a wrench does to a filter lives.
--
-- The picture is tg's own `pipe_state` for this machine, "filter" in
-- pipe_item.dmi (construction.dm:212): the device drawn with no pipe
-- joined to it, which is exactly what one in your hands is.
--
-- There is a SECOND fitting for the mirrored machine
-- (gas_filter_flipped_fitting). tg does the same thing --
-- `/obj/item/pipe/trinary/flippable` carries a `flipped` var its
-- `attack_self` turns over -- and the two are one item there only
-- because a click in hand can flip it. Alt+click rotation turns the
-- whole fitting but does not exchange its inlet and outlet, so the two
-- recipes still represent the honest two layouts.
return {
    id = "gas_filter_fitting",
    name = "gas filter fitting",
    sprite = "filter_fitting",
    category = "fittings",
    -- tg's `inhand_icon_state = "buildpipe"` for the whole
    -- /obj/item/pipe family (construction.dm:19).
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
}
