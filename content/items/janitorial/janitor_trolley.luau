local wheeled_tub = require("@lib/wheeled_tub")

-- tg's `/obj/structure/mop_bucket/janitorialcart` (janitor.dm:53-64): the tub
-- plus a rack. An item, for the same reason as `mop_bucket`: native storage is
-- the rack, `show_contents` is `update_overlays` (janitor.dm:359-372), and
-- alt-click opens it in place of tg's radial. Tub 2.5 × 100 tg units
-- (janitor.dm:68) at the mop's scale. Nine rack places: bag, mop, broom, spray,
-- replacer and four signs (janitor.dm:58-64). docs/janitorial/trolley.md.
local content = {
    id = "janitor_trolley",
    visual_layer = "low_object",
    motion_response = {
        mass = 50.0,
        restitution = 0.1,
        friction = 0.8,
        half_extent = 0.45,
        public_contacts = true,
    },
    name_label = "lunatic/tfs:entity.janitor_trolley.name",
    name = "janitorial cart",
    sprite = "janitor_trolley",
    examine = { flavor = "This is the alpha and omega of sanitation." },
    volume_ml = 4167,
    fill_sprites = { { 1, "janitor_trolley_water" } },
    storage = 9,
    show_contents = true,
    gestures = { "secondary" },
}

local spec: wheeled_tub.Spec = {
    id = content.id,
    noun = "cart",
    -- `tool.use_tool(src, user, 5 SECONDS, ...)` (janitor.dm:257).
    dump_seconds = 5,
}
content.actions = wheeled_tub.actions(spec)

if sim ~= nil then
    wheeled_tub.attach(spec)
end

return content
