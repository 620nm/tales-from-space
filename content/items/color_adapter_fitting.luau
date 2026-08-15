-- A color adapter, in your hands.
--
-- tg draws every `/obj/item/pipe` from its machine's own
-- `pipe_state` in `pipe_item.dmi` (construction.dm:17,216) --
-- `"adapter_center"` here (pipes/color_adapter.dm:17).
return {
    id = "color_adapter_fitting",
    name = "color adapter fitting",
    sprite = "color_adapter_loose",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
}
