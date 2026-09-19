local physical_profiles = require("@lib/physical_profiles")
-- A broken pane: the improvised scalpel (tg glass.dm:307-326). force 5 --
-- under the 10 a saw needs, which is why the floor rescue can open a
-- chest but never saw the ribs (docs/SURGERY.md 6.3). Reuses the glass
-- sheet's picture until a shard sprite is baked.
return {
    id = "shard",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.shard.name",
    name = "shard",
    sprite = "glass",
    force = 5,
    sharp = "edged",
}
