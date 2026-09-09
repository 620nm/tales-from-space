local content = { id = "airlock" }
if sim ~= nil then
    local def = sim.define("behavior", "lunatic/tfs:airlock", { prototype = content.id })
    def:handle("link.message.done", { kind = "react" }, controller.device)
    def:handle("door.operation.done", { kind = "react" }, controller.door)
    -- A command carries no actor, and the host's policy is its gate
    -- (docs/scripting/controllers.md). A hand keeps the engine's own
    -- answer: a transform must return a table, and falling off the end
    -- faults the handler off the round.
    def:handle("door.permission", { kind = "transform" }, function(ev)
        return { allowed = ev.actor == nil or ev.allowed }
    end)
end
return content
