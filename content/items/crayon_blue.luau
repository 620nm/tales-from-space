-- One blue crayon stick. Thirty successful commits consume its uses.
-- tg crayons.dm:636-690.
local content = {
    id = "crayon_blue",
    name_label = "lunatic/tfs:entity.crayon_blue.name",
    name = "blue crayon",
    sprite = "crayon_blue",
    acts_on_items = true,
    uses = 30,
    writer = {
        font_family = "kalam-bold",
        weight = 700,
        colors = { { name = "blue", color = "#00B7EF" } },
    },
}

content.actions = {
    {
        id = "write", gesture = "primary", route = "held",
        label = "lunatic/tfs:action.crayon.write",
        target = { fact = "target.proto", value = "paper" },
    },
}

if sim ~= nil then
    local behavior = sim.define("behavior", "lunatic/tfs:crayon_blue", { prototype = content.id })
    writing.attach(behavior)
end

return content
