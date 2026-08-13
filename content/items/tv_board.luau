-- Every chill room needs one. The mainboard that makes a machine
-- frame a television — corded: no powered outlet in range, no reruns.
return {
    id = "tv_board",
    name = "machine board (television)",
    sprite = "board",
    deploys = "tv",
    builds = {
        id = "install",
        label = "Television",
        sprite = "tv",
        target = "frame",
        cost = 1,
        secs = 2.0,
    },
    on_use = function(ctx, self, user, x, y)
        if not ctx.frame(x, y) then
            return "pass"
        end
        ctx.system_msg(user, "You slot the board into the frame and secure it.")
        if ctx.do_after(user, 2.0) and ctx.frame(x, y) then
            ctx.deploy(self, x, y)
        else
            ctx.system_msg(user, "You stop assembling.")
        end
    end,
}
