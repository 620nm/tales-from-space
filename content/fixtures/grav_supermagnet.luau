local grav_smes = require("@lib/grav_smes")

-- A wrench on the packed cart sets its ring between two emitters.
local content = { id = "grav_supermagnet" }
if sim ~= nil then
    local definition =
        sim.define("behavior", "lunatic/tfs:grav_supermagnet", { prototype = content.id })
    definition:handle(
        "interaction.use",
        { kind = "replace", route = "interact" },
        grav_smes.set_ring
    )
end
return content
