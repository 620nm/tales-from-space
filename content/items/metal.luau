-- Metal sheets, the structural material — tg's shapes. Walls in two
-- stages: two sheets raise a girder on floor or plating (4 s), two
-- more plate a standing girder into a Wall turf (4 s). Or, chosen from
-- the build menu, five sheets box up into a machine frame (8 s) that
-- waits for a circuit board. The engine validates reach, occupancy,
-- structures, and the stack; the seam ledgers every step.

-- One build step, checked twice. ctx.can_construct IS the engine's own
-- completion validator, so refusing before the work starts refuses for
-- exactly the reason the seam would refuse at the end — no more four
-- seconds of welding that quietly produce nothing. The second call
-- catches the world moving under a job in progress: someone steps onto
-- the tile, another builder finishes the same girder first.
local function build(ctx, item, user, x, y, kind, secs, starting)
    local why = ctx.can_construct(user, item, x, y, kind)
    if why then
        ctx.system_msg(user, why)
        return
    end
    ctx.system_msg(user, starting)
    if not ctx.do_after(user, secs) then
        ctx.system_msg(user, "You stop building.")
        return
    end
    why = ctx.can_construct(user, item, x, y, kind)
    if why then
        ctx.system_msg(user, why)
        return
    end
    ctx.construct(item, x, y, kind)
end

return {
    id = "metal",
    name = "metal sheets",
    sprite = "metal",
    stack = 30,
    -- Build-menu rows (display data; the numbers mirror the hook below
    -- and the native validator, which stay the enforcement truth).
    builds = {
        {
            id = "wall",
            label = "Wall (girder first)",
            sprite = "wall",
            target = { "floor", "plating" },
            cost = 2,
            secs = 4.0,
        },
        {
            id = "frame",
            label = "Machine frame",
            sprite = "frame",
            target = { "floor", "plating" },
            cost = 5,
            secs = 8.0,
        },
    },
    on_use = function(ctx, self, user, x, y, choice)
        local t = ctx.turf(x, y)
        if t ~= "floor" and t ~= "plating" then
            return "pass" -- not a build site; native click handling continues
        end
        if choice == "frame" then
            build(ctx, self, user, x, y, "frame", 8.0,
                "You start assembling a machine frame.")
        elseif ctx.girder(x, y) then
            build(ctx, self, user, x, y, "wall", 4.0,
                "You start plating the girder into a wall.")
        else
            build(ctx, self, user, x, y, "girder", 4.0,
                "You start assembling a girder.")
        end
    end,
}
