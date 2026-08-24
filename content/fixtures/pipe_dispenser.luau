-- What the pipe dispenser DOES, as opposed to what it stocks
-- (machines/pipe_dispenser.luau).
--
-- Two behaviours, and the second is the one that makes it a dispenser
-- rather than a vending machine: it takes fittings back.
--
-- tg's `item_interaction` (code/game/machinery/pipe/
-- pipe_dispenser.dm:154-160) accepts an `/obj/item/pipe` or an
-- `/obj/item/pipe_meter`, says "You put [tool] back into [src]", and
-- `qdel`s it. There is no refund and no stock to return it to, because
-- the machine never had any — it conjures. So this is a bin that
-- happens to be shaped like a shelf, and the only reason to use it over
-- the floor is that the floor gets crowded.
--
-- WHAT COUNTS as one of its own is not a list in this file: `sim.stocks`
-- asks the machine's own shelf. So the day the heat exchanger joins the
-- roster it is recyclable too, with no edit here — and a softdrinks
-- machine, which does not run this script, still cannot swallow a pump.
local content = {
    id = "pipe_dispenser",
    name = "pipe dispenser",
    sprite = "pipe_dispenser",
    -- The item is the thing swung; `self` is the machine. The target is
    -- the expert about what a swing means to it (docs/CONSTRUCTION.md),
    -- and this machine's answer is "I'll take that back".
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "interact" }, function(ev)
        local self, user, x, y = ev.subject, ev.actor, ev.at.x, ev.at.y
        if not sim.is_powered(self) then
            sim.message.send({ recipient = user, message = "The dispenser is dark and silent." })
            return true
        end
        ui.open({ viewer = user, owner = self })
        return true
    end)
    script_definition:handle("attack.swing", { kind = "replace", route = "attack" }, function(ev)
        local self, user = ev.implement, ev.actor
        local target, victim, item = ev.target, ev.target, ev.target
        local info = { surgery_refusal = ev.refusal }
        local _self, _victim = self, victim
        local id = item.prototype
        if not id or not sim.stocks(self, id) then
            return { replaced = false } -- not ours; let the click mean whatever else it means
        end
        if not sim.is_powered(self) then
            sim.message.send({ recipient = user, message = "The dispenser is dark and silent." })
            return true
        end
        local x, y = self.tile.x, self.tile.y
        sim.entity.despawn({ entity = item })
        sim.sound.play({ asset = "lunatic/tfs:sound/vend", at = ev.at })
        sim.message.send({ recipient = user, message = "You put the " .. item.name .. " back into the dispenser." })
        return true
    end)
end

return content
