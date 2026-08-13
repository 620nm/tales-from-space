-- Metal sheets, the wall material — in tg's two stages: two sheets
-- raise a girder on floor or plating (4 s), two more plate a standing
-- girder into a Wall turf (4 s). The engine validates reach, occupancy,
-- the girder, and the stack; the seam ledgers every step.
return {
    id = "metal",
    name = "metal sheets",
    sprite = "metal",
    stack = 30,
    -- Build-menu row (display data; the numbers mirror the hook below
    -- and the native validator, which stay the enforcement truth).
    builds = {
        label = "Wall (girder first)",
        sprite = "wall",
        target = { "floor", "plating" },
        cost = 2,
        secs = 4.0,
    },
    on_use = function(ctx, self, user, x, y)
        local t = ctx.turf(x, y)
        if t ~= "floor" and t ~= "plating" then
            return "pass" -- not a build site; native click handling continues
        end
        if ctx.girder(x, y) then
            ctx.system_msg(user, "You start plating the girder into a wall.")
            if ctx.do_after(user, 4.0) and ctx.girder(x, y) then
                ctx.construct(self, x, y, "wall")
            else
                ctx.system_msg(user, "You stop building.")
            end
        else
            ctx.system_msg(user, "You start assembling a girder.")
            if ctx.do_after(user, 4.0) and not ctx.girder(x, y) then
                ctx.construct(self, x, y, "girder")
            else
                ctx.system_msg(user, "You stop building.")
            end
        end
    end,
}
