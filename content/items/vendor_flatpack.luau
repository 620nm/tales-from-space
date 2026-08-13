-- A vending machine, flat. Use it on a clear floor tile beside you;
-- remember it needs a powered outlet within cord range to actually
-- vend (docs/power.md — the cord is real).
return {
    id = "vendor_flatpack",
    name = "vending machine flatpack",
    sprite = "vendor",
    deploys = "vendor",
    builds = { label = "Vending machine", sprite = "vendor", target = "floor", cost = 1, secs = 3.0 },
    on_use = function(ctx, self, user, x, y)
        if ctx.turf(x, y) ~= "floor" then
            return "pass"
        end
        ctx.system_msg(user, "You start assembling the vending machine.")
        if ctx.do_after(user, 3.0) and ctx.turf(x, y) == "floor" then
            ctx.deploy(self, x, y)
        else
            ctx.system_msg(user, "You stop assembling.")
        end
    end,
}
