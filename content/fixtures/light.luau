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

-- THE FLAG STACK, and why it is a stack rather than a colour.
--
-- A fitting is told about CONDITIONS, one at a time and by name -- the
-- air is deadly, the air cannot be breathed, the panel is down to its
-- cell -- and any number of them can stand at once. What it burns is
-- the worst of them (lib/netmsg.luau), and what it goes back to when
-- the last one clears is the colour of the tube somebody screwed in.
--
-- So a fitting remembers three things and none of them is a picture:
-- `base` and `base_power`, which are the tube it has in it, and
-- `flags`, one row per condition holding the set of ADDRESSES that
-- raised it. Colours and brightnesses are looked up fresh every time,
-- which is what makes a retune in `lib/netmsg.luau` reach every
-- fitting already burning one -- and what stops a light that has been
-- red since before somebody's edit from staying a shade nothing names
-- any more.
--
-- THE ROWS ARE KEYED BY EMITTER because a room can have two alarms on
-- it, and one of them finding its own patch of air breathable must not
-- take the other's word off the ceiling. It also bounds what a hostile
-- sibling can do to exactly the row it holds.
--
-- `base_power` is captured rather than assumed: a fitting's own power
-- is what its prototype declares, a mapper may one day vary it, and a
-- flag clearing back to a literal 1.0 would quietly re-tune every
-- fitting that was not 1.0 to begin with.
local function relight(self, base, flags, base_power)
    local v = self.vars["light_flags"] or {}
    base = base or v.base
    base_power = base_power or v.base_power
    flags = flags or v.flags or {}
    if base == nil or base_power == nil then
        -- The first flag on a fitting nobody has flagged yet: what it
        -- is burning NOW is the tube, because nothing has replaced it.
        local l = sim.light(self)
        base = base or (l and l.color)
        base_power = base_power or (l and l.power)
    end
    self.vars["light_flags"] = { base = base, base_power = base_power, flags = flags }
    -- `status` is deliberately absent from the set: what is in the
    -- socket is the fitting's own business and a flag has no opinion
    -- about it. A shattered tube under a standing flag stays shattered
    -- and stays dark.
    local worst = netmsg.winner(flags)
    sim.set_light(self, {
        color = worst and worst.color or base,
        power = worst and worst.power or base_power,
    })
end

if sim ~= nil then
    -- The stack, on the fitting itself. `server` rather than `sight`:
    -- nothing draws it, the colour it comes to is already on the wire
    -- as light, and the shift record is where somebody asking why
    -- Medical was red goes looking.
    sim.define("script_var", "lunatic/tfs:light_flags", { replicate = "server" })
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    -- WHAT A FITTING LISTENS TO: `parent` and `sibling`, and nothing
    -- else. That is the panel feeding it and everything else that
    -- panel feeds, which is precisely the room. A `child` would be
    -- something joined to a light and nothing can be; a `grandchild`
    -- or a `sibling_child` is another room's plant reaching across a
    -- router, and one room's air alarm has no business dimming another
    -- room's corridor (docs/luau-api/devices.md).
    --
    -- The payload is checked before it is believed. It arrived over a
    -- network, which is exactly where a table turns up claiming to be
    -- something it is not.
    script_definition:handle("link.message.done", { kind = "react" }, function(ev)
        if ev.relation ~= "parent" and ev.relation ~= "sibling" then
            return
        end
        if not netmsg.is_light_flag(ev.payload) then
            return
        end
        local self = ev.self
        local v = self.vars["light_flags"] or {}
        local flags = v.flags or {}
        local name = ev.payload.flag
        local held = flags[name] or {}
        local on = ev.payload.op == "set"
        if (held[ev.from] == true) == on then
            -- A repeat of what this sender already said. It relights
            -- nothing and writes nothing.
            return
        end
        -- `nil` rather than `false` throughout: a row is the set of
        -- addresses holding a flag, and an address that let go needs no
        -- entry saying so -- nor does a row nobody is holding.
        held[ev.from] = on or nil
        flags[name] = if next(held) ~= nil then held else nil
        relight(self, v.base, flags, v.base_power)
    end)

    script_definition:handle("interaction.use", { kind = "replace", route = "interact" }, function(ev)
        local self, user, x, y = ev.subject, ev.actor, ev.at.x, ev.at.y
        local l = sim.light(self)
        if l == nil then
            return true
        end
        if l.status == "broken" then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:fixtures.light.the_tube_is_shattered_in", {}),
            })
        elseif l.status == "empty" then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:fixtures.light.the_fitting_is_empty", {}),
            })
        elseif l.status == "burned" then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:fixtures.light.the_tube_is_burned_out", {}),
            })
        elseif l.lit then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:fixtures.light.the_light_is_on", {}),
            })
        else
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:fixtures.light.the_light_is_dark_its", {}),
            })
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
                sim.message.send({
                    recipient = user,
                    message = sim.msg("lunatic/tfs:fixtures.light.there_is_already_a_good", {}),
                })
                return true
            end
            -- tg's Use(): no charges, no work, and it says so
            -- (lightreplacer.dm:259).
            if (target.uses or 0) <= 0 then
                sim.message.send({
                    recipient = user,
                    message = sim.msg("lunatic/tfs:fixtures.light.the_replacer_is_empty", {}),
                })
                return true
            end
            target:consume()
            -- The replacer carries tubes, so the fitting comes back
            -- burning what a tube burns — a warm bulb fitting serviced
            -- out of a janitor's device turns fluorescent, exactly as
            -- it would if you did it in a real corridor.
            sim.set_light(self, { status = "ok", color = TUBE_COLOR })
            -- The new tube is the new base, and a fitting refitted
            -- under a standing flag comes back burning that flag
            -- rather than fluorescent white for a pass.
            relight(self, TUBE_COLOR)
            sim.sound.play({ asset = "lunatic/tfs:sound/click", at = self.tile })
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:fixtures.light.you_replace_the_light_tube", {}),
            })
            return true
        end

        if id == "light_tube" then
            if l.status == "ok" then
                sim.message.send({
                    recipient = user,
                    message = sim.msg("lunatic/tfs:fixtures.light.there_is_already_a_tube", {}),
                })
                return true
            end
            -- Spent, not destroyed: a tube that went into a fitting is
            -- work and reads `ItemConsumed`, where `sim.entity.despawn`
            -- would file it as loss.
            target:consume()
            sim.set_light(self, { status = "ok", color = TUBE_COLOR })
            relight(self, TUBE_COLOR)
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:fixtures.light.you_fit_the_new_tube", {}),
            })
            return true
        end

        if id == "light_bulb" then
            -- tg light.dm:396, verbatim in spirit: the fitting takes
            -- what the fitting takes.
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:fixtures.light.this_type_of_light_requires", {}),
            })
            return true
        end

        -- Anything else is a blow. tg refuses to re-break glass that is
        -- already gone (break_light_tube, light.dm:689).
        if l.status == "broken" or l.status == "empty" then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:fixtures.light.there_is_nothing_left_in", {}),
            })
            return true
        end
        sim.set_light(self, { status = "broken" })
        sim.sound.play({ asset = "lunatic/tfs:sound/glass_break", at = self.tile })
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:fixtures.light.you_smash_the_light_tube", {}),
        })
        return true
    end)
end

return content
