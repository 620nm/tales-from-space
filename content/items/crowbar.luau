-- The classic, both jobs: pry a floor tile off its plating (instant,
-- tile refunded — the subfloor shows), and pry open a dead airlock
-- ("pass" hands powered doors back to the native access-checked
-- toggle).
return {
    id = "crowbar",
    name = "crowbar",
    sprite = "crowbar",
    -- Two names because tg draws held items from PAIRED lefthand /
    -- righthand icon files: one per hand slot, in slot order.
    inhand_sprite = { "held_crowbar_l", "held_crowbar_r" },
    stowed_sprite = "belt_crowbar",
    -- The equipment class targets dispatch on; no tank, nothing to burn.
    tool = "crowbar",
    on_use = function(ctx, self, user, x, y)
        local door = ctx.door(x, y)
        if door == nil and ctx.turf(x, y) == "floor" then
            -- The quick pop, not the heave: tg's pry_tile calls
            -- play_tool_sound, which is `usesound` (crowbar.ogg).
            ctx.sound("crowbar", x, y)
            ctx.pry_tile(x, y)
            ctx.system_msg(user, "You pry up the floor tile.")
            return
        end
        if door == nil or door.open or door.powered then
            return "pass"
        end
        -- The sustained heave: tg's `operating_sound`, played while
        -- forcing something open (crowbar_prying.ogg).
        ctx.sound("crowbar_pry", x, y)
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
