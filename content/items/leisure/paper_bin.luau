local physical_profiles = require("@lib/physical_profiles")
-- Thirty blank-sheet units. Native resource conversion materializes a paper
-- item on draw and reclaims only a blank paper on return.
-- tg paperbin.dm:3-18, :42-77, :91-141.
local content = {
    id = "paper_bin",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.paper_bin.name",
    name = "paper bin",
    sprite = "paper_bin",
    states = { "full", "empty" },
    state = "full",
    state_sprites = { full = "paper_bin", empty = "paper_bin_empty" },
    acts_on_items = true,
    hint_tags = { "paper_source" },
    resources = { paper = { capacity = 30, initial = 30 } },
    variants = {
        empty = {
            name = "empty paper bin",
            name_label = "lunatic/tfs:entity.paper_bin.empty.name",
            sprite = "paper_bin_empty",
            state = "empty",
            resources = { paper = { capacity = 30, initial = 0 } },
        },
    },
}

content.actions = {
    {
        id = "draw",
        gesture = "self",
        route = "self_use",
        label = "lunatic/tfs:action.paper_bin.draw",
    },
    {
        id = "return",
        gesture = "primary",
        route = "held",
        label = "lunatic/tfs:action.paper_bin.return",
        target = { fact = "target.proto", value = "paper" },
    },
}

if sim ~= nil then
    local function refresh(bin: Handle?)
        if bin == nil or not bin.alive or (bin.base or bin.prototype) ~= content.id then
            return
        end
        local state = "empty"
        for _, row in ipairs(sim.resources.read(bin)) do
            if row.id == "paper" and row.current > 0 then
                state = "full"
            end
        end
        if bin.state ~= state then
            sim.appearance.set_state({ entity = bin, state = state })
        end
    end
    local behavior = sim.define("behavior", "lunatic/tfs:paper_bin", { prototype = content.id })
    behavior:handle("entity.initialize.done", { kind = "react" }, function(ev)
        refresh(ev.entity)
    end)
    -- The interaction companion follows its committed resource commands.
    behavior:handle("interaction.use.done", { kind = "react" }, function(ev)
        refresh(ev.subject)
    end)
    sim.handle("resources.transfer.done", { kind = "react" }, function(ev)
        refresh(ev.from)
        refresh(ev.to)
    end)
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
        if item == nil or (item.base or item.prototype) ~= "paper" then
            return { replaced = false }
        end
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
