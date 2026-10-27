local controller = require("@lib/controller")

local content = { id = "airlock" }
if sim ~= nil then
    local def = sim.define("behavior", "lunatic/tfs:airlock", { prototype = content.id })
    def:handle("link.message.done", { kind = "react" }, controller.device)
    def:handle("door.operation.done", { kind = "react" }, controller.door)
    def:handle("latch.set.done", { kind = "react" }, controller.latch)
    -- A command carries no actor, and the host's policy is its gate
    -- (docs/scripting/controllers.md). A hand keeps the engine's answer.
    -- A transform must return a table; falling off the end faults it.
    def:handle("access.permission", { kind = "transform" }, function(ev)
        return { allowed = ev.actor == nil or ev.allowed }
    end)
end
return content
