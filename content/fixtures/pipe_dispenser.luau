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
-- WHAT COUNTS as one of its own is not a list in this file: `ctx.stocks`
-- asks the machine's own shelf. So the day the heat exchanger joins the
-- roster it is recyclable too, with no edit here — and a softdrinks
-- machine, which does not run this script, still cannot swallow a pump.
return {
    id = "pipe_dispenser",
    name = "pipe dispenser",
    sprite = "pipe_dispenser",
    on_interact = function(ctx, self, user)
        if not ctx.is_powered(self) then
            ctx.system_msg(user, "The dispenser is dark and silent.")
            return
        end
        ctx.open_ui(user, self)
    end,
    -- The item is the thing swung; `self` is the machine. The target is
    -- the expert about what a swing means to it (docs/CONSTRUCTION.md),
    -- and this machine's answer is "I'll take that back".
    on_attack = function(ctx, self, user, item)
        local id = ctx.item_id(item)
        if not id or not ctx.stocks(self, id) then
            return "pass" -- not ours; let the click mean whatever else it means
        end
        if not ctx.is_powered(self) then
            ctx.system_msg(user, "The dispenser is dark and silent.")
            return
        end
        local x, y = ctx.pos(self)
        ctx.consume(item)
        ctx.sound("vend", x, y)
        ctx.system_msg(user, "You put the " .. ctx.name(item) .. " back into the dispenser.")
    end,
}
