local content = { id = "airlock_pump" }
if sim ~= nil then
    local def = sim.define("behavior", "lunatic/tfs:airlock_pump", { prototype = content.id })
    def:handle("link.message.done", { kind = "react" }, controller.device)
    def:handle("atmos.pressure_target.done", { kind = "react" }, controller.pressure)
end
return content
