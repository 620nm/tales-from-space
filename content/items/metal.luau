-- Metal sheets: click a clear floor tile beside you to raise a wall
-- (two sheets each). The engine validates reach, occupancy, and the
-- stack; the seam ledgers the new wall like every turf change.
return {
    id = "metal",
    name = "metal sheets",
    sprite = "metal",
    stack = 30,
    -- Build-menu row (display data; the numbers mirror the hook below
    -- and the native validator, which stay the enforcement truth).
    builds = { label = "Wall", sprite = "wall", target = "floor", cost = 2, secs = 2.0 },
    on_use = function(ctx, self, user, x, y)
        if ctx.turf(x, y) ~= "floor" then
            return "pass" -- not a build site; native click handling continues
        end
        ctx.system_msg(user, "You start building a wall.")
        if ctx.do_after(user, 2.0) and ctx.turf(x, y) == "floor" then
            ctx.construct(self, x, y, "wall")
        else
            ctx.system_msg(user, "You stop building.")
        end
    end,
}
