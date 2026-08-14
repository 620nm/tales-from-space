-- Repairs what the wirecutters undo, on whichever of the station's
-- three power lines you have the coil set to.
--
-- A reel is 30 lengths, tg's coil size. That count is what lets a
-- machine frame ask for five of them: wiring an assembly is a
-- structure transition, and transitions spend stacks.
--
-- Laying cable is NOT a structure transition -- there is nothing on the
-- tile that owns the answer -- so it stays an on_use hook, which the
-- interpreter falls through to when no table names this item.
--
-- THE LINES. tg has three cable layers, and they are the real thing:
-- connection is gated on the layer bitflag and nothing else
-- (cable.dm:121), so three cables can share a tile and be three
-- separate circuits. The colours are a mnemonic for the layer, not a
-- mechanism -- tg's own names for them are "Red/Yellow/Blue Power
-- Line" (__DEFINES/power.dm:5,8,11), and its coil recolours itself to
-- match whichever layer you picked (cable.dm:596,602,608).
local LINES = {
    { mask = 1, name = "the red power line" },
    { mask = 2, name = "the yellow power line" },
    { mask = 4, name = "the blue power line" },
}

return {
    id = "cable_coil",
    name = "cable coil",
    sprite = "coil",
    inhand_sprite = { "held_coil_l", "held_coil_r" },
    stack = 30,
    -- Three settings, minted on the second: tg's coil defaults to
    -- CABLE_LAYER_2 (cable.dm:513), which is what the station's own
    -- branch wiring runs on.
    modes = 3,
    mode = 1,
    -- tg's "Use it in hand to change the layer you are placing on"
    -- (cable.dm:529). tg pops a radial menu there (cable.dm:589); we
    -- have no radial widget, so this cycles and says where it landed,
    -- which is the same information in one keypress instead of two.
    on_use_self = function(ctx, self, user)
        local dial = ctx.mode(self)
        local next_index = (dial.index + 1) % dial.count
        ctx.set_mode(self, next_index)
        ctx.system_msg(user, "You set the coil to " .. LINES[next_index + 1].name .. ".")
    end,
    on_use = function(ctx, self, user, x, y)
        local line = LINES[ctx.mode(self).index + 1]
        if ctx.cable(x, y) % (line.mask * 2) >= line.mask then
            return "pass" -- this line already runs here
        end
        ctx.system_msg(user, "You start laying cable...")
        if not ctx.do_after(user, 1.0) then
            ctx.system_msg(user, "You stop laying cable.")
            return
        end
        -- The same question again at the end: while you worked, another
        -- engineer may have cabled this very tile. The dial is asked
        -- again too -- a do_after is a whole second, and nothing stops
        -- you turning it mid-job.
        line = LINES[ctx.mode(self).index + 1]
        if ctx.cable(x, y) % (line.mask * 2) >= line.mask then
            ctx.system_msg(user, "Someone already ran " .. line.name .. " through there.")
            return
        end
        ctx.lay_cable(x, y, line.mask)
        ctx.system_msg(user, "You lay cable on " .. line.name .. ".")
    end,
}
