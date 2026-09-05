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
        -- Where the swinger is pointing on the doll (tg's
        -- `zone_selected`). `aim`, not `part`: a swung toolbox TRIES
        -- for the part and mostly gets it, at the `aim` odds
        -- `content/part_tree.luau` declares — 80%, +10 while the target
        -- is down — and otherwise lands wherever the hit weights say.
        -- That is tg's `get_random_valid_zone`
        -- (code/_onclick/item_attack.dm:321-326), and it is what keeps
        -- a hammer from being a scalpel.
        sim.damage.apply({ target = target, amounts = { brute = 10 }, aim = sim.zone(user) })
        sim.sound.play({ asset = "lunatic/tfs:sound/smash", at = target.tile })
        -- One whole sentence per message, the name passed as an
        -- argument rather than glued on with `..`: a fragment joined in
        -- content is a fragment no catalog can decline (docs/WORDS.md).
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:items.toolbox.rob", { name = target.name }),
        })
        sim.message.send({
            recipient = target,
            message = sim.msg("lunatic/tfs:items.toolbox.robbed", { name = user.name }),
        })
        return true
    end)
end

return content
