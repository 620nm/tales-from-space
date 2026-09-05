-- The first thing a surgeon reaches for (tg surgery_tools.dm:208-231).
local content = {
    id = "scalpel", name = "scalpel", sprite = "scalpel",
    tool = "scalpel", tool_speed = 1, surgical = true,
    force = 10, sharp = "edged",
    -- A surgical tool with nothing to do is refused rather than swung,
    -- and the reason rides `info.surgery_refusal` (docs/SURGERY.md §6.3).
    -- The tool speaks; the engine says nothing.
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
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:lib.surgery.not_lying_down", {}),
            })
        elseif why == "obstructed" then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:lib.surgery.site_covered", {}),
            })
        else
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.scalpel.there_is_nothing_to_do", {}),
            })
        end
        return true
    end)
end

return content
