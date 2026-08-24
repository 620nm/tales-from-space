-- The first item to cross the content boundary. Robust — and, since
-- the chillstation redirect, an actual container: it ships stocked
-- with the engineering loop (open it from your hand to get at them).
local content = {
    id = "toolbox",
    name = "mechanical toolbox",
    sprite = "toolbox",
    inhand_sprite = { "held_toolbox_l", "held_toolbox_r" },
    -- A boxful of loose steel, and it sounds like it. tg
    -- _toolbox.dm:19-21.
    pickup_sound = "toolbox_pickup",
    drop_sound = "toolbox_drop",
    storage = 7,
    holds = { "welder", "crowbar", "wirecutters", "screwdriver", "wrench", "cable_coil" },
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("attack.swing", { kind = "replace", route = "attack" }, function(ev)
        local self, user = ev.implement, ev.actor
        local target, victim, item = ev.target, ev.target, ev.target
        local info = { surgery_refusal = ev.refusal }
        local _self, _victim = self, victim
        sim.damage.apply({ target = target, amounts = { brute = 10 } })
        sim.sound.play({ asset = "lunatic/tfs:sound/smash", at = target.tile })
        -- One whole sentence per message, the name passed as an
        -- argument rather than glued on with `..`: a fragment joined in
        -- content is a fragment no catalog can decline
        -- (docs/LOCALIZATION.md §5). ctx has no msg(key, args) yet, so
        -- the frame still lives here; when it does, these two calls
        -- become keys and the arguments are already the arguments.
        sim.message.send({ recipient = user, message = string.format("You rob %s with the toolbox!", target.name) })
        sim.message.send({ recipient = target, message = string.format("%s robs you with a toolbox!", user.name) })
        return true
    end)
end

return content
