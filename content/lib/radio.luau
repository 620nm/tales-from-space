-- WHO A RADIO REACHES, in one place.
--
-- The engine's half of a `;` line is a plan naming every living radio
-- carrier and the relays that settled the words (`speech.radio`,
-- docs/luau-api/speech-radio.md). This pack's opinion is that a voice
-- is a signal: a handheld reaches a few rooms on its own, and reaches
-- the station only through the towers the relay stages left speaking
-- (lib/radio_relay.luau). That opinion is a `speech.radio` transform
-- registered on every radio-declaring item this pack ships -- the
-- headset and the encryption key -- and would otherwise be spelled once
-- per item file, which is what this directory exists to prevent.
--
-- EVERY NUMBER IS HERE and nowhere else, so retuning the radio is one
-- edit. Distances are Euclidean over tile coordinates; a signal fades
-- by the fraction of a circle's radius a listener stands at, and past
-- three quarters of it the words start dropping out.
local radio = {}

-- The channels, one word each: the bracket every listener sees, and the
-- word an encryption key carries. Common is the whole crew's; the four
-- department words belong to the jobs beside them.
radio.channels = {
    common = "Common",
    engineering = "Wrench", -- jobs/engineer.luau
    medical = "Lifeline", -- jobs/medic.luau
    security = "Watchline", -- jobs/security.luau
    command = "Charter", -- jobs/captain.luau
}

-- Which channel a fitted key lends a tower: the encryption key variant
-- ids (items/encryption_key.luau) against the words above. The blank
-- base key is deliberately absent -- a key stamped with nothing is
-- silent.
radio.key_for = {}
for department, word in pairs(radio.channels) do
    radio.key_for["encryption_key." .. department] = word
end

-- How far a handheld radio carries on its own: the local circle every
-- transmission gets whatever the towers are doing.
radio.LOCAL_RADIUS = 10
-- One powered tower's reach: a 60-tile diameter.
radio.TRANSCEIVER_RADIUS = 30
-- Each further POWERED tower on the same device-network tree stretches
-- every tower on it by a fifth. THE HARDWARE IS THE AMPLIFIER: a
-- blank-keyed tower still buffs the tree it stands in, an unpowered
-- one contributes nothing, and keys decide only which channels a tower
-- CARRIES, never how far its tree reaches.
radio.NETWORK_MULT = 1.2
-- Inside this fraction of a circle the words arrive whole; between it
-- and the rim they drop out character by character.
radio.CLEAR_FRACTION = 0.75

-- What one tower on a tree of `n` powered towers reaches.
function radio.radius_for(n)
    return radio.TRANSCEIVER_RADIUS * radio.NETWORK_MULT ^ (n - 1)
end

-- The circle that reaches (x, y) best and the fraction of its radius
-- the listener stands at. Above 1 the listener is outside every circle
-- offered. Ties keep the EARLIER circle, which is why `deliver` lists
-- the handheld's own first and then `ev.sources` in the engine's
-- ascending-address order (docs/luau-api/speech-radio.md).
local function nearest(circles, x, y)
    local best, best_f = nil, math.huge
    for _, circle in ipairs(circles) do
        local dx, dy = x - circle.x, y - circle.y
        local f = math.sqrt(dx * dx + dy * dy) / circle.radius
        if f < best_f then
            best, best_f = circle, f
        end
    end
    return best, best_f
end

-- The best (smallest) distance-over-radius fraction any circle gives a
-- listener standing at (x, y).
function radio.fraction(circles, x, y)
    local _, f = nearest(circles, x, y)
    return f
end

-- djb2 over the spoken line: the per-transmission seed the static is
-- keyed on. 32-bit by modulus; every intermediate stays under 2^53, so
-- the arithmetic is exact in Luau's doubles.
local function djb2(text)
    local h = 5381
    for i = 1, #text do
        h = (h * 33 + string.byte(text, i)) % 4294967296
    end
    return h
end

-- A deterministic 32-bit scramble. NO RNG anywhere in the radio: the
-- same words at the same fraction garble the same way every time, on
-- every server, which is what lets a spec assert the exact string a
-- listener at the rim reads (tests/radio_coverage_test.luau).
--
-- Multiply-add-shift only: the content VM ships no bit32 library, and
-- every intermediate here stays under 2^38, exact in Luau doubles.
-- The floor-divisions are the right-shifts of an ordinary avalanche;
-- the quality bar is "spread a seed over 4096 buckets", nothing more.
local function mix32(n)
    local h = n % 4294967296
    h = (h * 33 + 421 + math.floor(h / 8192)) % 4294967296
    h = (h * 33 + 421 + math.floor(h / 128)) % 4294967296
    h = (h * 33 + 421 + math.floor(h / 131072)) % 4294967296
    return h
end

