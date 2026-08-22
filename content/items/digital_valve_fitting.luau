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
}
