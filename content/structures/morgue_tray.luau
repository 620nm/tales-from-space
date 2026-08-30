-- The slab a morgue drawer slides out. Half of `morgue.luau` rather
-- than a thing of its own: the engine mints one with every drawer that
-- names it and never offers it to the map editor's palette, because a
-- tray standing on its own would be an obstacle with nothing behind it.
--
-- Dense and bolted down, as tg's is (code/game/objects/structures/
-- morgue.dm:532-548, the tray parent); its picture comes off the same
-- general structures sheet the drawer's does (:608-621).
return {
    id = "morgue_tray",
    name = "morgue tray",
    sprite = "morguet",
    dense = true,
    opaque = false,
    examine = {
        flavor = "A cold steel slab on runners. Apply corpse before "
            .. "closing.",
    },
}
