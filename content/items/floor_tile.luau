-- Floor tiles: over open space they lay structural plating (anchored —
-- the station grows outward, never floats); on bare plating they lay
-- the finished tiled floor a crowbar can pry back up.
return {
    id = "floor_tile",
    name = "floor tiles",
    sprite = "floor_tile",
    stack = 30,
    builds = {
        label = "Flooring",
        sprite = "floor",
        target = { "space", "plating" },
        cost = 1,
        secs = 1.5,
    },
    on_use = function(ctx, self, user, x, y)
        local t = ctx.turf(x, y)
        if t == "space" then
            ctx.system_msg(user, "You start laying plating.")
            if ctx.do_after(user, 1.5) and ctx.turf(x, y) == "space" then
                ctx.construct(self, x, y, "plating")
            else
                ctx.system_msg(user, "You stop building.")
            end
        elseif t == "plating" then
            ctx.system_msg(user, "You start tiling the floor.")
            if ctx.do_after(user, 0.5) and ctx.turf(x, y) == "plating" then
                ctx.construct(self, x, y, "floor")
            else
                ctx.system_msg(user, "You stop building.")
            end
        else
            return "pass"
        end
    end,
}
