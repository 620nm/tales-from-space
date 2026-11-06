local grav_smes = require("@lib/power/grav_smes")
local turning = require("@lib/turning")

-- Alt+click turns an emitter; a lit welder on an anchored one fuses the
-- whole assembly. One replacement answers both, since only one runs.
local content = { id = "grav_emitter" }
if sim ~= nil then
    local definition =
        sim.define("behavior", "lunatic/tfs:grav_emitter", { prototype = content.id })
    definition:handle(
        "interaction.use",
        { kind = "replace", route = "interact" },
        function(ev: InteractionUsePayload)
            if turning.is_turn(ev) then
                return turning.turn(ev)
            end
            return grav_smes.weld(ev)
        end
    )
    grav_smes.track(definition)
end
return content
