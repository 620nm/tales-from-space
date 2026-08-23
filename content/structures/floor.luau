-- The finished deck: plating with a tile lying on it. `plating.luau`
-- is the other half of the trade -- a tile spent there becomes this,
-- and the tile comes back here.
--
-- The refund is `salvage` rather than a transition, because prying a
-- tile up is a NATIVE step: tg's `/turf/open/floor/crowbar_act` gates
-- on `overfloor_placed` and hands straight to `pry_tile` -> `make_plating`
-- (code/game/turfs/open/floor.dm:144-176), instantly and with no
-- do_after to hang a yield on. What comes up is one tile, tg's own
-- `floor_tile_amount` of 1 for a plain floor (floor.dm:18). Until this
-- field existed the engine spelled that id itself, which made what the
-- station is tiled with a fact about the engine.
--
-- No transitions of its own: a crowbar takes the tile off (native), and
-- everything else you can do to a deck you do to the plating under it.
return {
    id = "floor",
    name = "floor",
    sprite = "floor",
    turf = "floor",
    salvage = { item = "floor_tile", count = 1 },
    examine = {
        flavor = "Standard station tiling, laid over the deck plating.",
    },
}
