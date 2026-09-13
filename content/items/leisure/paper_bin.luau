-- Thirty blank-sheet units. Native resource conversion materializes a paper
-- item on draw and reclaims only a blank paper on return.
-- tg paperbin.dm:3-18, :42-77, :91-141.
local content = {
    id = "paper_bin",
    name_label = "lunatic/tfs:entity.paper_bin.name",
    name = "paper bin",
    sprite = "paper_bin",
    acts_on_items = true,
    hint_tags = { "paper_source" },
    resources = { paper = { capacity = 30, initial = 30 } },
}

content.actions = {
    {
        id = "draw", gesture = "self", route = "self_use",
        label = "lunatic/tfs:action.paper_bin.draw",
    },
    {
        id = "return", gesture = "primary", route = "held",
        label = "lunatic/tfs:action.paper_bin.return",
        target = { fact = "target.proto", value = "paper" },
    },
}

if sim ~= nil then
    local behavior = sim.define("behavior", "lunatic/tfs:paper_bin", { prototype = content.id })
    behavior:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        sim.resources.materialize({
            source = ev.subject,
            resource = "paper",
            prototype = "paper",
            require_blank = true,
        })
        return true
    end)
    behavior:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local item = ev.claim and ev.claim.entity
        if item == nil or item.prototype ~= "paper" then return { replaced = false } end
        sim.resources.reclaim({
            item = item,
            target = ev.subject,
            resource = "paper",
            require_blank = true,
        })
        return true
    end)
end

return content
