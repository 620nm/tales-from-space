-- The mirrored gas filter, as a fitting. tg's
-- `/obj/item/pipe/trinary/flippable/filter` with its `flipped` var
-- turned over (construction.dm; the machine is filter.dm:202-204).
--
-- Same picture as the unflipped one, because tg's item art does not
-- distinguish them either: what differs is which side of the flow the
-- filtered outlet ends up on once it is bolted down, and that is a
-- fact about the MACHINE. See items/gas_filter_fitting.luau for why
-- this is a second item rather than a click on the first.
return {
    id = "gas_filter_flipped_fitting",
    name = "flipped gas filter fitting",
    sprite = "filter_fitting",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
}
