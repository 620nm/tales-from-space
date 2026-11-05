local grav_smes = require("@lib/grav_smes")

-- A lit welder on a set ring fuses the whole assembly.
local content = { id = "grav_supermagnet_ring" }
if sim ~= nil then
    local definition =
        sim.define("behavior", "lunatic/tfs:grav_supermagnet_ring", { prototype = content.id })
    definition:handle("interaction.use", { kind = "replace", route = "interact" }, grav_smes.weld)
    grav_smes.track(definition)
end
return content
