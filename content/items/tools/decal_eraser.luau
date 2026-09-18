local action_rules = require("@lib/action_rules")

-- The decal eraser.
--
-- TG HAS NO SUCH ITEM, and that is a deliberate divergence. There a
-- decal comes off only with the floor tile under it (decal_painter.dm:3,
-- "Decals break when the floor tiles are removed"), which makes a
-- misplaced arrow a deconstruction job. Josh's ruling: a dedicated
-- eraser always erases, and it is the only thing that does. A decal is
-- not dirt -- space cleaner and the mop are for spills -- and nothing
-- else on the station touches one.
--
-- It peels, one click one marking, newest first. `sim.decals_at` is
-- ordered by the decals roster rather than by when each was laid down,
-- so the newest is the highest runtime instance -- every placement
-- mints a fresh one (the engine's `docs/content-schema/decals.md`).
-- Repeated clicks therefore take a stacked tile apart in the reverse of
-- the order it was built up. Erasing all four at once would make a slip
-- of the hand unrecoverable and save nothing but clicks.
--
-- The art is tg's third decal-sprayer cell, the one on its debug
-- "extreme decal painter" (`icon_state = "decal_sprayer_ex"`,
-- decal_painter.dm:141-143): the same tool family, visibly not the same
-- tool, and nothing here ports the debug item it belongs to.

local content = {
    id = "decal_eraser",
    visual_layer = "item",
    name_label = "lunatic/tfs:entity.decal_eraser.name",
    name = "decal eraser",
    sprite = "decal_eraser",
    inhand_sprite = { "held_decal_painter_l", "held_decal_painter_r" },
}

-- Every deck, the same as the painter: a grating carries no marking,
-- and says so, instead of swallowing the click.
content.actions = { action_rules.primary("erase_decal", action_rules.any_deck()) }

if sim ~= nil then
    local script_definition =
        sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local user, x, y, choice = ev.actor, ev.at.x, ev.at.y, ev.choice
        local clicked = ev.claim
        local _x, _y, _choice = x, y, choice
        if clicked ~= nil and clicked.entity ~= nil then
            return { replaced = false }
        end
        local newest = nil
        for _, decal in ipairs(sim.decals_at(x, y)) do
            if newest == nil or decal.instance > newest then
                newest = decal.instance
            end
        end
        if newest == nil then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.decal_eraser.nothing_here", {}),
            })
            return true
        end
        sim.remove_decal(x, y, newest)
        -- The same hiss the painter makes, because it is the same
        -- nozzle with solvent in it (airlock_painter.dm:52-55).
        sim.sound.play({ asset = "lunatic/tfs:sound/paint_spray", at = ev.at })
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:items.decal_eraser.erased", {}),
        })
        return true
    end)
end

return content
