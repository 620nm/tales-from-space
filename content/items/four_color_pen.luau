-- Unlimited black, red, green, blue writing. The native writer snapshots
-- the exact selected state and font for each committed fragment.
-- tg pen.dm:125-152.
local content = {
    id = "four_color_pen",
    name_label = "lunatic/tfs:entity.four_color_pen.name",
    name = "four-color pen",
    sprite = "four_color_pen",
    acts_on_items = true,
    states = { "black", "red", "green", "blue" },
    state = "black",
    writer = {
        font_family = "patrick-hand",
        weight = 400,
        colors = {
            { name = "black", color = "#000000" },
            { name = "red", color = "#FF0000" },
            { name = "green", color = "#00FF00" },
            { name = "blue", color = "#0000FF" },
        },
    },
}

content.actions = {
    {
        id = "cycle_color", gesture = "self", route = "self_use",
        label = "lunatic/tfs:action.four_color_pen.cycle",
    },
    {
        id = "write", gesture = "primary", route = "held",
        label = "lunatic/tfs:action.four_color_pen.write",
        target = { fact = "target.proto", value = "paper" },
    },
}

if sim ~= nil then
    local behavior = sim.define("behavior", "lunatic/tfs:four_color_pen", { prototype = content.id })
    local colors = { "black", "red", "green", "blue" }

    behavior:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local index = sim.mode(ev.subject).index
        local next_index = (index + 1) % #colors
        sim.set_mode(ev.subject, next_index)
        sim.appearance.set_state({ entity = ev.subject, state = colors[next_index + 1] })
        return true
    end)

    writing.attach(behavior)
end

return content
