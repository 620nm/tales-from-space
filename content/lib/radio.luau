-- WHO A RADIO REACHES, in one place.
--
-- The engine's half of a `;` line is delivery to every living carrier
-- of the channel, station-wide (docs/CONTENT-SCHEMA.md §1.7b). This
-- pack's opinion is that a voice is a signal: a handheld radio reaches
-- a few rooms on its own, and reaches the station only through a
-- powered transceiver tower keyed to the same channel
-- (machines/transceiver.luau). That opinion is a `speech.radio`
-- transform (docs/LUAU-API.md §4) registered on every radio-declaring
-- item this pack ships -- the headset and the encryption key -- and the
-- policy would otherwise be spelled once per item file, which is what
-- this directory exists to prevent (AGENTS.md).
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
radio.LOCAL_RADIUS = 7
-- One powered, keyed tower's reach: a 21-tile diameter.
radio.TRANSCEIVER_RADIUS = 10.5
-- Each further tower on the same device-network tree stretches every
-- tower on it by a fifth: a NETWORK of towers is worth more than the
-- sum of its poles.
radio.NETWORK_MULT = 1.2
-- Inside this fraction of a circle the words arrive whole; between it
-- and the rim they drop out character by character.
radio.CLEAR_FRACTION = 0.75

-- What one tower on a tree of `n` towers reaches.
function radio.radius_for(n)
    return radio.TRANSCEIVER_RADIUS * radio.NETWORK_MULT ^ (n - 1)
end

-- The best (smallest) distance-over-radius fraction any source circle
-- gives a listener standing at (x, y). Above 1 the listener is outside
-- every circle there is.
function radio.fraction(sources, x, y)
    local best = math.huge
    for _, source in ipairs(sources) do
        local dx, dy = x - source.x, y - source.y
        local f = math.sqrt(dx * dx + dy * dy) / source.radius
        if f < best then
            best = f
        end
    end
    return best
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
local function mix32(n)
    local h = n % 4294967296
    h = bit32.bxor(h, bit32.rshift(h, 13))
    h = (h * 33 + 421) % 4294967296
    h = bit32.bxor(h, bit32.rshift(h, 7))
    h = (h * 33 + 421) % 4294967296
    h = bit32.bxor(h, bit32.rshift(h, 17))
    return h
end

-- The line as a listener at fraction `f` reads it: whole inside the
-- clear band, and losing characters to "~" toward the rim. Spaces are
-- never garbled, so a sentence keeps its shape however little of it
-- survives.
function radio.garble(text, f)
    if f <= radio.CLEAR_FRACTION then
        return text
    end
    local g = (f - radio.CLEAR_FRACTION) / (1 - radio.CLEAR_FRACTION)
    local seed = djb2(text)
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
-- rebuilt whole -- each answered row carries BOTH `heard` and `text`,
-- the anchor's own contract (docs/LUAU-API.md §4: a row missing either
-- discards or mutes) -- and nothing is ever added to them.
function radio.deliver(ev)
    -- The local circle first: a handheld reaches this far on its own.
    local sources = { { x = ev.at.x, y = ev.at.y, radius = radio.LOCAL_RADIUS } }

    -- Every powered tower holding any channel key, grouped by the
    -- device-network tree it stands in. `count` is what stretches a
    -- tree's reach; `gates` are the towers keyed to THIS line's
    -- channel, the only ones that carry it.
    --
    -- The tree fingerprint is `link_tree`'s FIRST member: the list
    -- ascends by address (docs/LUAU-API.md §7), so the lowest-address
    -- node names the tree for every tower on it. Handles compare by
    -- the entity they wrap; they are matched with `==` down a list
    -- rather than used as table keys, because userdata keys hash by
    -- reference. An empty tree is an unbound tower: a network of one.
    local groups = {}
    for _, tower in ipairs(sim.query.all("transceiver")) do
        if sim.is_powered(tower) then
            local words = keyed_words(tower)
            if words ~= nil then
                local carries = false
                for _, word in ipairs(words) do
                    if word == ev.channel then
                        carries = true
                    end
                end
                local fingerprint = sim.query.link_tree(tower)[1]
                local group = nil
                if fingerprint ~= nil then
                    for _, known in ipairs(groups) do
                        if known.fingerprint ~= nil and known.fingerprint == fingerprint then
                            group = known
                            break
                        end
                    end
                end
                if group == nil then
                    group = { fingerprint = fingerprint, count = 0, gates = {} }
                    table.insert(groups, group)
                end
                group.count += 1
                if carries then
                    local tile = tower.tile
                    table.insert(group.gates, { x = tile.x, y = tile.y })
                end
            end
        end
    end

    -- A tree carries the line if the speaker reaches ANY of its
    -- channel towers; then every channel tower on it rebroadcasts.
    for _, group in ipairs(groups) do
        local reach = radio.radius_for(group.count)
        local uplinked = false
        for _, gate in ipairs(group.gates) do
            local dx, dy = ev.at.x - gate.x, ev.at.y - gate.y
            if math.sqrt(dx * dx + dy * dy) <= reach then
                uplinked = true
                break
            end
        end
        if uplinked then
            for _, gate in ipairs(group.gates) do
                table.insert(sources, { x = gate.x, y = gate.y, radius = reach })
            end
        end
    end

    local answered = {}
    for index, row in ipairs(ev.listeners) do
        local tile = row.who.tile
        local f = radio.fraction(sources, tile.x, tile.y)
        answered[index] = {
            who = row.who,
            item = row.item,
            heard = f <= 1,
            text = if f <= 1 then radio.garble(ev.text, f) else ev.text,
        }
    end
    return { listeners = answered }
end

return radio
