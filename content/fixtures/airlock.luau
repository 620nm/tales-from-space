local content = { id = "airlock" }
if sim ~= nil then
    local def = sim.define("behavior", "lunatic/tfs:airlock", { prototype = content.id })
    def:handle("link.message.done", { kind = "react" }, controller.device)
    def:handle("door.operation.done", { kind = "react" }, controller.door)
    def:handle("door.permission", { kind = "transform" }, function(ev)
        if ev.actor == nil then return { allowed = true } end
    end)
end
return content
