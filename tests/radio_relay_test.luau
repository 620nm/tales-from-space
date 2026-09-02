-- WHAT THE NETWORK DOES TO A LINE, from the crew's side of it.
--
-- Coverage geometry is radio_coverage_test.luau's and the amplifier
-- arithmetic is radio_network_test.luau's. What this file asserts is
-- the four staged decisions between the two (lib/radio_relay.luau,
-- docs/luau-api/radio-relay.md): a tower takes a line in by RANGE, the
-- tree's top decides which tower READS it, every node CARRIES it up,
-- and only towers keyed to the word SEND it back out.
--
-- Two facts a crew can plan around fall out of that split:
--   * A BLANK TOWER IS A DOOR. Speak beside one and the keyed tower at
--     the far end of its network answers, because receipt never asked
--     about keys and the read did.
--   * A NETWORK IS THE ONLY BRIDGE. Two roots standing in one room are
--     two networks and never hand each other a line; a router over
--     both is what makes them one, and it is a card and a cable rather
--     than a range number.
--
-- The listener always stands deep inside the far tower's clear band,
-- so every line here arrives whole and no static literal is pinned.

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

local function rows(ui, field)
    local out = {}
    for _, row in ipairs(ui.toggles or {}) do
        if row.field == field then
            out[#out + 1] = row
        end
    end
    return out
end

-- The bench, twice over: two power islands 36 tiles apart, a tower and
-- a wall box on each, and a router in the near one that the two boxes
-- can hang under. The deck is bare plating so a spur can be snipped.
-- Distances (Euclidean, lib/radio.luau):
--   speaker (5,2)  -> near T (4,1)   =  1.41   always in range
--   speaker        -> far T  (45,1)  = 40.01   past 30 AND past 36
--   far T          -> listener(50,2) =  5.10   deep in the clear band
--   near T         -> listener       = 46.01   outside every circle
--   speaker        -> listener       = 45      outside LOCAL_RADIUS
-- Join radii (Chebyshev, docs/DEVICES.md): each wall box is 2 tiles
-- from its tower, inside the hub radius of 5; a router takes hubs at
-- any distance, which is what lets the two islands become one tree.
local BENCH = [==[(
    name: "relay bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'G': (turf: Plating, fixture: Some(Generator)),
        'a': (turf: Plating, fixture: Some(Apc)),
        'o': (turf: Plating, fixture: Some(Outlet)),
    },
    rows: [
        "####################################################",
        "#..................................................#",
        "#Gao....o...............................Gao......o.#",
        "####################################################",
    ],
    spawns: [(5, 2), (50, 2)],
    items: [
        (5, 2, "encryption_key.medical"),
        (50, 2, "encryption_key.medical"),
        (50, 2, "wirecutters"),
    ],
    machines: [
        (4, 1, "%s"),
        (9, 1, "network_router"),
        (45, 1, "transceiver.medical"),
    ],
    structures: [(6, 1, "access_point"), (49, 1, "access_point")],
    mounts: [(6, 1, North), (49, 1, North)],
    cables: [
        (1, 2, 2), (2, 2, 3), (3, 2, 1), (4, 2, 1), (5, 2, 1),
        (6, 2, 1), (7, 2, 1), (8, 2, 1),
        (40, 2, 2), (41, 2, 3), (42, 2, 1), (43, 2, 1), (44, 2, 1),
        (45, 2, 1), (46, 2, 1), (47, 2, 1), (48, 2, 1), (49, 2, 1),
    ],
)]==]

local speaker, listener

local function pocket(p)
    local x, y = t.pos(p)
    t.click(p, x, y, t.target_at(x, y, "encryption_key.medical"))
    t.run_ticks(2)
    assert(t.hands(p).held == "encryption_key.medical", "the key is in hand")
end

local function walk(p, dir, n)
    for _ = 1, n do
        t.move(p, dir)
        t.run_ticks(6)
    end
end

