-- The engineer's answer to a hull breach — and, since the construction
-- chain landed, the deconstruction tool: walls slice apart into their
-- girder and sheets (10 s, tg's slicing rate), standing girders cut
-- back to sheets (4 s). do_after guards revalidate every tick (alive,
-- welder still in the active hand, still in reach); no state machine
-- here, ever.
return {
    id = "welder",
    name = "welding tool",
    sprite = "welder",
    on_use = function(ctx, self, user, x, y)
        if ctx.is_breached(x, y) then
            ctx.sound("weld", x, y)
            ctx.system_msg(user, "You start welding the breach shut.")
            if ctx.do_after(user, 4.0) and ctx.is_breached(x, y) then
                ctx.seal_breach(x, y)
                ctx.system_msg(user, "You weld the breach shut.")
            else
                ctx.system_msg(user, "Your weld is interrupted.")
            end
        elseif ctx.turf(x, y) == "wall" then
            ctx.sound("weld", x, y)
            ctx.system_msg(user, "You start slicing the wall apart.")
            if ctx.do_after(user, 10.0) and ctx.turf(x, y) == "wall" then
                ctx.slice_wall(x, y)
                ctx.system_msg(user, "The wall comes apart.")
            else
                ctx.system_msg(user, "You stop slicing.")
            end
        elseif ctx.girder(x, y) then
            ctx.sound("weld", x, y)
            ctx.system_msg(user, "You start cutting the girder apart.")
            if ctx.do_after(user, 4.0) and ctx.girder(x, y) then
                ctx.cut_girder(x, y)
                ctx.system_msg(user, "The girder comes apart.")
            else
                ctx.system_msg(user, "You stop cutting.")
            end
        elseif ctx.frame(x, y) then
            ctx.sound("weld", x, y)
            ctx.system_msg(user, "You start cutting the frame apart.")
            if ctx.do_after(user, 4.0) and ctx.frame(x, y) then
                ctx.cut_frame(x, y)
                ctx.system_msg(user, "The frame comes apart.")
            else
                ctx.system_msg(user, "You stop cutting.")
            end
        else
            return "pass"
        end
    end,
}
