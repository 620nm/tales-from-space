local physical_profiles = require("@lib/physical_profiles")
-- What prying up a reinforced glass floor returns: tg
-- /obj/item/stack/tile/rglass (code/game/objects/items/stacks/tiles/
-- tile_types.dm:1785-1793), art tiles.dmi `tile_rglass`, held art
-- `tile-rglass`. Stack size and scatter follow floor_tile.luau.
return {
    id = "reinforced_glass_tile",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.reinforced_glass_tile.name",
    name = "reinforced glass floor tiles",
    sprite = "reinforced_glass_tile",
    inhand_sprite = { "held_reinforced_glass_tile_l", "held_reinforced_glass_tile_r" },
    stack = 30,
    scatter = 3,
}
