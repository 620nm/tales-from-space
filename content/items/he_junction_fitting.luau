-- A junction, in your hands.
--
-- tg draws every `/obj/item/pipe` from its machine's own `pipe_state`
-- in `pipe_item.dmi` (construction.dm:17,216) -- `"junction"` here
-- (heat_exchange/junction.dm:16).
return {
    id = "he_junction_fitting",
    name = "junction fitting",
    sprite = "he_junction_loose",
    category = "fittings",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
    -- The main this one will stand on, 1..=5: the engine's dial, set by
    -- the dispenser before it hands the part over (tg's
    -- `set_piping_layer` off the RPD, RPD.dm:569). Starts on the
    -- distribution run, PIPING_LAYER_DEFAULT.
    modes = 5,
    mode = 2,
}
