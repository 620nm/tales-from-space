-- First aid in a glass: libital solution. Same drinking gesture as the
-- cola — click your own tile with it in hand.
return {
    id = "beaker_libital",
    name = "beaker (libital)",
    sprite = "beaker",
    contents = { water = 0.20, libital = 0.15 },
    on_use = function(ctx, self, user, x, y)
        local px, py = ctx.pos(user)
        if x ~= px or y ~= py then
            return "pass"
        end
        local c = ctx.contents(self)
        local total = 0
        for _, n in pairs(c) do
            total = total + n
        end
        if total < 0.001 then
            ctx.system_msg(user, "The beaker is empty.")
            return
        end
        ctx.sound("drink", x, y)
        ctx.drink(self, user, 0.05)
        ctx.system_msg(user, "You drink from the beaker. It tastes like a hospital.")
    end,
}
