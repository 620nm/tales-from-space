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
--
-- Cable goes UNDER the deck, so the tile has to be open -- the same rule
-- pipe.luau states, and for the same tg reason (a covered turf hides its
-- contents: code/game/turfs/turf.dm:503-506). Unlike the cutters, this
-- refusal SPEAKS: you are placing something you are holding onto a floor
-- you can see, so the message describes the floor and gives away nothing
-- about what may already be buried.
return {
    id = "cable_coil",
    name = "cable coil",
    sprite = "coil",
    inhand_sprite = { "held_coil_l", "held_coil_r" },
    stack = 30,
    on_use = function(ctx, self, user, x, y)
        -- Asked first, so every covered tile answers the same way and
        -- the reply is not a probe for what is already buried.
        if ctx.turf(x, y) ~= "plating" then
            ctx.system_msg(user, "The floor is in the way. Pry the tile up first.")
            return
        end
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
