-- Repairs what the wirecutters undo, on whichever of the station's
-- three power lines you have the coil set to.
--
-- A reel is 30 lengths, tg's coil size. That count is what lets a
-- machine frame ask for five of them: wiring an assembly is a
-- structure transition, and transitions spend stacks.
--
-- Laying cable is NOT a structure transition -- there is nothing on the
-- tile that owns the answer -- so it stays an interaction.use hook, which the
-- interpreter falls through to when no table names this item.
--
-- Cable goes UNDER the deck, so the tile has to be open -- the same rule
-- pipe.luau states, and for the same tg reason (a covered turf hides its
-- contents: code/game/turfs/turf.dm:503-506). Unlike the cutters, this
-- refusal SPEAKS: you are placing something you are holding onto a floor
-- you can see, so the message describes the floor and gives away nothing
-- about what may already be buried.
--
-- THE LINES. tg has three cable layers, and they are the real thing:
-- connection is gated on the layer bitflag and nothing else
-- (cable.dm:121), so three cables can share a tile and be three
-- separate circuits. The colours are a mnemonic for the layer, not a
-- mechanism -- tg's own names for them are "Red/Yellow/Blue Power
-- Line" (__DEFINES/power.dm:5,8,11), and its coil recolours itself to
-- match whichever layer you picked (cable.dm:596,602,608).
local LINES = {
    { mask = 1, name = "the red power line" },
    { mask = 2, name = "the yellow power line" },
    { mask = 4, name = "the blue power line" },
}

local content = {
    id = "cable_coil",
    name = "cable coil",
    sprite = "coil",
    inhand_sprite = { "held_coil_l", "held_coil_r" },
    stack = 30,
    -- This IS the station's cable: what a run under the deck is made
    -- of, and therefore what cutting one hands back. One field, both
    -- directions -- the engine floods the powernet and never learns
    -- that the thing you lay it with is called a coil.
    subfloor = "cable",
    -- Three settings, minted on the second: tg's coil defaults to
    -- CABLE_LAYER_2 (cable.dm:513), which is the line the shipped
    -- station runs its backbone on.
    modes = 3,
    mode = 1,
    -- tg's "Use it in hand to change the layer you are placing on"
    -- (cable.dm:529). tg pops a radial menu there (cable.dm:589); we
    -- have no radial widget, so this cycles and says where it landed,
    -- which is the same information in one keypress instead of two.
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        local dial = sim.mode(self)
        local next_index = (dial.index + 1) % dial.count
        sim.set_mode(self, next_index)
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:items.cable_coil.set", {
                line = LINES[next_index + 1].name,
            }),
        })
        return true
    end)
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local clicked, target = ev.claim, ev.claim
        local _x, _y, _choice = x, y, choice
        -- Asked first, so every covered tile answers the same way and
        -- the reply is not a probe for what is already buried. Open
        -- deck, not "plating": the map decides per tile.
        if not sim.subfloor_exposed(x, y) then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.cable_coil.the_floor_is_in_the", {}),
            })
            return true
        end
        local line = LINES[sim.mode(self).index + 1]
        if sim.cable(x, y) % (line.mask * 2) >= line.mask then
            return { replaced = false } -- this line already runs here
        end
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:items.cable_coil.you_start_laying_cable", {}),
        })
        sim.spawn_task(user, function()
            if sim.do_after(user, sim.ticks(1.0), {}) == "interrupted" then
                sim.message.send({
                    recipient = user,
                    message = sim.msg("lunatic/tfs:items.cable_coil.you_stop_laying_cable", {}),
                })
                return true
            end
            -- The same question again at the end: while you worked, another
            -- engineer may have cabled this very tile. The dial is asked
            -- again too -- a do_after is a whole second, and nothing stops
            -- you turning it mid-job.
            line = LINES[sim.mode(self).index + 1]
            if sim.cable(x, y) % (line.mask * 2) >= line.mask then
                sim.message.send({
                    recipient = user,
                    message = sim.msg("lunatic/tfs:items.cable_coil.taken", {
                        line = line.name,
                    }),
                })
                return true
            end
            sim.lay_cable(x, y, line.mask)
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.cable_coil.laid", {
                    line = line.name,
                }),
            })
        end)
        return true
    end)
end

return content
