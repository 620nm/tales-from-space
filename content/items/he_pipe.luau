-- A length of heat-exchanging pipe: the run you lay when you WANT the
-- room to feel what is inside it.
--
-- tg's `/obj/machinery/atmospherics/pipe/heat_exchanging/simple`
-- (heat_exchange/simple.dm, he_pipes.dm). Ordinary pipe is a sealed
-- tube that trades nothing with the deck it is buried under. This is the
-- opposite piece of kit: thin-walled, matte grey, and every pass it
-- conducts with the air of the tile above it at tg's window
-- coefficient -- 0.1, `WINDOW_HEAT_TRANSFER_COEFFICIENT`
-- (__DEFINES/atmospherics/atmos_core.dm:122) -- once the two differ by
-- more than 20 K (`minimum_temperature_difference`, he_pipes.dm:2).
-- That deadband is why a run at room temperature does nothing at all,
-- and why a freezer loop laid through a hot room bleeds it dry.
--
-- IT JOINS ONLY ITSELF (tg's `HE_type_check`, he_pipes.dm:18-21). A
-- heat-exchange run and a distribution main can touch end to end on one
-- layer and stay two networks, which is what the junction is for
-- (structures/he_junction.luau).
--
-- IT TAKES NO PAINT. tg fixes the colour at `#404040` outright
-- (`add_atom_colour(..., FIXED_COLOUR_PRIORITY)`, he_pipes.dm:15), and a
-- thing with a colour of its own has no second colour to be -- the same
-- rule the colour adapter keeps. The painter says so.
--
-- THREE LAYERS, not five: tg's sheets carry piping layers 2, 3 and 4 and
-- no others (`he-simple.dmi`), so those are the ones this fits.
local LAYERS = { 2, 3, 4 }

local content = {
    id = "he_pipe",
    name = "heat-exchanging pipe",
    sprite = "he_pipe",
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
    stack = 25,
    subfloor = "pipe",
    -- What makes this a KIND rather than a second id for the same thing
    -- (../lunatic/docs/content-schema/subfloor.md): its own art family,
    -- its own colour, the layers it fits, and the law it conducts by.
    pipe = {
        sprite = "he_pipe",
        color = "#404040",
        layers = LAYERS,
        conducts = { coefficient = 0.1, min_delta_k = 20 },
    },
    -- The engine's dial is the piping layer, 1..5, and this fits three
    -- of them; the cycle below walks those three. Minted on layer 3,
    -- PIPING_LAYER_DEFAULT, like everything else off the shelf.
    modes = 5,
    mode = 2,
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        local layer = sim.mode(self).index + 1
        -- 2 -> 3 -> 4 -> 2. Ordinary pipe wraps 1..5; this wraps the
        -- three tg drew art for, so the dial never stops somewhere the
        -- wrench would refuse.
        local next_layer = LAYERS[1]
        for i, candidate in ipairs(LAYERS) do
            if candidate == layer then
                next_layer = LAYERS[(i % #LAYERS) + 1]
                break
            end
        end
        sim.set_mode(self, next_layer - 1)
        sim.message.send({ recipient = user, message = "Pipe layer set to " .. next_layer .. "." })
        return true
    end)
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local clicked, target = ev.claim, ev.claim
        local _x, _y, _choice = x, y, choice
        if not sim.subfloor_exposed(x, y) then
            sim.message.send({ recipient = user, message = "The floor is in the way. Pry the tile up first." })
            return true
        end
        local layer = sim.mode(self).index + 1
        local mask = 2 ^ (layer - 1)
        if sim.pipe_occupancy(x, y) % (mask * 2) >= mask then
            sim.message.send({ recipient = user, message = "An atmospherics component already occupies that pipe layer." })
            return true
        end
        if sim.pipe(x, y) % (mask * 2) >= mask then
            return { replaced = false } -- a length already runs here on this layer
        end
        sim.message.send({ recipient = user, message = "You start fitting a length of heat-exchanging pipe..." })
        sim.spawn_task(user, function()
            if sim.do_after(user, sim.ticks(1.0), {}) == "interrupted" then
                sim.message.send({ recipient = user, message = "You stop fitting the pipe." })
                return true
            end
            layer = sim.mode(self).index + 1
            mask = 2 ^ (layer - 1)
            if sim.pipe_occupancy(x, y) % (mask * 2) >= mask then
                sim.message.send({ recipient = user, message = "An atmospherics component already occupies that pipe layer." })
                return true
            end
            if sim.pipe(x, y) % (mask * 2) >= mask then
                sim.message.send({ recipient = user, message = "Someone already ran pipe through there." })
                return true
            end
            -- The native verb reads the KIND off this very item, the same
            -- field read the other way when a length is pulled back up.
            sim.fasten_pipe(self, x, y, "ratchet", "You wrench the heat-exchanging pipe into place.")
        end)
        return true
    end)
end

return content
