local physical_profiles = require("@lib/physical_profiles")
-- What prying up a glass floor returns: tg /obj/item/stack/tile/glass
-- (code/game/objects/items/stacks/tiles/tile_types.dm:1772-1780), art
-- tiles.dmi `tile_glass`, held art `tile-glass`. Stack size and scatter
-- follow floor_tile.luau. Laying one back down is not ported: tg lays it
-- on plating (plating.dm:73,84) and crafts it from sheets (sheets/glass.dm:15).
return {
    id = "glass_tile",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.glass_tile.name",
    name = "glass floor tiles",
    sprite = "glass_tile",
    inhand_sprite = { "held_glass_tile_l", "held_glass_tile_r" },
    stack = 60, -- tile_types.dm:19, as floor_tile
    scatter = 3,
}
