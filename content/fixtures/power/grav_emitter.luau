local grav_smes = require("@lib/power/grav_smes")

-- A lit welder on an anchored emitter fuses the whole assembly.
local content = { id = "grav_emitter" }
if sim ~= nil then
    local definition =
        sim.define("behavior", "lunatic/tfs:grav_emitter", { prototype = content.id })
    definition:handle("interaction.use", { kind = "replace", route = "interact" }, grav_smes.weld)
    grav_smes.track(definition)
end
return content
