-- The mirrored gas mixer, as a fitting. tg's flipped mixer subtype
-- (mixer.dm:212-214) reached through the same flippable item.
--
-- Same picture, different machine: flipping moves which intake is
-- which, not what the thing looks like in a hand. See
-- items/gas_filter_fitting.luau for why the pair are two items.
return {
    id = "gas_mixer_flipped_fitting",
    name = "flipped gas mixer fitting",
    sprite = "mixer_fitting",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
}
