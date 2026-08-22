-- The engine room's deck: plating with two rods wrenched across it
-- (tg's /turf/open/floor/engine, reinforced_floor.dm:2-18). It is not a
-- tiled floor and never becomes one -- there is no tile lying on top to
-- pry, which is why a crowbar does nothing at all to it
-- (reinforced_floor.dm:41-42, an override whose whole body is `return`)
-- and why the only way down is the wrench that put the rods in.
--
-- Thirty deciseconds is tg's own `use_tool(src, user, 30)` at
-- reinforced_floor.dm:47, and the two rods it hands back are its
-- `floor_tile_amount` (`:18`) -- exactly what plating spends to become
-- one, so the trade closes with nothing minted or eaten.
return {
    id = "reinforced_floor",
    name = "reinforced floor",
    sprite = "reinforced_floor",
    turf = "reinforced_floor",
    examine = {
        flavor = "Deck plating with reinforcement rods wrenched firmly in place.",
    },
    transitions = {
        {
            tool = "wrench",
            secs = 3.0,
            into = "turf:plating",
            yields = { rod = 2 },
            start = "You start removing the reinforcement rods.",
            done = "The rods come up, leaving bare plating.",
        },
    },
}
