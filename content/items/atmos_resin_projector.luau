-- The hand-held half of tg's atmospherics emergency resin kit. tg's
-- backpack nozzle lays resin foam on an adjacent turf, with five charges
-- regenerating on ten-second timers (code/game/objects/items/tanks/
-- watertank.dm:287-327). This first portable carries those five shots;
-- refilling waits for the backpack itself.
--
-- What one shot MEANS belongs here: put the pack's resin column on the
-- room cell. Plasma fire's two content rules read the same column and
-- stop, so the engine only owns the named scalar, its decay, and the
-- reaction arithmetic. The `ExtinguishedAt` consequence stays a native
-- ledger edge and is not a hook.
local content = {
    id = "atmos_resin_projector",
    name = "atmos resin projector",
    -- Reuse the rapid pipe dispenser silhouette until the next asset
    -- bake brings in tg's backpack nozzle; this change does not alter the
    -- asset manifests or the wire.
    sprite = "rpd",
    category = "tools",
    uses = 5,
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
        local turf = sim.turf(x, y)
        if turf ~= "floor" and turf ~= "plating" and turf ~= "reinforced_floor" then
            return { replaced = false }
        end
        if (self.uses or 0) <= 0 then
            sim.message.send({ recipient = user, message = "The resin projector is empty." })
            return true
        end

        local cell = ev.at.matter
        local reading = sim.matter_read(cell)
        local resin = reading and reading.columns.atmos_resin or nil
        if resin == nil then
            return { replaced = false }
        end
        if resin >= 1.0 then
            sim.message.send({ recipient = user, message = "The deck is already sealed under fresh resin." })
            return true
        end

        sim.matter_set_column(cell, "atmos_resin", 1.0)
        self:consume()
        sim.sound.play({ asset = "lunatic/tfs:sound/spray", at = ev.at })
        sim.message.send({ recipient = user, message = "You coat the deck in fire-smothering resin." })
        return true
    end)
end

return content
