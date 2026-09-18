local controller = require("@lib/controller")

local content = { id = "bidirectional_vent" }
if sim ~= nil then
    local def = sim.define("behavior", "lunatic/tfs:bidirectional_vent", { prototype = content.id })
    def:handle("link.message.done", { kind = "react" }, controller.device)
    def:handle("atmos.pressure_target.done", { kind = "react" }, controller.pressure)
end
return content