-- Open a box's panel, unlock it -- a lock placed with no access word
-- opens for whoever is standing at it (network_test.luau) -- and accept
-- every candidate it offers. Answers how many it took. `id` names a
-- structure; a machine is whatever is standing on its tile.
local function join_all(p, x, y, id)
    t.click(p, x, y, if id ~= nil then t.target_at(x, y, id) else t.target_at(x, y))
    t.tick()
    assert(t.ui(p) ~= nil, "the box wears its panel")
    t.ui_act(p, "toggle", '{"field":"link_lock"}')
    t.tick()
    assert(rows(t.ui(p), "link_lock")[1].on, "the lock opens for whoever stands at it")
    local offered = #rows(t.ui(p), "link_join")
    for _ = 1, offered do
        local offer = rows(t.ui(p), "link_join")[1]
        t.ui_act(p, "toggle", string.format('{"field":"link_join","option":"%s"}', offer.option))
        t.tick()
    end
    t.ui_close(p)
    t.tick()
    return offered
end

local function say_and_read(line)
    local _ = t.messages(speaker)
    local _ = t.messages(listener)
    t.say(speaker, ";" .. line)
    t.run_ticks(2)
    assert(said(speaker, line), "the speaker's own copy is always clean")
    return t.messages(listener)
end

-- The two walks the two crewmen make: the speaker between the mark and
-- the near boxes, the listener between the mark and the far one.
local function speaker_to_boxes()
    walk(speaker, "north", 1)
    local x, y = t.pos(speaker)
    assert(x == 5 and y == 1, "at the near wall: " .. x .. "," .. y)
end
local function speaker_to_mark()
    walk(speaker, "south", 1)
    local x, y = t.pos(speaker)
    assert(x == 5 and y == 2, "back on the mark: " .. x .. "," .. y)
end
local function listener_to_box()
    walk(listener, "north", 1)
    local x, y = t.pos(listener)
    assert(x == 50 and y == 1, "beside the far wall box: " .. x .. "," .. y)
end
local function listener_to_mark()
    walk(listener, "south", 1)
    local x, y = t.pos(listener)
    assert(x == 50 and y == 2, "back on the far mark: " .. x .. "," .. y)
end

-- Everything up to "two towers, two roots": the bench, the keys, and a
-- tower hung under each wall box. `near` is the near tower's id, which
-- is the only thing the two runs below disagree about.
local function two_roots(near)
    t.world(string.format(BENCH, near), 0)
    speaker = t.join()
    listener = t.join()
    t.run_ticks(20)
    pocket(speaker)
    pocket(listener)

    speaker_to_boxes()
    assert(join_all(speaker, 6, 1, "access_point") == 1,
        "the near box offers its tower and nothing else")
    speaker_to_mark()
    listener_to_box()
    assert(join_all(listener, 49, 1, "access_point") == 1,
        "so does the far one")
    listener_to_mark()
end

-- The router takes both wall boxes, which is the only gesture in this
-- file that makes one network out of two.
local function bridge()
    speaker_to_boxes()
    walk(speaker, "east", 3)
    assert(join_all(speaker, 9, 1) == 2,
        "a root takes hubs, and there are two of them")
    walk(speaker, "west", 3)
    speaker_to_mark()
end

-- ---------------------------------------------------------------
-- 1. TWO ROOTS NEVER BRIDGE. Both towers are keyed to Lifeline and
--    both are on the air; the speaker is in earshot of the near one
--    only, and the listener stands in the far one's circle only. Each
--    root carries its own line and neither hands it over -- the whole
--    of "relay only through the network" (docs/luau-api/radio-relay.md).
-- ---------------------------------------------------------------
two_roots("transceiver.medical")
assert(#say_and_read("far side, do you copy") == 0,
    "two networks in one room stay two networks")

