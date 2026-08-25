-- The ceiling light. It knows three things about itself, and they are
-- all things only IT could know: what is in its socket, what a tube or
-- a replacer does to that socket, and what happens when somebody swings
-- something at the glass. No tool carries a list of the fixtures it can
-- fix (docs/CONSTRUCTION.md — the tool is equipment, the target is the
-- expert); tg dispatches the same way, through
-- `/obj/machinery/light/item_interaction` (light.dm:386).
--
-- The engine owns the half a script must not: whether a socket state
-- emits, what the room then looks like, and who is told about it.
--
-- One deliberate divergence from tg: there, hitting a fixture with an
-- ordinary item damages it and enough damage breaks the tube. We have
-- no machine integrity yet, so one swing shatters it. The ledger names
-- who swung.
-- What a fresh tube burns. tg's own default fluorescent white
-- (LIGHT_COLOR_DEFAULT "#f3fffa", code/__DEFINES/colors.dm:254; it is
-- /obj/machinery/light's `bulb_colour`, light.dm:24-28). It lives here
-- because the FITTING is what knows what went into it — the engine
-- ships no colour but white, and a tube is a game word.
local TUBE_COLOR = "#F3FFFA"

local content = {
    id = "light",

    -- Empty hand: read the ceiling.

    -- Something arrived at the fixture in somebody's hand. `target` is
    -- that item.
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "interact" }, function(ev)
        local self, user, x, y = ev.subject, ev.actor, ev.at.x, ev.at.y
        local l = sim.light(self)
        if l == nil then
            return true
        end
        if l.status == "broken" then
            sim.message.send({ recipient = user, message = "The tube is shattered in its socket." })
        elseif l.status == "empty" then
            sim.message.send({ recipient = user, message = "The fitting is empty." })
        elseif l.status == "burned" then
            sim.message.send({ recipient = user, message = "The tube is burned out." })
        elseif l.lit then
            sim.message.send({ recipient = user, message = "The light is on." })
        else
            sim.message.send({ recipient = user, message = "The light is dark. Its breaker must be out." })
        end
        return true
    end)
    script_definition:handle("attack.swing", { kind = "replace", route = "attack" }, function(ev)
        local self, user = ev.implement, ev.actor
        local target, victim, item = ev.target, ev.target, ev.target
        local info = { surgery_refusal = ev.refusal }
        local _self, _victim = self, victim
        local l = sim.light(self)
        if l == nil then
            return true
        end
        local id = target.prototype

        if id == "light_replacer" then
            if l.status == "ok" then
                sim.message.send({ recipient = user, message = "There is already a good tube in the fitting." })
                return true
            end
            -- tg's Use(): no charges, no work, and it says so
            -- (lightreplacer.dm:259).
            if (target.uses or 0) <= 0 then
                sim.message.send({ recipient = user, message = "The replacer is empty." })
                return true
            end
            target:consume()
            -- The replacer carries tubes, so the fitting comes back
            -- burning what a tube burns — a warm bulb fitting serviced
            -- out of a janitor's device turns fluorescent, exactly as
            -- it would if you did it in a real corridor.
            sim.set_light(self, "ok", TUBE_COLOR)
            sim.sound.play({ asset = "lunatic/tfs:sound/click", at = self.tile })
            sim.message.send({ recipient = user, message = "You replace the light tube." })
            return true
        end

        if id == "light_tube" then
            if l.status == "ok" then
                sim.message.send({ recipient = user, message = "There is already a tube in the fitting." })
                return true
            end
            -- Spent, not destroyed: a tube that went into a fitting is
            -- work and reads `ItemConsumed`, where `sim.entity.despawn`
            -- would file it as loss.
            target:consume()
            sim.set_light(self, "ok", TUBE_COLOR)
            sim.message.send({ recipient = user, message = "You fit the new tube." })
            return true
        end

        if id == "light_bulb" then
            -- tg light.dm:396, verbatim in spirit: the fitting takes
            -- what the fitting takes.
            sim.message.send({ recipient = user, message = "This type of light requires a tube!" })
            return true
        end

        -- Anything else is a blow. tg refuses to re-break glass that is
        -- already gone (break_light_tube, light.dm:689).
        if l.status == "broken" or l.status == "empty" then
            sim.message.send({ recipient = user, message = "There is nothing left in there to break." })
            return true
        end
        sim.set_light(self, "broken")
        sim.sound.play({ asset = "lunatic/tfs:sound/glass_break", at = self.tile })
        sim.message.send({ recipient = user, message = "You smash the light tube." })
        return true
    end)
end

return content
