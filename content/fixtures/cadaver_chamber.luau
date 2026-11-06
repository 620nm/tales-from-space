-- A cadaver chamber's handlers: the closet family's close and push, without
-- the weld, lock and salvage a morgue does not have. Its lamps are scripted
-- states, so the click that opens one steps it back to `closed` first. A push
-- from inside meets a lamp only for the second until the next pass reads a corpse
-- revived in there, and goes nowhere until then (`lib/closets/chamber_watch.luau`).
-- Every open, whoever makes it, raises `container.open.done` here, and that
-- slides the contents out onto the tray's tile (`lib/closets/tray.luau`).
local breakout = require("@lib/closets/breakout")
local chamber_watch = require("@lib/closets/chamber_watch")
local closing = require("@lib/closets/closing")
local data = require("@lib/closets/data")
local tray = require("@lib/closets/tray")

local content = { id = "cadaver_chamber" }

if sim ~= nil then
    local behavior = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    behavior:handle("interaction.use", { kind = "replace", route = "interact" }, function(ev)
        if ev.gesture ~= "primary" or ev.implement ~= nil then
            return { replaced = false }
        end
        local chamber: Handle = ev.subject
        if chamber.state == data.chamber_items_state or chamber.state == data.chamber_bodies_state then
            local shown = chamber.state
            sim.appearance.set_state({ entity = chamber, state = data.closed_state })
            if sim.container.open({ container = chamber }) ~= nil then
                -- A refused open leaves the chamber as it stood.
                sim.appearance.set_state({ entity = chamber, state = shown })
            end
            return true
        end
        if chamber.state == data.open_state then
            closing.tell_refusal(ev.actor, chamber, false)
        end
        return { replaced = false }
    end)
    behavior:handle("container.resist", { kind = "replace", route = "interact" }, breakout.on_resist)
    behavior:handle("container.open.done", { kind = "react" }, tray.slide_out)
    behavior:handle("container.closing", { kind = "veto", route = "interact" }, closing.veto)
    behavior:handle("container.closing", { kind = "replace", route = "interact" }, closing.gather)
    behavior:handle("container.close.done", { kind = "react" }, function(ev: ContainerCloseDonePayload)
        closing.on_closed(ev)
        chamber_watch.start(ev.self)
    end)
end

return content
