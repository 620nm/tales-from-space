-- One yellow crayon stick. Thirty successful commits consume its uses.
-- tg crayons.dm:636-690.
local content = {
    id = "crayon_yellow",
    name_label = "lunatic/tfs:entity.crayon_yellow.name",
    name = "yellow crayon",
    sprite = "crayon_yellow",
    acts_on_items = true,
    uses = 30,
    writer = {
        font_family = "kalam-bold",
        weight = 700,
        colors = { { name = "yellow", color = "#FFF200" } },
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
    local behavior = sim.define("behavior", "lunatic/tfs:crayon_yellow", { prototype = content.id })
    writing.attach(behavior)
end

return content
