-- The ceiling light. It knows three things about itself, and they are
-- all things only IT could know: what is in its socket, what a tube or
-- a replacer does to that socket, and what happens when somebody swings
-- something at the glass. No tool carries a list of the fixtures it can
-- fix (docs/construction.md — the tool is equipment, the target is the
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

return {
    id = "light",

    -- Empty hand: read the ceiling.
    on_interact = function(ctx, self, user)
        local l = ctx.light(self)
        if l == nil then
            return
        end
        if l.status == "broken" then
            ctx.system_msg(user, "The tube is shattered in its socket.")
        elseif l.status == "empty" then
            ctx.system_msg(user, "The fitting is empty.")
        elseif l.status == "burned" then
            ctx.system_msg(user, "The tube is burned out.")
        elseif l.lit then
            ctx.system_msg(user, "The light is on.")
        else
            ctx.system_msg(user, "The light is dark. Its breaker must be out.")
        end
    end,

    -- Something arrived at the fixture in somebody's hand. `target` is
    -- that item.
    on_attack = function(ctx, self, user, target)
        local l = ctx.light(self)
        if l == nil then
            return
        end
        local id = ctx.item_id(target)

        if id == "light_replacer" then
            if l.status == "ok" then
                ctx.system_msg(user, "There is already a good tube in the fitting.")
                return
            end
            -- tg's Use(): no charges, no work, and it says so
            -- (lightreplacer.dm:259).
            if (ctx.uses(target) or 0) <= 0 then
                ctx.system_msg(user, "The replacer is empty.")
                return
            end
            ctx.consume(target)
            -- The replacer carries tubes, so the fitting comes back
            -- burning what a tube burns — a warm bulb fitting serviced
            -- out of a janitor's device turns fluorescent, exactly as
            -- it would if you did it in a real corridor.
            ctx.set_light(self, "ok", TUBE_COLOR)
            ctx.sound("click", ctx.pos(self))
            ctx.system_msg(user, "You replace the light tube.")
            return
        end

        if id == "light_tube" then
            if l.status == "ok" then
                ctx.system_msg(user, "There is already a tube in the fitting.")
                return
            end
            ctx.consume(target)
            ctx.set_light(self, "ok", TUBE_COLOR)
            ctx.system_msg(user, "You fit the new tube.")
            return
        end

        if id == "light_bulb" then
            -- tg light.dm:396, verbatim in spirit: the fitting takes
            -- what the fitting takes.
            ctx.system_msg(user, "This type of light requires a tube!")
            return
        end

        -- Anything else is a blow. tg refuses to re-break glass that is
        -- already gone (break_light_tube, light.dm:689).
        if l.status == "broken" or l.status == "empty" then
            ctx.system_msg(user, "There is nothing left in there to break.")
            return
        end
        ctx.set_light(self, "broken")
        ctx.sound("glass_break", ctx.pos(self))
        ctx.system_msg(user, "You smash the light tube.")
    end,
}
