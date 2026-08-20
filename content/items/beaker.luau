-- The bare beaker: empty off the shelf, and the vessel everything else
-- on a chem bench is poured into. Capacity is the 50-unit beaker at the
-- documented bridge of 1 u = 0.025 mol (docs/reagents.md).
--
-- Three gestures, all of them one click with it in your active hand:
-- your own tile is a swig, another vessel within reach is a pour, and
-- the deck beside you is a spill.
local U = 0.025

return {
    id = "beaker",
    name = "beaker",
    sprite = "beaker",
    inhand_sprite = { "held_beaker_l", "held_beaker_r" },
    capacity_mol = 50 * U,
    -- Clicking another loose vessel has to reach this hook rather than
    -- picking it up: pouring is a thing you do TO the thing you named.
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

        -- 1. A vessel you pointed at: pour into it.
        if clicked ~= nil and clicked.entity ~= nil then
            if total(clicked.entity) == nil then
                return "pass" -- not something that holds anything
            end
            if (total(self) or 0) < 0.001 then
                ctx.system_msg(user, "The beaker is empty.")
                return
            end
            ctx.pour(self, clicked.entity, 0.25)
            ctx.system_msg(user, "You pour from the beaker.")
            return
        end

        -- 2. Your own tile: a swig.
        local px, py = ctx.pos(user)
        if x == px and y == py then
            if (total(self) or 0) < 0.001 then
                ctx.system_msg(user, "The beaker is empty.")
                return
            end
            ctx.sound("drink", x, y)
            ctx.drink(self, user, 0.05)
            ctx.system_msg(user, "You drink from the beaker.")
            return
        end

        -- 3. The deck beside you: tip it out.
        local turf = ctx.turf(x, y)
        if turf ~= "floor" and turf ~= "plating" then
            return "pass"
        end
        if (total(self) or 0) < 0.001 then
            ctx.system_msg(user, "The beaker is empty.")
            return
        end
        ctx.spill(self, x, y)
        ctx.system_msg(user, "You tip the beaker out onto the deck.")
    end,
}
