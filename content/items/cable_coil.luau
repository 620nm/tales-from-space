-- Repairs what the wirecutters undo. Lays branch (consumer-spec) cable;
-- feeder work needs heavier gear and arrives with construction.
--
-- A reel is 30 lengths, tg's coil size. That count is what lets a
-- machine frame ask for five of them: wiring an assembly is a
-- structure transition, and transitions spend stacks.
--
-- Laying cable is NOT a structure transition -- there is nothing on the
-- tile that owns the answer -- so it stays an on_use hook, which the
-- interpreter falls through to when no table names this item.
return {
    id = "cable_coil",
    name = "cable coil",
    sprite = "coil",
    inhand_sprite = { "held_coil_l", "held_coil_r" },
    stack = 30,
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