-- ---------------------------------------------------------------
-- 2. ONE ROUTER, ONE NETWORK. Under a root the two islands are one
--    tree of two towers, so the far tower's mouth is open to a line it
--    never heard the speaker say -- which is the point of a network.
-- ---------------------------------------------------------------
bridge()
local before = #t.ledger_rows("radio_relayed")
local heard = say_and_read("far side, do you copy")
assert(heard[1] == "far side, do you copy",
    "bridged, the far tower speaks for the near one: " .. table.concat(heard, " | "))

-- ---------------------------------------------------------------
-- 3. WHAT THE SHIFT RECORD KEEPS. One row per CARRYING TREE, naming
--    the words it settled on and how many of its mouths spoke them,
--    and nothing per listener. No interception row anywhere: every
--    refusal in this pack is range or keys, which happens on every
--    tower on every line and is deliberately not written down.
-- ---------------------------------------------------------------
local relayed = t.ledger_rows("radio_relayed")
assert(#relayed - before == 1, "one tree carried, one row: " .. (#relayed - before))
local last = relayed[#relayed]
assert(last.channel == "Lifeline" and last.text == "far side, do you copy",
    "the row holds the settled words: " .. tostring(last.channel) .. " / " .. tostring(last.text))
assert(last.sources == 2, "both keyed towers were mouths: " .. tostring(last.sources))
assert(t.ledger_has("SaidRadio"), "what the human said is on the record first")
assert(#t.ledger_rows("radio_intercepted") == 0,
    "a silent refusal leaves no row: " .. #t.ledger_rows("radio_intercepted"))

-- ---------------------------------------------------------------
-- 4. A SUSPENDED TOWER CARRIES NOTHING. One snip on the far wall
--    box's own spur and the box goes dark; the tower under it keeps
--    its own cord and its own power and still drops off the air,
--    because a node whose parent is offline is suspended and a
--    suspended relay is not walked at all.
-- ---------------------------------------------------------------
t.swap_hands(listener)
t.tick()
t.click(listener, 50, 2, t.target_at(50, 2, "wirecutters"))
t.run_ticks(2)
assert(t.hands(listener).held == "wirecutters", "the cutters are in hand")
listener_to_box()
walk(listener, "west", 2)
t.click_subfloor(listener, 48, 2, "cable", 1)
t.run_seconds(1.5)
assert(t.cable_at(48, 2) == 0, "the spur is parted")
assert(t.ledger_has("CableCut"), "sabotage is attributable")
t.run_ticks(60)
walk(listener, "east", 2)
listener_to_mark()

assert(#say_and_read("say again, the far end went quiet") == 0,
    "a tower whose box went dark is off the air, cord or no cord")

-- ---------------------------------------------------------------
-- 5. A BLANK TOWER IS A DOOR. The near tower carries no channel at
--    all now. Standing beside it the speaker still reaches nobody
--    while the two networks are apart -- the near tree can read
--    nothing and the far tree cannot hear him.
-- ---------------------------------------------------------------
two_roots("transceiver")
assert(#say_and_read("anyone on the far island") == 0,
    "a keyless tower on its own network is a dead end")

-- ---------------------------------------------------------------
-- 6. ...AND THE DOOR OPENS ON A NETWORK. Bridged, the blank tower
--    takes the line in on RANGE, the router picks the far tower as the
--    one that can read the word, and the far tower speaks it. Receipt
--    is key-blind and the key check lives at the read: that is the
--    whole difference, and it is what a crew gets for running cable.
-- ---------------------------------------------------------------
bridge()
local through_blank = say_and_read("anyone on the far island")
assert(through_blank[1] == "anyone on the far island",
    "a blank tower is a way onto its network: " .. table.concat(through_blank, " | "))
local blanked = t.ledger_rows("radio_relayed")
assert(blanked[#blanked].sources == 1,
    "and only the keyed tower is a mouth: " .. tostring(blanked[#blanked].sources))
assert(#t.ledger_rows("radio_intercepted") == 0,
    "still nothing worth writing down")
