-- Holds an incision open (tg surgery_tools.dm:1-16).
local content = {
    id = "retractor", name = "retractor", sprite = "retractor",
    tool = "retractor", tool_speed = 1, surgical = true,
    -- Refused rather than swung on a patient, the reason on
    -- `info.surgery_refusal` (docs/SURGERY.md §6.3).
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("attack.swing", { kind = "replace", route = "attack" }, function(ev)
        local self, user = ev.implement, ev.actor
        local target, victim, item = ev.target, ev.target, ev.target
        local info = { surgery_refusal = ev.refusal }
        local _self, _victim = self, victim
        if not info or not info.surgery_refusal then return { replaced = false } end
        local why = info.surgery_refusal
        if why == "not_lying" then
            sim.message.send({ recipient = user, message = "They need to be lying down for that." })
        elseif why == "obstructed" then
            sim.message.send({ recipient = user, message = "The operation site is covered." })
        else
            sim.message.send({ recipient = user, message = "There is nothing to retract there." })
        end
        return true
    end)
end

return content
