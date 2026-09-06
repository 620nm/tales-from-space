-- The APC, and the two things about it that are not mechanism.
--
-- Everything a player DOES to one is native: the battery, the three
-- channels, the ports and their reserve flags, and the `link` module's
-- address, roster and candidates -- and a press on any of those rows
-- goes through the same helper a script's gesture would
-- (docs/TGUI.md). There is deliberately no hook here that throws a
-- breaker, joins or releases anything; a second path to those would be
-- a second answer to who may.
--
-- What is left is a SENTENCE and a FLAG.
--
-- The sentence is `lib/network.luau`'s, said with this box's nouns. A
-- crewman who touches a panel gets its window and one line about what
-- it is carrying, because "online" and "suspended" are the engine's
-- words and nobody says them out loud. The access point and the router
-- are the other callers and differ in exactly two words
-- (fixtures/access_point.luau, fixtures/network_router.luau). "Fitting"
-- rather than "device" because what hangs off a panel is what the
-- panel feeds -- the tubes, the fans, whatever is on a cord -- and a
-- crewman reading the line knows what is plugged in without being told
-- there is a network at all.
--
-- The flag is the one thing a panel knows that nothing else on the
-- station does: whether the room is running off its own cell. The
-- engine raises `flow.backup.done` on the crossing and only on the
-- crossing, so this is one emission when the mains die and one when
-- they come back, never a per-pass drumbeat. What the lights do with
-- it is theirs (fixtures/light.luau); all this says is that it
-- happened.
--
-- The use hook rides `interaction.use.done` rather than
-- `interaction.use` for the access point's reason: the decision anchor
-- is where a handler REPLACES the click, and replacing this one would
-- eat both the panel and the crowbar.
local content = {
    id = "apc",
}

local NOUN = "APC"
local MEMBER = "fitting"

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    script_definition:handle("interaction.use.done", { kind = "react", route = "interact" }, function(ev)
        -- An empty hand, and a use that actually resolved: `implement`
        -- is absent for the crewman reading the box and present for the
        -- one taking it off the wall, and both arrive here.
        if ev.implement ~= nil or ev.outcome ~= "completed" then
            return
        end
        local said = network.line(ev.subject, NOUN, MEMBER)
        if said == nil then
            -- No address at all, which for a socketed box is one thing:
            -- there is nothing in the socket to lend it one. The panel
            -- is still bridging power; it is simply on no network.
            said = sim.msg("lunatic/tfs:lib.network.no_card", {})
        end
        sim.message.send({ recipient = ev.actor, message = said })
    end)

    -- ON AND OFF THE RESERVE. `ev.controller` is the panel that
    -- crossed, and it is the panel that has to be the subject of the
    -- emission -- a message put on the network by anything else would
    -- reach the wrong half of the forest. `ev.on` is which way it
    -- crossed, and the two directions are one set and one clear of the
    -- same named flag.
    script_definition:handle("flow.backup.done", { kind = "react" }, function(ev)
        sim.link.emit({
            subject = ev.controller,
            payload = netmsg.light_flag(ev.on and "set" or "clear", "low_power"),
        })
    end)
end

return content
