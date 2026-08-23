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
return {
    id = "atmos_resin_projector",
    name = "atmos resin projector",
    -- Reuse the rapid pipe dispenser silhouette until the next asset
    -- bake brings in tg's backpack nozzle; this change does not alter the
    -- asset manifests or the wire.
    sprite = "rpd",
    category = "tools",
    uses = 5,
    on_use = function(ctx, self, user, x, y, _choice, clicked)
        if clicked ~= nil and clicked.entity ~= nil then
            return "pass"
        end
        local turf = ctx.turf(x, y)
        if turf ~= "floor" and turf ~= "plating" and turf ~= "reinforced_floor" then
            return "pass"
        end
        if (ctx.uses(self) or 0) <= 0 then
            ctx.system_msg(user, "The resin projector is empty.")
            return
        end

        local cell = ctx.cell(x, y)
        local resin = ctx.column(cell, "atmos_resin")
        if resin == nil then
            return "pass"
        end
        if resin >= 1.0 then
            ctx.system_msg(user, "The deck is already sealed under fresh resin.")
            return
        end

        ctx.matter_set_column(cell, "atmos_resin", 1.0)
        ctx.consume(self)
        ctx.sound("spray", x, y)
        ctx.system_msg(user, "You coat the deck in fire-smothering resin.")
    end,
}
