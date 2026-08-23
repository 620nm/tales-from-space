-- Sabotage, attributable: cutting a cable is a Script-actor ledger row
-- naming this file and the player holding the cutters. Layer masks:
-- 1 = red, 2 = yellow, 4 = blue. What each line CARRIES is the
-- station's business, not the cutters' (docs/POWER.md).
--
-- Cabling under a covered deck is out of reach, exactly as the pipe
-- under it is: tg's levelupdate() drops everything in a covered turf to
-- UNDERFLOOR_HIDDEN (code/game/turfs/turf.dm:503-506,
-- code/__DEFINES/turfs.dm:50-54), so the cutters never see it. Whether
-- a deck is open is the tile's own answer and not its turf's name -- a
-- map may leave a panel open in a finished floor (docs/MAPPING.md). The
-- refusal is a silent "pass" rather than a message, because telling a
-- saboteur "there is cable down there" is the whole thing the covering
-- floor is meant to prevent.
--
-- ONE SNIP, ONE CABLE. tg's wirecutter_act deconstructs the single
-- /obj/structure/cable you clicked (cable.dm:210-221) -- it never
-- clears the tile -- and you can pick which of three stacked cables
-- that is because BYOND separates them by a hundredth of a draw layer
-- (cable.dm:22,37,47) and the click lands on the topmost one under the
-- cursor. The browser alpha-tests those same stacked sprites and the
-- server passes the validated exact line here. Clearing a three-line
-- tile is still three snips, but which one comes first is what you aim at.

return {
    id = "wirecutters",
    name = "wirecutters",
    sprite = "wirecutters",
    inhand_sprite = { "held_wirecutters_l", "held_wirecutters_r" },
    -- tg's belt sheet calls these "cutters", so the picture does too.
    stowed_sprite = "belt_cutters",
    -- tg wirecutters.dm:28-29.
    pickup_sound = "wirecutter_pickup",
    drop_sound = "wirecutter_drop",
    -- The equipment class targets dispatch on; no tank, nothing to burn.
    tool = "cutters",
    on_use = function(ctx, self, user, x, y, _, target)
        -- Asked before the cable question, so a covered tile answers
        -- the same whether or not anything runs under it.
        if not ctx.subfloor_exposed(x, y) then
            return "pass"
        end
        if target == nil or target.kind ~= "cable" then
            return "pass"
        end
        local line = target.layer
        if ctx.cable(x, y) % (line * 2) < line then
            return "pass"
        end
        ctx.system_msg(user, "You start snipping through the cabling...")
        if not ctx.do_after(user, 1.0) then
            ctx.system_msg(user, "You stop cutting.")
            return
        end
        -- Asked again at the end, not remembered from the start: the
        -- line you were cutting may already be gone.
        if ctx.cable(x, y) % (line * 2) < line then
            return
        end
        ctx.sound("wirecutter", x, y)
        ctx.cut_cable(x, y, line)
        ctx.system_msg(user, "The cable parts with a snap.")
    end,
}
