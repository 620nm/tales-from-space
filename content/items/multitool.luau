-- Reads what a wire is doing before you cut it, and defeats a safety
-- interlock if you would rather it did that.
--
-- It has a tool class now, and one machine in the game answers to it:
-- a multitool on a volumetric pump throws its pressure limiters
-- (tg's `multitool_act`, volume_pump.dm:162-170), after which the pump
-- will push past what the kit is rated for and leak a tenth of
-- everything it moves into the room. Nothing else in the construction
-- chain dispatches on the class yet -- a target that declares no
-- multitool step simply is not interested.
--
-- tg: /obj/item/multitool (multitool.dm:14).
local content = {
    id = "multitool",
    name = "multitool",
    sprite = "multitool",
    tool = "multitool",
    inhand_sprite = { "held_multitool_l", "held_multitool_r" },
    stowed_sprite = "belt_multitool",
    -- tg multitool.dm:28-29.
    pickup_sound = "multitool_pickup",
    drop_sound = "multitool_drop",
    -- The first half of the sentence at the top of this file: hold it
    -- against an open deck and it says what the cable under there is
    -- carrying, per channel (`sim.segment_live`). A READ and nothing
    -- else -- what a machine draws, what a breaker is set to and what a
    -- bank has left are the grid's business and a window's, not a
    -- probe's (docs/POWER.md).
    --
    -- It declines every click it has nothing to say about, so nothing
    -- this tool already does is shadowed: a click that NAMES something
    -- is that thing's business (the pump's limiters, a machine's
    -- window), a finished floor hides its wiring, and a bare tile with
    -- no cable in it is not a wire at all. `interaction.use` is late in the click
    -- order but not last (docs/LUAU-API.md §9), so declining is what
    -- keeps the rungs below it reachable.
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local clicked, target = ev.claim, ev.claim
        local _x, _y, _choice = x, y, choice
        if clicked ~= nil and clicked.entity ~= nil then
            return { replaced = false }
        end
        if not sim.subfloor_exposed(x, y) then
            return { replaced = false }
        end
        local live = sim.segment_live(x, y)
        if live == nil then
            return { replaced = false }
        end
        -- One authored line per state of the pair: "equipment and
        -- lighting" is two words and a conjunction, and joining those
        -- three is the composition rule's third clause
        -- (docs/LOCALIZATION.md 5).
        local carrying = nil
        if live.equipment and live.lighting then
            carrying = "carrying_both"
        elseif live.equipment then
            carrying = "carrying_equipment"
        elseif live.lighting then
            carrying = "carrying_lighting"
        end
        if carrying == nil then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.multitool.the_cable_here_is_dead", {}),
            })
        else
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.multitool." .. carrying, {}),
            })
        end
        return true
    end)
end

return content
