local grav_smes = require("@lib/grav_smes")

-- The finished machine: its messages, the south-cell-only glass rule and
-- the refusal to cut welded joints. Every other step is a native
-- transition in structures/power/grav_smes.luau.
local content = { id = "grav_smes" }
if sim ~= nil then
    for _, key in ipairs(grav_smes.message_keys()) do
        sim.define("message", key, { placeholders = {} })
    end
    local definition = sim.define("behavior", "lunatic/tfs:grav_smes", { prototype = content.id })
    definition:handle(
        "interaction.use",
        { kind = "replace", route = "interact" },
        grav_smes.body_use
    )
end
return content
