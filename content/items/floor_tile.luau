-- Floor tiles. Space knows a tile lays plating over it (and only next
-- to something solid — the station grows outward, never floats);
-- plating knows a tile finishes it into floor. Both statements live
-- with the turfs that make them, in tfs/content/structures/.
return {
    id = "floor_tile",
    name = "floor tiles",
    sprite = "floor_tile",
    inhand_sprite = { "held_floor_tile_l", "held_floor_tile_r" },
    stack = 30,
    -- Tiles arrive crooked. tg jitters every tile stack by +/-3 in its
    -- own `Initialize` (code/game/objects/items/stacks/tiles/
    -- tile_types.dm:35-36) rather than at any of the events that
    -- scatter other things, which is why a crowbarred tile and a
    -- mapper's tile look alike: the jitter is a fact about the type,
    -- not about how it came to be there.
    --
    -- Three 32nds is deliberately small -- under a tenth of a tile.
    -- Enough that a row of pried-up tiles reads as a mess somebody
    -- made, not enough to look like they landed on the wrong turf.
    scatter = 3,
}
