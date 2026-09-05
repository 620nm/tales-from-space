-- WHAT A DEVICE-NETWORK BOX SAYS ABOUT ITSELF, in one place.
--
-- The access point and the router are the same object twice over: both
-- take their address out of a card in a socket, both draw the same
-- native panel with every row on it that a player can act on
-- (docs/TGUI.md, the `link` module), and both owe a crewman who walks
-- up and touches one a plain sentence about what it is doing. That
-- sentence is the only part of either that is content, and it would
-- otherwise be spelled twice in two roster files -- which is what this
-- directory exists to prevent (AGENTS.md).
--
-- THE PANEL SAYS IT IN ENGINE WORDS. `sim.link_state` answers with
-- `online`, `unbound`, `suspended` -- a closed roster the ledger and
-- the window share, so a word read off a screen is the word a
-- reconstruction reads off the log (docs/DEVICES.md §4). None of those
-- is a sentence anybody says out loud, and turning them into ones is a
-- pack's job and not an engine's.
--
-- A SHUT PANEL SAYS NOTHING ABOUT THE NETWORK BEHIND IT, and neither
-- does this. What a lock protects is the ROSTER -- a list of what is
-- joined to a network is worth something to whoever is standing at a
-- rival's rack -- so a locked node reports that it is locked and stops.
-- Printing the member count past a shut lock would be this pack walking
-- around the engine's own rule (docs/DEVICES.md §8), which is worse
-- than having no line at all.
local network = {}

-- THE CLASS WORD IS NOT HERE, and cannot be. `link.class` and
-- `link.accepts` are the pack's own words for what KIND of device a
-- node is (docs/content-schema/link.md), and one word shared by
-- fourteen files is exactly what this directory is for -- except that
-- `lib/` is published into the ITEM sandbox and not into the structure
-- registry's (`crates/lunatic-server/src/structures/registry.rs`), so a
-- structure reading `network.class` reads nil at prototype time. It is
-- therefore spelled out in each file, and `structures/air_alarm.luau`
-- is where the argument for the word lives.

-- One sentence about `node`, called what the file calling this calls
-- it. `noun` is the pack's word for the box itself ("access point");
-- `member` is its word for one of the things it holds, because a hub
-- carries devices and a root carries hubs and neither is the other.
--
-- Returns nil for a thing on no network at all, which for a socketed
-- box means its socket is empty -- the caller says so in its own words,
-- because "there is no card in it" is a different sentence from every
-- one below.
function network.line(node, noun, member)
    local state = sim.link_state(node)
    if state == nil then
        return nil
    end
    -- WHAT OPENS IT IS NOT SOMETHING THIS CAN KNOW. A lock's key is the
    -- placement's own `access` word, so one box wants a claim and the
    -- one beside it -- screwed together by hand, keyed by nothing --
    -- opens for whoever is standing at it (docs/DEVICES.md §8). The
    -- surface answers `locked` either way and offers no way to tell,
    -- so the line says the one thing that is true of both.
    if state.locked then
        return sim.msg("lunatic/tfs:lib.network.locked", { noun = noun })
    end
    if state.suspended then
        return sim.msg("lunatic/tfs:lib.network.suspended", { noun = noun })
    end
    local held = state.members or 0
    if held == 0 then
        return sim.msg("lunatic/tfs:lib.network.bare", { noun = noun })
    end
    if held == 1 then
        return sim.msg("lunatic/tfs:lib.network.one", { noun = noun, member = member })
    end
    return sim.msg("lunatic/tfs:lib.network.many", {
        noun = noun,
        member = member,
        held = held,
    })
end

return network
