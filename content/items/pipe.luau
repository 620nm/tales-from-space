-- A length of pipe, wrenched down under the deck on whichever of the
-- five piping layers you have it set to.
--
-- Like cable, this is not a structure transition: there is nothing
-- standing on the tile that owns the answer, so it stays an on_use
-- hook. Also like cable, it needs the subfloor OPEN -- pipe lives under
-- the plating, so you pry the tile up, run the line, and put the floor
-- back. The engine refuses a finished floor; this hook says so first,
-- because a refusal with no explanation reads as a bug.
--
-- THE LAYERS. tg has five, PIPING_LAYER_MIN..MAX with
-- PIPING_LAYER_DEFAULT = 3 (__DEFINES/atmospherics/atmos_piping.dm:78-80),
-- and two pipes on different layers do not connect
-- (atmosmachinery.dm:350). They are bare numbers in tg -- there are no
-- named piping layers and no per-layer colours -- so they are bare
-- numbers here. Layer 3 is the distribution run every dispenser hands
-- you; the others exist so a second run can CROSS the first without
-- joining it.
local LAYERS = { 1, 2, 4, 8, 16 }

return {
    id = "pipe",
    name = "pipe",
    sprite = "pipe",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
    stack = 25,
    -- Five settings, minted on the third: PIPING_LAYER_DEFAULT.
    modes = 5,
    mode = 2,
    -- tg cycles a pipe item's layer 1->2->3->4->5->1 on RIGHT-CLICK
    -- (construction.dm:438-445), because attack_self is already spoken
    -- for there (it rotates the fitting). We have no secondary-click
    -- channel, so the cycle moves to the in-hand key -- same cycle,
    -- same wrap, same balloon-alert-sized message.
    on_use_self = function(ctx, self, user)
        local dial = ctx.mode(self)
        local next_index = (dial.index + 1) % dial.count
        ctx.set_mode(self, next_index)
        ctx.system_msg(user, "Pipe layer set to " .. (next_index + 1) .. ".")
    end,
    on_use = function(ctx, self, user, x, y)
        -- Asked first, so every covered tile answers the same way and
        -- the reply is not a probe for what is already buried.
        if ctx.turf(x, y) ~= "plating" then
            ctx.system_msg(user, "The floor is in the way. Pry the tile up first.")
            return
        end
        local mask = LAYERS[ctx.mode(self).index + 1]
        if ctx.pipe_occupancy(x, y) % (mask * 2) >= mask then
            ctx.system_msg(user, "An atmospherics component already occupies that pipe layer.")
            return
        end
        if ctx.pipe(x, y) % (mask * 2) >= mask then
            return "pass" -- a length already runs here on this layer
        end
        ctx.system_msg(user, "You start fitting a length of pipe...")
        if not ctx.do_after(user, 1.0) then
            ctx.system_msg(user, "You stop fitting the pipe.")
            return
        end
        -- The same question again at the end: while you worked, another
        -- engineer may have run the line through this very tile -- and
        -- you may have turned the dial yourself.
        mask = LAYERS[ctx.mode(self).index + 1]
        if ctx.pipe_occupancy(x, y) % (mask * 2) >= mask then
            ctx.system_msg(user, "An atmospherics component already occupies that pipe layer.")
            return
        end
        if ctx.pipe(x, y) % (mask * 2) >= mask then
            ctx.system_msg(user, "Someone already ran pipe through there.")
            return
        end
        -- One exact item becomes one exact length. Native code derives the
        -- layer again, preserves a pulled length's directional mask and
        -- spends this stack only if the topology actually lands.
        ctx.fasten_pipe(self, x, y, "ratchet", "You wrench the pipe into place.")
    end,
}
