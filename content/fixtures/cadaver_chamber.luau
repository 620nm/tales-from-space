-- A cadaver chamber's handlers: the closet family's close and push, without
-- the weld, lock and salvage a morgue does not have. Its lamps are scripted
-- states, so the click that opens one steps it back to `closed` first. A push
-- from inside meets a lamp only for the second until the next pass reads a corpse
-- revived in there, and goes nowhere until then (`lib/closets/chamber_watch.luau`).
local breakout = require("@lib/closets/breakout")
local chamber_watch = require("@lib/closets/chamber_watch")
local closing = require("@lib/closets/closing")
local data = require("@lib/closets/data")

local content = { id = "cadaver_chamber" }

if sim ~= nil then
    sim.define("sound", "lunatic/tfs:sound/cadaver_alert", { asset = "cadaver_alert" })
    local behavior = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    behavior:handle("interaction.use", { kind = "replace", route = "interact" }, function(ev)
        if ev.gesture ~= "primary" or ev.implement ~= nil then
            return { replaced = false }
        end
        local chamber: Handle = ev.subject
        if chamber.state == data.chamber_items_state or chamber.state == data.chamber_bodies_state then
            sim.appearance.set_state({ entity = chamber, state = data.closed_state })
            sim.container.open({ container = chamber })
            return true
        end
        if chamber.state == data.open_state then
            closing.tell_refusal(ev.actor, chamber, false)
        end
        return { replaced = false }
    end)
    behavior:handle("container.resist", { kind = "replace", route = "interact" }, breakout.on_resist)
    behavior:handle("container.closing", { kind = "veto", route = "interact" }, closing.veto)
    behavior:handle("container.closing", { kind = "replace", route = "interact" }, closing.gather)
    behavior:handle("container.close.done", { kind = "react" }, function(ev: ContainerCloseDonePayload)
        closing.on_closed(ev)
        chamber_watch.start(ev.self)
    end)
end

return content
