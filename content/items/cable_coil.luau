-- Repairs what the wirecutters undo. Lays branch (consumer-spec) cable;
-- feeder work needs heavier gear and arrives with construction.
return {
    id = "cable_coil",
    name = "cable coil",
    sprite = "coil",
    builds = { label = "Cable", sprite = "coil", target = "floor", cost = 1, secs = 1.0 },
    on_use = function(ctx, self, user, x, y)
        local mask = ctx.cable(x, y)
        if mask % 4 >= 2 then
            return "pass" -- branch already present here
        end
        ctx.system_msg(user, "You start laying cable...")
        if ctx.do_after(user, 1.0) then
            ctx.lay_cable(x, y, 2)
            ctx.system_msg(user, "You lay branch cabling.")
        else
            ctx.system_msg(user, "You stop laying cable.")
        end
    end,
}
