-- Floor tiles: over open space they lay structural plating (anchored —
-- the station grows outward, never floats); on bare plating they lay
-- the finished tiled floor a crowbar can pry back up.
return {
    id = "floor_tile",
    name = "floor tiles",
    sprite = "floor_tile",
    stack = 30,
    builds = {
        id = "flooring",
        label = "Flooring",
        sprite = "floor",
        target = { "space", "plating" },
        cost = 1,
        secs = 1.5,
    },
    on_use = function(ctx, self, user, x, y)
        local t = ctx.turf(x, y)
        local kind, secs, starting
        if t == "space" then
            kind, secs, starting = "plating", 1.5, "You start laying plating."
        elseif t == "plating" then
            kind, secs, starting = "floor", 0.5, "You start tiling the floor."
        else
            return "pass"
        end
        -- Checked twice against the engine's own validator: once before
        -- the work, so an impossible job never starts, and once at the
        -- end, so a job the world invalidated mid-way says why.
        local why = ctx.can_construct(user, self, x, y, kind)
        if why then
            ctx.system_msg(user, why)
            return
        end
        ctx.system_msg(user, starting)
        if not ctx.do_after(user, secs) then
            ctx.system_msg(user, "You stop building.")
            return
        end
        why = ctx.can_construct(user, self, x, y, kind)
        if why then
            ctx.system_msg(user, why)
            return
        end
        ctx.construct(self, x, y, kind)
    end,
}
