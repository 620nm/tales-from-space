-- Sabotage, attributable: cutting a cable is a Script-actor ledger row
-- naming this file and the player holding the cutters.
--
-- ONE SNIP, ONE CABLE. tg's wirecutter_act deconstructs the single
-- /obj/structure/cable you clicked (cable.dm:210-221) -- it never
-- clears the tile -- and you can pick which of three stacked cables
-- that is because BYOND separates them by a hundredth of a draw layer
-- (cable.dm:22,37,47) and the click lands on the topmost one under the
-- cursor. Our cables are subfloor topology rather than entities, so
-- there is no cursor to aim at a layer with; what carries over is the
-- rule that a snip takes the TOPMOST line and leaves the ones beneath
-- it running. Clearing a three-line tile is three snips, which is what
-- it costs in tg too.
local TOPMOST_FIRST = { 4, 2, 1 }

local function top_line(mask)
    for _, bit in ipairs(TOPMOST_FIRST) do
        if mask % (bit * 2) >= bit then
            return bit
        end
    end
    return nil
end

return {
    id = "wirecutters",
    name = "wirecutters",
    sprite = "wirecutters",
    inhand_sprite = { "held_wirecutters_l", "held_wirecutters_r" },
    -- The equipment class targets dispatch on; no tank, nothing to burn.
    tool = "cutters",
    on_use = function(ctx, self, user, x, y)
        if top_line(ctx.cable(x, y)) == nil then
            return "pass"
        end
        ctx.system_msg(user, "You start snipping through the cabling...")
        if not ctx.do_after(user, 1.0) then
            ctx.system_msg(user, "You stop cutting.")
            return
        end
        -- Asked again at the end, not remembered from the start: the
        -- line you were cutting may already be gone.
        local line = top_line(ctx.cable(x, y))
        if line == nil then
            return
        end
        ctx.sound("wirecutter", x, y)
        ctx.cut_cable(x, y, line)
        ctx.system_msg(user, "The cable parts with a snap.")
    end,
}
