-- Sabotage, attributable: cutting a cable is a Script-actor ledger row
-- naming this file and the player holding the cutters. Layer masks:
-- 1 = feeder (red), 2 = branch (yellow), 4 = reserved (blue).
return {
    id = "wirecutters",
    name = "wirecutters",
    sprite = "wirecutters",
    inhand_sprite = { "held_wirecutters_l", "held_wirecutters_r" },
    -- tg's belt sheet calls these "cutters", so the picture does too.
    stowed_sprite = "belt_cutters",
    -- The equipment class targets dispatch on; no tank, nothing to burn.
    tool = "cutters",
    on_use = function(ctx, self, user, x, y)
        if ctx.cable(x, y) == 0 then
            return "pass"
        end
        ctx.system_msg(user, "You start snipping through the cabling...")
        if ctx.do_after(user, 1.0) and ctx.cable(x, y) ~= 0 then
            ctx.sound("wirecutter", x, y)
            ctx.cut_cable(x, y, 7)
            ctx.system_msg(user, "The cable parts with a snap.")
        else
            ctx.system_msg(user, "You stop cutting.")
        end
    end,
}