-- The line as a listener at fraction `f` reads it: whole inside the
-- clear band, and losing characters to "~" toward the rim. Spaces are
-- never garbled, so a sentence keeps its shape however little of it
-- survives. The seed comes in from outside so `deliver` pays djb2 once
-- per CIRCLE rather than once per listener -- the host meters fuel per
-- invocation, and an exhausted handler forfeits its whole answer.
local function garble_seeded(seed, text, f)
    if f <= radio.CLEAR_FRACTION then
        return text
    end
    local g = (f - radio.CLEAR_FRACTION) / (1 - radio.CLEAR_FRACTION)
    local out = {}
    for i = 1, #text do
        local c = string.sub(text, i, i)
        if c ~= " " and mix32(seed + i * 2654435761) % 4096 / 4096 < g then
            c = "~"
        end
        out[i] = c
    end
    return table.concat(out)
end

function radio.garble(text, f)
    return garble_seeded(djb2(text), text, f)
end

-- Every channel word a tower's encryption sockets carry, in socket
-- order, or nil against a machine with none. Reads the settled roster
-- (`Handle.components`, docs/LUAU-API.md §7), so a swapped key counts
-- from the tick the swap settled.
local function keyed_words(machine)
    local words = nil
    for _, slot in ipairs(machine.components or {}) do
        if slot.kind == "encryption" then
            local word = radio.key_for[slot.item]
            if word ~= nil then
                words = words or {}
                words[#words + 1] = word
            end
        end
    end
    return words
end
radio.keyed_words = keyed_words

-- The one sentence a crewman standing at a tower gets
-- (fixtures/transceiver.luau): what it carries, and whether anything is
-- feeding it -- the access point's own contract, in this machine's
-- words (fixtures/access_point.luau, lib/network.luau).
function radio.status_line(machine)
    if not sim.is_powered(machine) then
        return "The transceiver is dark. Check what is feeding it."
    end
    local words = keyed_words(machine)
    if words == nil then
        return "There is no channel keyed into it. Until there is, it carries nothing."
    end
    local line = "The transceiver is on the air, carrying " .. table.concat(words, " and ")
    local state = sim.link_state(machine)
    if state ~= nil and state.parent ~= nil and not state.suspended then
        return line .. ", relayed through its network."
    end
    return line .. "."
end

-- The `speech.radio` policy itself, shared by every transmitting item
-- (items/headset.luau, items/encryption_key.luau). The offered rows are
-- rebuilt whole -- each answered row carries `heard`, `text` AND
-- `channel`, the anchor's own contract (a row missing one discards or
-- mutes, docs/luau-api/speech-radio.md) -- and nothing is ever added.
--
-- WHICH TOWERS ARE SPEAKING is settled before this runs: `ev.sources`
-- is one row per relay that survived `radio.send`, carrying its tree's
-- words and its `peers` count (lib/radio_relay.luau). All that is left
-- here is geometry.
function radio.deliver(ev)
    -- One circle per signal in the air, filed under the word it is
    -- spoken in: the handheld's own first -- it reaches this far
    -- whatever the towers are doing -- then every source, the tree's
    -- hardware count deciding its reach.
    --
    -- A listener only ever hears a circle whose word is the one their
    -- own radio is tuned to, which is what makes a rewritten channel a
    -- REBROADCAST rather than a leak: the towers move the line onto
    -- another band and the crew still on the old one keep their own.
    local bands = {}
    local function circle(channel, x, y, radius, text)
        local band = bands[channel]
        if band == nil then
            band = {}
            bands[channel] = band
        end
        band[#band + 1] = { x = x, y = y, radius = radius, text = text, spoken = {} }
    end
    circle(ev.channel, ev.at.x, ev.at.y, radio.LOCAL_RADIUS, ev.text)
    for _, source in ipairs(ev.sources) do
        circle(source.channel, source.at.x, source.at.y, radio.radius_for(source.peers), source.text)
    end

    -- One djb2 per CIRCLE and one garble per distinct fraction of it --
    -- listeners cluster on few of them -- so a crowd costs rows, not
    -- hashes (the fuel argument on `garble_seeded`).
    local answered = {}
    for index, row in ipairs(ev.listeners) do
        -- A LIVING listener may have no tile at all: a body stowed in
        -- a drawer keeps its radio and loses its coordinates
        -- (t.bodies_at's "no tile" case). A signal model has one
        -- honest answer for someone standing nowhere -- not heard --
        -- and the read is guarded per row, so an odd carrier costs
        -- that one row and never the transmission.
        local ok, tile = pcall(function()
            return row.who.tile
        end)
        local band = bands[row.channel]
        local heard, text = false, ev.text
        if ok and tile ~= nil and band ~= nil then
            local reach, f = nearest(band, tile.x, tile.y)
            if f <= 1 then
                heard = true
                text = reach.spoken[f]
                if text == nil then
                    reach.seed = reach.seed or djb2(reach.text)
                    text = garble_seeded(reach.seed, reach.text, f)
                    reach.spoken[f] = text
                end
            end
        end
        answered[index] = {
            who = row.who,
            item = row.item,
            heard = heard,
            text = text,
            channel = row.channel,
        }
    end
    return { listeners = answered }
end

return radio
