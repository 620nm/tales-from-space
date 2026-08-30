local SPRAY, STREAM = 0, 1
local content = {
    id = "spray_bottle", name = "spray bottle", sprite = "spray_bottle",
    volume_ml = 250, modes = 2, mode = SPRAY, acts_on_items = true,
    ranged_use = { range = 5, effect = "spray_puff", sound = "spray" },
}
if sim ~= nil then
    local d = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    d:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local next_mode = (sim.mode(ev.subject).index + 1) % 2
        sim.set_mode(ev.subject, next_mode)
        sim.message.send({ recipient = ev.actor,
            message = next_mode == STREAM and "You set the nozzle to stream."
                or "You set the nozzle to spray." })
        return true
    end)
    d:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local target = ev.at
        if ev.claim ~= nil and ev.claim.entity ~= nil then target = ev.claim.entity end
        sim.matter.spray({ from = ev.subject, target = target,
            mode = sim.mode(ev.subject).index == STREAM and "stream" or "spray" })
        return true
    end)
end
return content
