-- The air alarm, and the one thing about it that is not mechanism.
--
-- Everything a player DOES to one is native: the `link` module draws
-- the address, the state, the lock, the roster and the candidates, and
-- the `reach` module draws the settings of every machine joined to it
-- (docs/TGUI.md). There is deliberately no hook here that joins,
-- releases, unlocks or sets anything -- a second path to any of those
-- would be a second answer to who may.
--
-- What is left is a sentence, and it is `lib/network.luau`'s, said with
-- this box's nouns: a hub carries devices, and the devices an alarm
-- carries are the room's fans. The access point and the router are the
-- other two callers and differ in exactly those two words
-- (fixtures/access_point.luau, fixtures/network_router.luau).
--
-- WHAT IT DOES WITH WHAT IT HEARS is the second half, and the only
-- half that is a judgement. The engine sorts the air on each powered
-- fan's own tile into three words and hands the fan a band crossing
-- (docs/atmos/hazard-sensing.md); the fan repeats it onto the network
-- (fixtures/vent.luau); this box turns the room into light. That
-- division is deliberate: a fan reports the tile it stands on and has
-- no idea whether the ROOM is in trouble, an alarm can see the whole
-- room and does, and a fitting burns whatever it is told to. Nobody
-- along that chain knows more than their own job.
--
-- IT REMEMBERS NOTHING ABOUT THE AIR, and that is the load-bearing
-- decision. A delivery is a NUDGE, not a fact to file: what the box
-- does with one is go and read every fixture it can reach
-- (`sim.query.link_reach`, which is exactly its children, its parent
-- and its siblings) and ask each what band it last sorted its own
-- tile into (`sim.hazard_level`). A remembered roster keyed by
-- address would be a second copy of the truth, and every way of
-- losing a fan -- unbolted, unpowered, joined to somebody else's
-- console -- would leave its last word standing in here forever with
-- nothing able to withdraw it. Reading instead means a fan that is
-- gone is simply not in the answer.
--
-- The only thing it does keep is the pair of bools it last PUT ON THE
-- WIRE, so that a room holding steady says nothing. `dirty` beside
-- them is the one repair: an emission the network refused never
-- reached anybody, so the next nudge must say the whole standing
-- state again rather than a difference against a message nobody got.
--
-- IT IS NOT A RADIO RELAY, and that is the deliberate difference from
-- the other two boxes on this network. A tower, a wall box and a router
-- each do something to a `;` line crossing them (lib/radio_relay.luau);
-- an air alarm is a room's plumbing console and carries no speech, so
-- it registers neither stage and a line reaching it stops there.
--
-- It rides `interaction.use.done` rather than `interaction.use` for the
-- access point's reason: the decision anchor is where a handler
-- REPLACES the click, and replacing this one would eat both the panel
-- and the crowbar.
local content = {
    id = "air_alarm",
}

local NOUN = "air alarm"
local MEMBER = "machine"

-- The two flags this box can raise, in the order it announces them.
-- Written out rather than iterated off `netmsg.flags`, because that
-- table holds one flag an alarm has no business touching -- the
-- panel's own reserve -- and because a fixed order makes the emissions
-- for one delivery reproducible.
local BANDS = { "deadly", "unbreathable" }

-- What the room amounts to, read fresh off everything within one hop
-- of this box. Anything that does not sense the air answers nil and
-- is skipped, which is most of what a panel feeds -- a fitting, a
-- port, another alarm.
local function derive(self)
    local out = { deadly = false, unbreathable = false }
    for _, node in ipairs(sim.query.link_reach(self)) do
        local level = sim.hazard_level(node)
        if level == "deadly" then
            out.deadly = true
        elseif level == "unbreathable" then
            out.unbreathable = true
        end
    end
    return out
end

