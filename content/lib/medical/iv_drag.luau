-- Dragging a docked IV stand onto a body selects the patient and connects the line.
local iv_line = require("@lib/medical/iv_line")

local iv_drag = {}
local CONNECT_REFUSED = "lunatic/tfs:action.iv_drip.connect_refused"

local function refuse(actor: Handle): ()
    if actor.alive then
        sim.message.send({ recipient = actor, message = sim.msg(CONNECT_REFUSED, {}) })
    end
end

function iv_drag.on_drag(ev: InteractionDragPayload): { replaced: boolean }
    local ok, vessel = pcall(function()
        return ev.subject:docked()
    end)
    if not ok or vessel == nil then
        refuse(ev.actor)
        return { replaced = false }
    end

    local queued = iv_line.connect({
        drip = ev.subject,
        actor = ev.actor,
        patient = ev.target,
        vessel = vessel,
    })
    if not queued then
        refuse(ev.actor)
    end
    return { replaced = queued }
end

return iv_drag
