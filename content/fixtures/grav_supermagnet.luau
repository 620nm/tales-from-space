local grav_smes = require("@lib/grav_smes")

-- A lit welder on an anchored supermagnet fuses the whole assembly.
local content = { id = "grav_supermagnet" }
if sim ~= nil then
    local definition =
        sim.define("behavior", "lunatic/tfs:grav_supermagnet", { prototype = content.id })
    definition:handle("interaction.use", { kind = "replace", route = "interact" }, grav_smes.weld)
end
return content
