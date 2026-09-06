-- WHAT ONE DEVICE SAYS TO ANOTHER over the station's own network, in
-- one place.
--
-- The engine carries a table from a node to the nodes that can hear it
-- and says nothing about what is in it (docs/luau-api/devices.md): the
-- payload is data, and the words in it are entirely this pack's. Which
-- means the words have to be agreed somewhere, because an air alarm
-- writing "unbreathable" and a light fixture reading "unbreathable"
-- are two files that must not be allowed to drift apart. This is that
-- somewhere, and it is the whole reason `content/lib/` exists
-- (AGENTS.md).
--
-- TWO SENTENCES ARE SPOKEN ON THIS STATION, and no more:
--
--   * a HAZARD REPORT -- a vent or a scrubber saying what the air on
--     its own tile just became. The engine decides the band on the
--     atmos cadence against `content/tuning.luau`'s numbers
--     (docs/atmos/hazard-sensing.md); the fixture merely repeats it to
--     whoever is listening.
--   * a LIGHT FLAG -- a set or a clear of one named condition on the
--     lights that can hear it. It carries no colour and no brightness,
--     only the NAME of the condition, so what a flag looks like is
--     decided once, below, and a retune reaches every fitting already
--     burning it.
--
-- NEITHER IS ADDRESSED. An emitter cannot name a recipient and there is
-- no channel to subscribe to: who hears a thing is the shape of the
-- device forest and nothing else, one hop up and one hop down. That is
-- why an alarm's flags reach the room's lights -- they hang off the
-- same APC the alarm does, so they are its siblings -- and why they do
-- not reach the next room's.
local netmsg = {}

-- The `kind` word every payload leads with. A listener that does not
-- recognise the kind drops the message, which is what lets a third
-- sentence be added later without auditing every handler.
netmsg.LIGHT_FLAG = "light.flag" -- { kind, op = "set" | "clear", flag }
netmsg.ATMOS_HAZARD = "atmos.hazard" -- { kind, level, previous }

-- WHAT EACH CONDITION DOES TO A TUBE, and which one wins when two of
-- them are standing at once.
--
-- `color` nil means "leave the tube its own colour" -- a fitting under
-- a flag that only dims keeps the white or the tungsten somebody
-- screwed into it. `power` is tg's `bulb_power` (light.dm:24-26), the
-- unflagged fitting's own being the 1.0 its prototype declares
-- (structures/light.luau). `range` is deliberately untouched: a room
-- warning you about the air should not also shrink to a puddle around
-- each fixture, because then you cannot see the door.
--
-- The colours are pack judgements. RED for air that kills, which is
-- the one alarm colour nobody has to be taught. BLUE for air that
-- merely cannot be breathed, because a blue room reads as a different
-- emergency from a fire and a crewman coming through the door should
-- be able to tell which one they have walked into. NOTHING for a
-- station on its reserve: the lights just go down, which is what
-- happens in a building running off batteries and needs no explaining.
--
-- `importance` is the whole tie-break. It is a total order over a
-- SMALL closed set on purpose -- a flag stack is not a priority queue,
-- it is three conditions and a rule about which is worse.
netmsg.flags = {
    deadly = { color = "#FF2020", power = 1.5, importance = 100 },
    unbreathable = { color = "#3060FF", power = 1.2, importance = 50 },
    low_power = { power = 0.5, importance = 10 },
}

-- One flag, set or cleared. The name is checked by the listener rather
-- than here: a sender is entitled to be wrong and a fitting is not
-- entitled to trust it.
function netmsg.light_flag(op, flag)
    return { kind = netmsg.LIGHT_FLAG, op = op, flag = flag }
end

-- One band crossing, in the engine's own three words. `previous` rides
-- along because a listener that missed a delivery can still tell which
-- way the air is going.
function netmsg.hazard(level, previous)
    return { kind = netmsg.ATMOS_HAZARD, level = level, previous = previous }
end

-- Is this thing a light flag, and a well-formed one? Anything that
-- reaches a handler came over the network, and a network is exactly
-- where a payload arrives from something that is not what it claims to
-- be -- a hand-built script on a spliced-in board, or simply an older
-- version of this pack. So the shape is checked at the door: the kind,
-- an operation from the closed pair, and a flag name this file has an
-- answer for.
function netmsg.is_light_flag(payload)
    if type(payload) ~= "table" or payload.kind ~= netmsg.LIGHT_FLAG then
        return false
    end
    if payload.op ~= "set" and payload.op ~= "clear" then
        return false
    end
    return netmsg.flags[payload.flag] ~= nil
end

-- The worst flag standing, or nil for none. `flags` is a set of names
-- -- `{ deadly = true }` -- because the only thing a fitting remembers
-- is WHICH conditions it was told about, never what they look like.
--
-- Ties break on the name so that two flags of equal importance always
-- pick the same one; `pairs` over a table has no order to rely on, and
-- a picture that flickered with the iteration order would be a bug
-- nobody could reproduce.
function netmsg.winner(flags)
    if type(flags) ~= "table" then
        return nil
    end
    local best, best_name = nil, nil
    for name, on in pairs(flags) do
        local spec = on and netmsg.flags[name] or nil
        if spec ~= nil then
            if best == nil
                or spec.importance > best.importance
                or (spec.importance == best.importance and name < best_name)
            then
                best, best_name = spec, name
            end
        end
    end
    return best, best_name
end

-- What a roster of hazard levels amounts to, as the two flags a light
-- understands. `levels` is address -> level; one room on fire is
-- enough to raise the flag for the whole roster, because the roster is
-- a room's worth of machines and a light cannot be red in one corner.
function netmsg.hazard_flags(levels)
    local out = { deadly = false, unbreathable = false }
    for _, level in pairs(levels) do
        if level == "deadly" then
            out.deadly = true
        elseif level == "unbreathable" then
            out.unbreathable = true
        end
    end
    return out
end

-- The whole of what a vent and a scrubber do with the band the engine
-- just sorted their tile into: repeat it, and let the room's alarm
-- decide what it means. Written once here rather than twice there,
-- which is the rule for a gesture two roster files would otherwise
-- spell out (AGENTS.md); the `Definition:handle` naming it still lives
-- in each fixture file, because `lib/` may not define anything.
function netmsg.report_hazard(ev)
    sim.link.emit({
        subject = ev.self,
        payload = netmsg.hazard(ev.level, ev.previous),
    })
end

return netmsg
