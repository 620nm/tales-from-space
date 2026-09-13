-- One black crayon stick. Thirty successful commits consume its uses.
-- tg crayons.dm:636-690.
local content = {
    id = "crayon_black",
    name_label = "lunatic/tfs:entity.crayon_black.name",
    name = "black crayon",
    sprite = "crayon_black",
    acts_on_items = true,
    uses = 30,
    writer = {
        font_family = "kalam-bold",
        weight = 700,
        colors = { { name = "black", color = "#1C1C1C" } },
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
    local behavior = sim.define("behavior", "lunatic/tfs:crayon_black", { prototype = content.id })
    writing.attach(behavior)
end

return content
