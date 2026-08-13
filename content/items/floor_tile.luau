-- Floor tiles: click open space beside the station's edge to lay
-- plating (one tile each). New floors need an anchor — an adjacent
-- floor or wall — so the station grows outward, never floats.
return {
    id = "floor_tile",
    name = "floor tiles",
    sprite = "floor_tile",
    stack = 30,
    builds = { label = "Plating", sprite = "floor", target = "space", cost = 1, secs = 1.5 },
    on_use = function(ctx, self, user, x, y)
        if ctx.turf(x, y) ~= "space" then
            return "pass"
        end
        ctx.system_msg(user, "You start laying plating.")
        if ctx.do_after(user, 1.5) and ctx.turf(x, y) == "space" then
            ctx.construct(self, x, y, "floor")
        else
            ctx.system_msg(user, "You stop building.")
        end
    end,
}
