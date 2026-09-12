local content = { id = "threat_spawn" }
if sim ~= nil then
    local behavior = sim.define("behavior", "lunatic/tfs:threat_spawn", { prototype = content.id })
    behavior:handle("entity.initialize.done", { kind = "react" }, map_markers.initialize)
end
return content
