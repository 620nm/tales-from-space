-- A wrench on a gas turbine section with its panel open turns it a quarter
-- clockwise: tg's `default_change_direction_wrench` (_machinery.dm:1069-1077)
-- plays the wrench's sound and sets `turn(dir, -90)`, BYOND's negative angle
-- being clockwise. With the panel shut tg's `wrench_act` does nothing
-- (turbine.dm:186-189), so the click goes on down the ladder.
local gas_turbine_wrench = {}

local OPEN = "open"
local WRENCH = "wrench"
-- The pack's own line for tg's "You rotate [src]." (_machinery.dm:1075).
local TURNED = "lunatic/tfs:lib.gas_turbine_wrench.turned"

-- Every key this module sends, for the roster file to define.
function gas_turbine_wrench.message_keys(): { string }
    return { TURNED }
end

-- The wrench row every section shares, offered with the panel open
-- (tg's "Rotate" screentip, turbine.dm:72-74).
function gas_turbine_wrench.turn_row(): { [string]: any }
    return {
        id = "turn_section",
        gesture = "primary",
        route = "receiver",
        label = "lunatic/tfs:ui.affordance.rotate",
        target = { fact = "target.state", value = OPEN },
        held = { fact = "held.proto", value = WRENCH },
        uses_held = true,
        suggest_implement = { item = WRENCH },
    }
end

-- A wrench on an open section turns it one declared facing clockwise; any
-- other click, or a shut panel, declines.
function gas_turbine_wrench.turn(ev: InteractionUsePayload): boolean | { replaced: boolean }
    local section, tool = ev.subject, ev.implement
    if tool == nil or not tool.alive or (tool.base or tool.prototype) ~= WRENCH then
        return { replaced = false }
    end
    if section.state ~= OPEN then
        return { replaced = false }
    end
    sim.structure.turn({ entity = section, clockwise = true })
    -- tg plays the wrench's `usesound` at volume 50; a roster sound carries
    -- no volume, so this one plays at the ratchet's own.
    sim.sound.play({ sound = "ratchet", at = ev.at })
    sim.message.send({ recipient = ev.actor, message = sim.msg(TURNED, {}) })
    return true
end

return gas_turbine_wrench
