local physical_profiles = require("@lib/physical_profiles")
local writing = require("@lib/writing")

-- One purple crayon stick. Thirty successful commits consume its uses.
-- tg crayons.dm:636-690.
local content = {
    id = "crayon_purple",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.crayon_purple.name",
    name = "purple crayon",
    sprite = "crayon_purple",
    acts_on_items = true,
    uses = 30,
    writer = {
        font_family = "kalam-bold",
        weight = 700,
        colors = { { name = "purple", color = "#DA00FF" } },
    },
}

content.actions = {
    {
        id = "write",
        gesture = "primary",
        route = "held",
        label = "lunatic/tfs:action.crayon.write",
        target = { fact = "target.proto", value = "paper" },
    },
}

if sim ~= nil then
    local behavior = sim.define("behavior", "lunatic/tfs:crayon_purple", { prototype = content.id })
    writing.attach(behavior)
end

return content
