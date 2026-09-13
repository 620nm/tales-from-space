-- One orange crayon stick. Thirty successful commits consume its uses.
-- tg crayons.dm:636-690.
local content = {
    id = "crayon_orange",
    name_label = "lunatic/tfs:entity.crayon_orange.name",
    name = "orange crayon",
    sprite = "crayon_orange",
    acts_on_items = true,
    uses = 30,
    writer = {
        font_family = "kalam-bold",
        weight = 700,
        colors = { { name = "orange", color = "#FF9300" } },
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
    local behavior = sim.define("behavior", "lunatic/tfs:crayon_orange", { prototype = content.id })
    writing.attach(behavior)
end

return content
