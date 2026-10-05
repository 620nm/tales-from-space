local physical_profiles = require("@lib/physical_profiles")
local action_rules = require("@lib/action_rules")
local consume_followups = require("@lib/consume_followups")

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
-- ledger edge and is not a handler.

-- A shot on its way to the deck: the room cell it coats, who aimed it,
-- and the clicked tile.
type ResinShot = { cell: MatterOwner, user: Handle, at: TileAddress }

local content = {
    id = "atmos_resin_projector",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.atmos_resin_projector.name",
    name = "atmos resin projector",
    -- Reuse the rapid pipe dispenser silhouette until the next asset
    -- bake brings in tg's backpack nozzle; this change does not alter the
    -- asset manifests or the wire.
    sprite = "rpd",
    category = "tools",
    uses = 5,
}

content.actions = {
    action_rules.primary("seal_deck", action_rules.deck("floor_tiles", "grid_cover", "station_base", "reinforcement")),
}

if sim ~= nil then
    local script_definition =
        sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    -- The deck is coated only by a charge that was spent: a consume an
    -- exchange holds spends nothing and must seal nothing
    -- (lib/consume_followups.luau).
    local shots = consume_followups.new() :: consume_followups.ConsumeFollowups<ResinShot>
    script_definition:handle(
        "item.consume.done",
        { kind = "react" },
        function(ev: ItemConsumeDonePayload)
            local shot = consume_followups.settle(shots, ev.item)
            if shot == nil or ev.outcome ~= "completed" then
                return
            end
            sim.matter.set_column({ owner = shot.cell, column = "atmos_resin", value = 1.0 })
            sim.sound.play({ asset = "lunatic/tfs:sound/spray", at = shot.at })
            sim.message.send({
                recipient = shot.user,
                message = sim.msg(
                    "lunatic/tfs:items.atmos_resin_projector.you_coat_the_deck_in",
                    {}
                ),
            })
        end
    )
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local clicked, target = ev.claim, ev.claim
        local _x, _y, _choice = x, y, choice
        if clicked ~= nil and clicked.entity ~= nil then
            return { replaced = false }
        end
        if not sim.has_component(x, y, "station_base")
            or sim.has_component(x, y, "wall")
            or sim.has_component(x, y, "reinforced_wall") then
            return { replaced = false }
        end
        if (self.uses or 0) <= 0 then
            sim.message.send({
                recipient = user,
                message = sim.msg(
                    "lunatic/tfs:items.atmos_resin_projector.the_resin_projector_is_empty",
                    {}
                ),
            })
            return true
        end

        local cell = ev.at.matter
        local reading = sim.matter_read(cell)
        local resin = reading and reading.columns.atmos_resin or nil
        if resin == nil then
            return { replaced = false }
        end
        if resin >= 1.0 then
            sim.message.send({
                recipient = user,
                message = sim.msg(
                    "lunatic/tfs:items.atmos_resin_projector.the_deck_is_already_sealed",
                    {}
                ),
            })
            return true
        end

        consume_followups.expect(shots, self, { cell = cell, user = user, at = ev.at })
        self:consume()
        return true
    end)
end

return content
