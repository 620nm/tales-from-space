-- A length of pipe, wrenched down under the deck.
--
-- Like cable, this is not a structure transition: there is nothing
-- standing on the tile that owns the answer, so it stays an on_use
-- hook. Also like cable, it needs the subfloor OPEN -- pipe lives under
-- the plating, so you pry the tile up, run the line, and put the floor
-- back. The engine refuses a finished floor; this hook says so first,
-- because a refusal with no explanation reads as a bug.
--
-- Layer masks are tg's five piping layers: 1, 2, 4, 8, 16 for layers
-- 1..5. Layer 3 (mask 4) is the distribution run every dispenser hands
-- you; the others exist so a second run can CROSS the first without
-- joining it.
local LAYER_DISTRO = 4

return {
    id = "pipe",
    name = "pipe",
    sprite = "pipe",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
    stack = 25,
    on_use = function(ctx, self, user, x, y)
        -- Asked first, so every covered tile answers the same way and
        -- the reply is not a probe for what is already buried.
        if ctx.turf(x, y) ~= "plating" then
            ctx.system_msg(user, "The floor is in the way. Pry the tile up first.")
            return
        end
        if ctx.pipe(x, y) % 8 >= 4 then
            return "pass" -- a distribution length already runs here
        end
        ctx.system_msg(user, "You start fitting a length of pipe...")
        if not ctx.do_after(user, 1.0) then
            ctx.system_msg(user, "You stop fitting the pipe.")
            return
        end
        -- The same question again at the end: while you worked, another
        -- engineer may have run the line through this very tile.
        if ctx.pipe(x, y) % 8 >= 4 then
            ctx.system_msg(user, "Someone already ran pipe through there.")
            return
        end
        ctx.lay_pipe(x, y, LAYER_DISTRO)
        ctx.sound("ratchet", x, y)
        ctx.system_msg(user, "You wrench the pipe into place.")
    end,
}
