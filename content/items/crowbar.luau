-- The classic, both jobs: pry a floor tile off its plating (instant,
-- tile refunded — the subfloor shows), and pry open a dead airlock
-- ("pass" hands powered doors back to the native access-checked
-- toggle).
local content = {
    id = "crowbar",
    name = "crowbar",
    sprite = "crowbar",
    -- Two names because tg draws held items from PAIRED lefthand /
    -- righthand icon files: one per hand slot, in slot order.
    inhand_sprite = { "held_crowbar_l", "held_crowbar_r" },
    stowed_sprite = "belt_crowbar",
    -- Handling, not use: `crowbar`/`crowbar_pry` above are the noises it
    -- makes DOING something. tg crowbar.dm:19-20.
    pickup_sound = "crowbar_pickup",
    drop_sound = "crowbar_drop",
    -- The equipment class targets dispatch on; no tank, nothing to burn.
    tool = "crowbar",
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local clicked, target = ev.claim, ev.claim
        local _x, _y, _choice = x, y, choice
        -- The server appends the validated clicked atom after the
        -- legacy choice slot. nil is turf; a door record means this
        -- exact authoritative door was named, never rediscovered from
        -- an otherwise target-less tile click.
        local door = nil
        if target ~= nil and target.kind == "door" then
            door = sim.door(x, y)
        end
        if target == nil and sim.turf(x, y) == "floor" then
            -- The quick pop, not the heave: tg's pry_tile calls
            -- play_tool_sound, which is `usesound` (crowbar.ogg).
            sim.sound.play({ asset = "lunatic/tfs:sound/crowbar", at = ev.at })
            sim.pry_tile(x, y)
            sim.message.send({ recipient = user, message = "You pry up the floor tile." })
            return true
        end
        if door == nil or door.open or door.powered then
            return { replaced = false }
        end
        -- The sustained heave: tg's `operating_sound`, played while
        -- forcing something open (crowbar_prying.ogg).
        sim.sound.play({ asset = "lunatic/tfs:sound/crowbar_pry", at = ev.at })
        sim.message.send({ recipient = user, message = "You jam the crowbar into the airlock and heave..." })
        sim.spawn_task(user, function()
            if sim.do_after(user, sim.ticks(2.5), {}) == "ok" then
                local d = sim.door(x, y)
                if d ~= nil and not d.open and not d.powered then
                    sim.pry_door(x, y)
                    sim.message.send({ recipient = user, message = "The door gives way." })
                end
            else
                sim.message.send({ recipient = user, message = "You lose your grip on the crowbar." })
            end
        end)
        return true
    end)
end

return content
