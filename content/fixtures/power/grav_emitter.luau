local grav_smes = require("@lib/power/grav_smes")
local turning = require("@lib/turning")

-- Alt+click turns an emitter; a lit welder on an anchored one fuses the
-- whole assembly.
local content = { id = "grav_emitter" }
if sim ~= nil then
    local definition =
        sim.define("behavior", "lunatic/tfs:grav_emitter", { prototype = content.id })
    turning.attach(definition, { route = "interact" })
    definition:handle("interaction.use", { kind = "replace", route = "interact" }, grav_smes.weld)
    grav_smes.track(definition)
end
return content
