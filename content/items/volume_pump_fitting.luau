-- A volumetric gas pump, in your hands.
--
-- tg's `/obj/item/pipe/directional` pointed at `.../binary/volume_pump`
-- (volume_pump.dm:19). The picture is the machine's own `pipe_state`,
-- `"volumepump"` (volume_pump.dm:20).
return {
    id = "volume_pump_fitting",
    name = "volumetric gas pump fitting",
    sprite = "volume_pump_loose",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
}
