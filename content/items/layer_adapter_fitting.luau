-- A layer adapter, in your hands.
--
-- tg draws every `/obj/item/pipe` from its machine's own
-- `pipe_state` in `pipe_item.dmi` (construction.dm:17,216) --
-- `"manifoldlayer"` here (pipes/layermanifold.dm:13).
return {
    id = "layer_adapter_fitting",
    name = "layer adapter fitting",
    sprite = "layer_adapter_loose",
    category = "fittings",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
}
