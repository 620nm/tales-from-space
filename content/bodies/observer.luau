-- The observer staff step out into (content/lib/observe.luau): no parts,
-- no hands, unseen by the crew, and through every wall (`observer = true`,
-- the engine's docs/content-schema/bodies.md). It is never offered on the
-- crew board and never dies: its one capacity is a constant.
local content = {
    id = "observer",
    name = "observer",
    sprite = "ghost",
    visual_layer = "standing_mob",
    observer = true,
    max_health = 100,
    hands = 0,
    capacities = {
        awake = { role = "consciousness", awake_below = 0.30, formula = { "const", 1 } },
    },
}

if sim ~= nil then
    local observe = require("@lib/observe")
    sim.define("script_var", observe.LEFT, { replicate = "server", private = true })
    sim.define("script_var", observe.WAITING, { replicate = "server", private = true })
    sim.define("script_var", observe.SPENT, { replicate = "server", private = true })
    local behavior = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    -- A spawn answers the spawned plan, so the observer seats its asker here.
    behavior:handle("entity.spawn.done", { kind = "react" }, observe.on_spawned)
end

return content
