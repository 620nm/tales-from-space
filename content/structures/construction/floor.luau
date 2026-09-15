-- Tiles are a removable cover over the retained station base.
-- Refund: code/game/turfs/open/floor.dm:18,144-176.
return {
    id = "floor",
    visual_layer = "cover",
    name_label = "lunatic/tfs:entity.floor.name",
    name = "floor",
    sprite = "floor",
    turf = "component:floor_tiles",
    transitions = {
        {
            sound = "crowbar",
            tool = "crowbar",
            into = "remove_component",
            yields = { floor_tile = 1 },
            done = "You pry up the floor tile.",
        },
    },
    examine = {
        flavor = "Standard station tiling, laid over the deck plating.",
    },
}
