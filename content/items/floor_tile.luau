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
}
