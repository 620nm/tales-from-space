local physical_profiles = require("@lib/physical_profiles")
-- What prying up a reinforced plasma glass floor returns: tg
-- /obj/item/stack/tile/rglass/plasma (code/game/objects/items/stacks/tiles/
-- tile_types.dm:1807-1814), art tiles.dmi `tile_rpglass`; it sets no held
-- art of its own, so it wears reinforced glass tile's `tile-rglass` (:1790).
-- Stack size and scatter follow floor_tile.luau.
return {
    id = "reinforced_plasma_glass_tile",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.reinforced_plasma_glass_tile.name",
    name = "reinforced plasma glass floor tiles",
    sprite = "reinforced_plasma_glass_tile",
    inhand_sprite = { "held_reinforced_glass_tile_l", "held_reinforced_glass_tile_r" },
    stack = 60, -- tile_types.dm:19, as floor_tile
    scatter = 3,
}
