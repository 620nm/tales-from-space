local grav_smes = require("@lib/grav_smes")
local grav_smes_run = require("@lib/grav_smes_run")

-- The finished machine: its messages and its operating cycle
-- (lib/grav_smes_run.luau). Every build step past the weld is a native
-- transition in structures/power/grav_smes.luau.
local content = { id = "grav_smes" }
if sim ~= nil then
    for _, key in ipairs(grav_smes.message_keys()) do
        sim.define("message", key, { placeholders = {} })
    end
    for _, key in ipairs(grav_smes_run.message_keys()) do
        sim.define("message", key, { placeholders = {} })
    end
    local definition = sim.define("behavior", "lunatic/tfs:grav_smes", { prototype = content.id })
    definition:handle("interaction.act", { kind = "replace", route = "act" }, grav_smes_run.act)
    definition:handle("entity.initialize.done", { kind = "react" }, grav_smes_run.on_initialize)
    definition:handle("structure.changed", { kind = "react" }, grav_smes_run.on_changed)
    definition:handle("flow.store.done", { kind = "react" }, grav_smes_run.on_store)
    definition:handle("flow.load.done", { kind = "react" }, grav_smes_run.on_load)
end
return content
