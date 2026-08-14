-- Sabotage, attributable: cutting a cable is a Script-actor ledger row
-- naming this file and the player holding the cutters. Layer masks:
-- 1 = feeder (red), 2 = branch (yellow), 4 = reserved (blue).
--
-- Cabling under an intact floor tile is out of reach, exactly as the
-- pipe under it is: tg's levelupdate() drops everything in a covered
-- turf to UNDERFLOOR_HIDDEN (code/game/turfs/turf.dm:503-506,
-- code/__DEFINES/turfs.dm:50-54), so the cutters never see it. The
-- refusal is a silent "pass" rather than a message, because telling a
-- saboteur "there is cable down there" is the whole thing the covering
-- floor is meant to prevent.
return {
    id = "wirecutters",
    name = "wirecutters",
    sprite = "wirecutters",
    inhand_sprite = { "held_wirecutters_l", "held_wirecutters_r" },
    -- The equipment class targets dispatch on; no tank, nothing to burn.
    tool = "cutters",
    on_use = function(ctx, self, user, x, y)
        if ctx.turf(x, y) ~= "plating" then
            return "pass"
        end
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
