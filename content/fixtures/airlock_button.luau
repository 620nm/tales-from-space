local controller = require("@lib/controller")

local content = { id = "airlock_button" }
if sim ~= nil then
    local def = sim.define("behavior", "lunatic/tfs:airlock_button", { prototype = content.id })
    def:handle("interaction.use", { kind = "replace", route = "interact" }, function(ev)
        controller.button(ev)
        return true
    end)
end
return content
