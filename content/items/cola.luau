-- Dispensed by the vending machine; drinkable since M7. Clicking your
-- own tile with the can in hand takes a swig — the contents transfer
-- into your bloodstream mole by mole, and metabolism does the rest.
return {
    id = "cola",
    name = "can of Space Cola",
    sprite = "cola",
    contents = { water = 0.30, sugar = 0.06 },
    on_use = function(ctx, self, user, x, y)
        local px, py = ctx.pos(user)
        if x ~= px or y ~= py then
            return "pass" -- only a click on your own tile drinks
        end
        local c = ctx.contents(self)
        local total = 0
        for _, n in pairs(c) do
            total = total + n
        end
        if total < 0.001 then
            ctx.system_msg(user, "The can is empty.")
            return
        end
        ctx.sound("drink", x, y)
        ctx.drink(self, user, 0.05)
        ctx.system_msg(user, "You take a swig of Space Cola.")
    end,
}
