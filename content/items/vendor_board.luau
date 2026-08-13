-- The mainboard that makes a machine frame a vending machine (tg's
-- assembly precedent: the frame is generic, the board decides).
-- Remember it needs a powered outlet within cord range to actually
-- vend (docs/power.md — the cord is real).
return {
    id = "vendor_board",
    name = "machine board (vending)",
    sprite = "board",
    deploys = "vendor",
    builds = {
        id = "install",
        label = "Vending machine",
        sprite = "vendor",
        target = "frame",
        cost = 1,
        secs = 2.0,
    },
    on_use = function(ctx, self, user, x, y)
        if not ctx.frame(x, y) then
            return "pass"
        end
        ctx.system_msg(user, "You slot the board into the frame and secure it.")
        if ctx.do_after(user, 2.0) and ctx.frame(x, y) then
            ctx.deploy(self, x, y)
        else
            ctx.system_msg(user, "You stop assembling.")
        end
    end,
}
