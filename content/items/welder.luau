-- The engineer's answer to a hull breach — and the first customer of
-- ctx.do_after: the engine revalidates every tick (alive, welder still
-- in the active hand, still in reach); no state machine here, ever.
return {
    id = "welder",
    name = "welding tool",
    sprite = "welder",
    on_use = function(ctx, self, user, x, y)
        if not ctx.is_breached(x, y) then
            return "pass" -- not our business; native click handling continues
        end
        ctx.sound("weld", x, y)
        ctx.system_msg(user, "You start welding the breach shut.")
        if ctx.do_after(user, 4.0) and ctx.is_breached(x, y) then
            ctx.seal_breach(x, y)
            ctx.system_msg(user, "You weld the breach shut.")
        else
            ctx.system_msg(user, "Your weld is interrupted.")
        end
    end,
}
