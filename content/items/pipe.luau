-- A length of pipe, wrenched down under the deck on whichever of the
-- five piping layers you have it set to.
--
-- Like cable, this is not a structure transition: there is nothing
-- standing on the tile that owns the answer, so it stays an interaction.use
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

local content = {
    id = "pipe",
    name = "pipe",
    sprite = "pipe",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
    stack = 25,
    -- This IS the station's piping: what a run under the deck is made
    -- of, what a wrench may fasten into one, and what pulling one hands
    -- back. The native fasten verb used to recognise this length by its
    -- id; it reads this instead, so a pack with two kinds of pipe gets
    -- both and a pack with none gets a refusal.
    subfloor = "pipe",
    -- Five settings, minted on the third: PIPING_LAYER_DEFAULT.
    modes = 5,
    mode = 2,
    -- tg cycles a pipe item's layer 1->2->3->4->5->1 on RIGHT-CLICK
    -- (construction.dm:438-445), because attack_self is already spoken
    -- for there (it rotates the fitting). We have no secondary-click
    -- channel, so the cycle moves to the in-hand key -- same cycle,
    -- same wrap, same balloon-alert-sized message.
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        local dial = sim.mode(self)
        local next_index = (dial.index + 1) % dial.count
        sim.set_mode(self, next_index)
        sim.message.send({ recipient = user, message = "Pipe layer set to " .. (next_index + 1) .. "." })
        return true
    end)
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local clicked, target = ev.claim, ev.claim
        local _x, _y, _choice = x, y, choice
        -- Asked first, so every covered tile answers the same way and
        -- the reply is not a probe for what is already buried. Open
        -- deck, not "plating": the map decides per tile.
        if not sim.subfloor_exposed(x, y) then
            sim.message.send({ recipient = user, message = "The floor is in the way. Pry the tile up first." })
            return true
        end
        local mask = LAYERS[sim.mode(self).index + 1]
        if sim.pipe_occupancy(x, y) % (mask * 2) >= mask then
            sim.message.send({ recipient = user, message = "An atmospherics component already occupies that pipe layer." })
            return true
        end
        if sim.pipe(x, y) % (mask * 2) >= mask then
            return { replaced = false } -- a length already runs here on this layer
        end
        sim.message.send({ recipient = user, message = "You start fitting a length of pipe..." })
        sim.spawn_task(user, function()
            if sim.do_after(user, sim.ticks(1.0), {}) == "interrupted" then
                sim.message.send({ recipient = user, message = "You stop fitting the pipe." })
                return true
            end
            -- The same question again at the end: while you worked, another
            -- engineer may have run the line through this very tile -- and
            -- you may have turned the dial yourself.
            mask = LAYERS[sim.mode(self).index + 1]
            if sim.pipe_occupancy(x, y) % (mask * 2) >= mask then
                sim.message.send({ recipient = user, message = "An atmospherics component already occupies that pipe layer." })
                return true
            end
            if sim.pipe(x, y) % (mask * 2) >= mask then
                sim.message.send({ recipient = user, message = "Someone already ran pipe through there." })
                return true
            end
            -- One exact item becomes one exact length. Native code derives the
            -- layer again, preserves a pulled length's directional mask and
            -- spends this stack only if the topology actually lands.
            sim.fasten_pipe(self, x, y, "ratchet", "You wrench the pipe into place.")
        end)
        return true
    end)
end

return content
