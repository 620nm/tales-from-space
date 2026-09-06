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
-- (fixtures/vent.luau); this box keeps the tally and turns it into
-- light. That division is deliberate: a fan reports the tile it stands
-- on and has no idea whether the ROOM is in trouble, an alarm holds a
-- roster and does, and a fitting burns whatever it is told to. Nobody
-- along that chain knows more than their own job.
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

if sim ~= nil then
    -- The roster: address -> the worst word that address last
    -- reported, with `none` spelled as the absence of a key. A hub
    -- holds at most a room's worth of fans, so this is a handful of
    -- short strings against the 4096 bytes a ScriptVar gets
    -- (docs/luau-api/script-vars.md).
    sim.define("script_var", "lunatic/tfs:hazard_levels", { replicate = "server" })
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    -- NOT YET REACHING IT, and the reason is the engine's rather than
    -- this file's: a routed delivery addresses the INTERFACE, and this
    -- box takes its address from a card in a socket
    -- (`devicenet_emit` routes through `devicenet_entity`, where
    -- `devicenet_host` is the machine). So `link.message.done` arrives
    -- at the card and a handler scoped to this prototype never runs.
    -- Written as it should be, and left that way.
    --
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
        -- The engine's own three words, checked because this arrived
        -- over a network rather than out of the engine's hand.
        local level = payload.level
        if level ~= "none" and level ~= "deadly" and level ~= "unbreathable" then
            return
        end
        local held = if level == "none" then nil else level
        local self = ev.self
        local levels = self.vars["hazard_levels"] or {}
        if levels[ev.from] == held then
            return
        end
        local before = netmsg.hazard_flags(levels)
        levels[ev.from] = held
        self.vars["hazard_levels"] = levels
        local after = netmsg.hazard_flags(levels)
        for _, band in ipairs(BANDS) do
            if before[band] ~= after[band] then
                sim.link.emit({
                    subject = self,
                    payload = netmsg.light_flag(if after[band] then "set" else "clear", band),
                })
            end
        end
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
