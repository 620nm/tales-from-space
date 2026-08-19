-- Reinforced glass: the same pane with rods run through it. Set into a
-- grille it makes a window that takes real work to get back out --
-- unscrewed before it can be pried, which is the whole point of putting
-- it between you and whatever is on the other side.
--
-- Fusing a sheet of glass to a rod by hand is tg's recipe and is not
-- expressible yet: it is item-on-item, and every step this engine
-- understands targets a TILE. Until that seam exists, reinforced glass
-- is stocked, not made.
return {
    id = "rglass",
    name = "reinforced glass sheets",
    sprite = "rglass",
    inhand_sprite = { "held_rglass_l", "held_rglass_r" },
    -- Rods in it or not, it is still a pane. tg glass.dm:112-113.
    pickup_sound = "glass_pickup",
    drop_sound = "glass_drop",
    stack = 50,
}
