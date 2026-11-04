local wheeled_tub = require("@lib/wheeled_tub")

-- tg's `/obj/structure/mop_bucket` (code/game/objects/structures/janitor.dm:3-16).
-- A dense item (janitor.dm:8): walkers bump and shove it, a pull rolls it and no
-- hand lifts it, while its vessel, reach and fill picture stay item mechanisms
-- (docs/janitorial/trolley.md). tg's capacity keeps its ratio to the mop's
-- head: 100 tg units at 250/15 mL.
local content = {
    id = "mop_bucket",
    visual_layer = "low_object",
    dense = true,
    motion_response = {
        mass = 20.0,
        restitution = 0.1,
        friction = 0.8,
        half_extent = 0.35,
        public_contacts = true,
    },
    name_label = "lunatic/tfs:entity.mop_bucket.name",
    name = "mop bucket",
    sprite = "mop_bucket",
    examine = { flavor = "Fill it with water, but don't forget a mop!" },
    volume_ml = 1667,
    fill_sprites = { { 1, "mop_bucket_water" } },
    gestures = { "secondary" },
}

-- The cart's dump (janitor.dm:257): tg's mop bucket empties through the mop it
-- wets, and a mop here fills from the deck, so a crowbar is the way out.
local spec: wheeled_tub.Spec = { id = content.id, noun = "mop bucket", dump_seconds = 5 }
content.actions = wheeled_tub.actions(spec)

if sim ~= nil then
    wheeled_tub.attach(spec)
end

return content
