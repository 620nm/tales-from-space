local physical_profiles = require("@lib/physical_profiles")
-- What prying up a plasma glass floor returns: tg
-- /obj/item/stack/tile/glass/plasma (code/game/objects/items/stacks/tiles/
-- tile_types.dm:1798-1805), art tiles.dmi `tile_pglass`; it sets no held
-- art of its own, so it wears glass tile's `tile-glass` (:1778).
-- Stack size and scatter follow floor_tile.luau.
return {
    id = "plasma_glass_tile",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.plasma_glass_tile.name",
    name = "plasma glass floor tiles",
    sprite = "plasma_glass_tile",
    inhand_sprite = { "held_glass_tile_l", "held_glass_tile_r" },
    stack = 30,
    scatter = 3,
}
