local reflection_chamber = require("@lib/process/reflection_chamber")

local content = { id = "reflection_chamber" }

if sim ~= nil then
    for _, key in ipairs(reflection_chamber.message_keys()) do
        sim.define("message", key, { placeholders = {} })
    end
    sim.define("script_var", "lunatic/tfs:reflection_watching", { replicate = "server" })
    local behavior =
        sim.define("behavior", "lunatic/tfs:reflection_chamber", { prototype = "reflection_chamber" })
    behavior:handle(
        "entity.initialize.done",
        { kind = "react" },
        reflection_chamber.on_initialize
    )
    behavior:handle("structure.changed", { kind = "react" }, reflection_chamber.on_changed)
    behavior:handle("examine.lines", { kind = "transform" }, reflection_chamber.examine_lines)
end

return content
