-- WHAT A TOWER DOES TO A LINE crossing it, in one place.
--
-- The engine walks every powered, unsuspended relay four times per `;`
-- line -- receive, read, carry, send -- standing on one machine at a
-- time (docs/luau-api/radio-relay.md). These are this pack's answers,
-- shared by the tower, the access point and the router because the
-- three of them disagree about nothing here (fixtures/transceiver.luau,
-- fixtures/access_point.luau, fixtures/network_router.luau).
--
-- The division of labour: RANGE is receipt's, KEYS are the reader's and
-- the mouth's. A tower takes in whatever it can hear whether or not it
-- can make the word out, so a blank tower beside the speaker still puts
-- the line on its tree and a keyed tower elsewhere on that tree reads
-- it out. lib/radio.luau owns the numbers.
--
-- NOTHING HERE WRITES `reason`, deliberately. A stage that states one
-- earns a shift-record row; range and keys are arithmetic every tower
-- does on every line, and writing those down would bury the rows that
-- mean something. A mod that wants its own drop on the record says so.
local radio_relay = {}

-- Whether a machine's encryption sockets carry `channel`. A machine
-- with no keys in it carries nothing, which is the blank tower.
local function keyed_to(node, channel)
    for _, word in ipairs(radio.keyed_words(node) or {}) do
        if word == channel then
            return true
        end
    end
    return false
end
radio_relay.keyed_to = keyed_to

-- Receipt is RANGE, and deliberately key-blind: `ev.distance` is the
-- speaker's Euclidean tiles from this tower and the tree's hardware
-- count sets what that buys. `reads` is the separate question of
-- whether this tower could make the word out; answering it false is not
-- a refusal, it just sends the question up to the tree's top.
function radio_relay.receive(ev)
    if ev.distance > radio.radius_for(ev.peers) then
        return { cancelled = true }
    end
    return { reads = keyed_to(ev.self, ev.channel) }
end

-- Nobody on this tree could make the word out, so the top picks the
-- tower the words are read from: the first one on it keyed to the
-- channel, in the engine's ascending-address order. None means the tree
-- has no business with this line at all.
function radio_relay.read(ev)
    for _, row in ipairs(ev.relays) do
        if keyed_to(row.node, ev.channel) then
            return { reader = row.node }
        end
    end
    return { cancelled = true }
end

-- The hop that changes nothing. Registering it is the point: this is
-- where the words pass through a machine somebody could own, and a
-- guest script hosted here is what eventually rewrites them
-- (docs/DIEGETIC_SCRIPTING.md). Stock hardware is honest hardware.
function radio_relay.carry(ev)
    return { text = ev.text, channel = ev.channel }
end

-- The mouth. A tower speaks exactly the words its keys are cut with,
-- and the channel here is the one the tree SETTLED on -- so a line
-- moved onto another band goes back out only through towers keyed to
-- that band.
function radio_relay.send(ev)
    return { cancelled = not keyed_to(ev.self, ev.channel) }
end

return radio_relay
