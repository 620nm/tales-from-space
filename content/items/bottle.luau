-- The bottle: fifty units with a neck on it. Same size as the beaker
-- and a different shape of thing to carry it in -- a beaker is what you
-- mix in and a bottle is what you put on a shelf afterwards.
--
-- Capacity is tg's `volume = 50` at the documented bridge of
-- 1 u = 0.025 mol (docs/reagents.md); the picture and the fill prefix
-- are both tg's `bottle` (bottle.dm:6-7; `volume = 50` at :12,
-- `fill_icon_thresholds` at :13).
--
-- The three gestures are the vessel's rather than the beaker's: your
-- own tile is a swig, another vessel within reach is a pour, the deck
-- is a spill. (Content files cannot `require` one another, so each one
-- spells them out; see card.luau on the same tradeoff.)
local U = 0.025

return {
    id = "bottle",
    name = "bottle",
    sprite = "bottle",
    capacity_mol = 50 * U,
    fill_sprites = {
        { 1, "bottle_fill_1" },
        { 20, "bottle_fill_20" },
        { 40, "bottle_fill_40" },
        { 60, "bottle_fill_60" },
        { 80, "bottle_fill_80" },
        { 100, "bottle_fill_100" },
    },
    acts_on_items = true,
    on_use = function(ctx, self, user, x, y, choice, clicked)
        local function total(obj)
            local c = ctx.contents(obj)
            if c == nil then
                return nil
            end
            local n = 0
            for _, moles in pairs(c) do
                n = n + moles
            end
            return n
        end

        if clicked ~= nil and clicked.entity ~= nil then
            if total(clicked.entity) == nil then
                return "pass"
            end
            if (total(self) or 0) < 0.001 then
                ctx.system_msg(user, "The bottle is empty.")
                return
            end
            -- tg's cup default `amount_per_transfer_from_this = 10`
            -- (_cup.dm:4), which is also the beaker's gesture.
            ctx.pour(self, clicked.entity, 10 * U)
            ctx.system_msg(user, "You pour from the bottle.")
            return
        end

        local px, py = ctx.pos(user)
        if x == px and y == py then
            if (total(self) or 0) < 0.001 then
                ctx.system_msg(user, "The bottle is empty.")
                return
            end
            ctx.sound("drink", x, y)
            ctx.drink(self, user, 2 * U)
            ctx.system_msg(user, "You drink from the bottle.")
            return
        end

        local turf = ctx.turf(x, y)
        if turf ~= "floor" and turf ~= "plating" then
            return "pass"
        end
        if (total(self) or 0) < 0.001 then
            ctx.system_msg(user, "The bottle is empty.")
            return
        end
        ctx.spill(self, x, y)
        ctx.system_msg(user, "You tip the bottle out onto the deck.")
    end,
}
