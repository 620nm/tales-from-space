-- Repairs what the wirecutters undo. Lays branch (consumer-spec) cable;
-- feeder work needs heavier gear and arrives with construction.
return {
    id = "cable_coil",
    name = "cable coil",
    sprite = "coil",
    builds = {
        id = "cable",
        label = "Cable",
        sprite = "coil",
        target = { "floor", "plating" },
        cost = 1,
        secs = 1.0,
    },
    on_use = function(ctx, self, user, x, y)
        if ctx.cable(x, y) % 4 >= 2 then
            return "pass" -- branch already present here
        end
        ctx.system_msg(user, "You start laying cable...")
        if not ctx.do_after(user, 1.0) then
            ctx.system_msg(user, "You stop laying cable.")
            return
        end
        -- The same question again at the end: while you worked, another
        -- engineer may have cabled this very tile.
        if ctx.cable(x, y) % 4 >= 2 then
            ctx.system_msg(user, "Someone already cabled that.")
            return
        end
        ctx.lay_cable(x, y, 2)
        ctx.system_msg(user, "You lay branch cabling.")
    end,
}