if sim ~= nil then
    -- Two bools and a repair bit: what this box last put on the wire.
    -- Bounded by construction rather than by a roster's length, which
    -- is the other reason not to keep one (docs/luau-api/script-vars.md).
    sim.define("script_var", "lunatic/tfs:alarm_flags", { replicate = "server" })
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("link.message.done", { kind = "react" }, controller.message)

    -- WHO IT BELIEVES: `child` and `sibling`. A child is a fan joined
    -- to this alarm by hand, which is the pairing the whole box exists
    -- for. A sibling is a fan still hanging off the panel that feeds
    -- the room, which is where every fan starts and where most of them
    -- stay -- an alarm bolted up in a room reports on that room
    -- without an engineer joining anything (docs/devices/joining.md).
    -- Anything further away is another room's plant and is not this
    -- alarm's to speak for.
    --
    -- WHAT IT SAYS BACK, and how little of it. One emission per band
    -- whose ANSWER changed -- at most two per delivery, and only when
    -- a fan crosses a band, which is already the only time a fan says
    -- anything. The per-address traffic ceiling is four a second
    -- (docs/DEVICES.md) and this comes nowhere near it: a room would
    -- have to be crossing bands twice a second to press on it, and a
    -- room doing that has worse problems than its lighting.
    script_definition:handle("link.message.done", { kind = "react" }, function(ev)
        if ev.relation ~= "child" and ev.relation ~= "sibling" then
            return
        end
        local payload = ev.payload
        if type(payload) ~= "table" or payload.kind ~= netmsg.ATMOS_HAZARD then
            return
        end
        -- The WORD in the payload is deliberately not read. It says
        -- what one tile did, and this box answers for a room -- so the
        -- message is taken as "something moved, go and look" and the
        -- looking is done below, where a sender cannot lie about
        -- anybody but itself.
        local self = ev.self
        local last = self.vars["alarm_flags"] or {}
        local now = derive(self)
        local again = last.dirty == true
        for _, band in ipairs(BANDS) do
            if again or (last[band] == true) ~= now[band] then
                sim.link.emit({
                    subject = self,
                    payload = netmsg.light_flag(if now[band] then "set" else "clear", band),
                })
            end
        end
        self.vars["alarm_flags"] = { deadly = now.deadly, unbreathable = now.unbreathable }
    end)

    -- AN EMISSION NOBODY GOT is the one case a difference cannot be
    -- taken against: the traffic ceilings truncate rather than queue
    -- (docs/DEVICES.md), so a refused emission leaves the fittings
    -- holding a state this box thinks it has already corrected. The
    -- repair is to forget that it said anything and say all of it
    -- again on the next nudge.
    --
    -- NOTHING HERE CAN REACH THE RATE CEILING TODAY, and the
    -- arithmetic is worth writing down rather than trusting: the
    -- fixtures are sampled once an atmos pass, a pass is every ten
    -- ticks and the ceiling's window is twenty, so this box is asked
    -- to look at most twice a second. Two looks times the two bands
    -- below is four emissions, which is exactly the allowance and
    -- never over it. The guard is here for the other ways an
    -- emission fails -- a card pulled between the handler and the
    -- apply, a box that went off the air in the same tick -- and for
    -- the day a third band is added or the cadence moves.
    script_definition:handle("link.emit.done", { kind = "react" }, function(ev)
        if ev.outcome ~= "failed" then
            return
        end
        local v = ev.self.vars["alarm_flags"] or {}
        v.dirty = true
        ev.self.vars["alarm_flags"] = v
    end)

    script_definition:handle("interaction.use.done", { kind = "react", route = "interact" }, function(ev)
        -- An empty hand, and a use that actually resolved: `implement`
        -- is absent for the crewman reading the box and present for the
        -- one taking it off the wall, and both arrive here.
        if ev.implement ~= nil or ev.outcome ~= "completed" then
            return
        end
        local said = network.line(ev.subject, NOUN, MEMBER)
        if said == nil then
            -- No address at all, which for a socketed box is one thing.
            said = sim.msg("lunatic/tfs:lib.network.no_card", {})
        end
        sim.message.send({ recipient = ev.actor, message = said })
    end)
end

return content
