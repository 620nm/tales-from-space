-- The classic, both jobs: pry a floor tile off its plating (instant,
-- tile refunded — the subfloor shows), and pry open a dead airlock
-- ("pass" hands powered doors back to the native access-checked
-- toggle).
return {
    id = "crowbar",
    name = "crowbar",
    sprite = "crowbar",
    on_use = function(ctx, self, user, x, y)
        local door = ctx.door(x, y)
        if door == nil and ctx.turf(x, y) == "floor" then
            ctx.sound("crowbar", x, y)
            ctx.pry_tile(x, y)
            ctx.system_msg(user, "You pry up the floor tile.")
            return
        end
        if door == nil or door.open or door.powered then
            return "pass"
        end
        ctx.sound("crowbar", x, y)
        ctx.system_msg(user, "You jam the crowbar into the airlock and heave...")
        if ctx.do_after(user, 2.5) then
            local d = ctx.door(x, y)
            if d ~= nil and not d.open and not d.powered then
                ctx.pry_door(x, y)
                ctx.system_msg(user, "The door gives way.")
            end
        else
            ctx.system_msg(user, "You lose your grip on the crowbar.")
        end
    end,
}
