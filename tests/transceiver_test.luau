-- A radio transceiver from a crate of parts, and back into one.
--
-- The build ladder is the machine frame's, generically
-- (docs/CONSTRUCTION.md; deconstruction_test.luau is the round trip's
-- own spec) -- what THIS file asserts is the transceiver's stake in
-- it: the board names its sockets one shortage at a time, the
-- finished tower says what its keys make of it
-- (fixtures/transceiver.luau, lib/radio.luau), and a teardown hands
-- back the KEY THAT WENT IN rather than minting a fresh one -- a
-- channel is a physical thing in a socket, so losing track of which
-- key is which would be losing the thing the machine is for.

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

-- The bench: power along the south wall, a plain transceiver a map
-- stood up (its sockets on the plain rungs: a blank key says nothing),
-- and every part of a keyed one lying at the builder's feet.
t.world([==[(
    name: "transceiver bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'G': (turf: Floor, fixture: Some(Generator)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'o': (turf: Floor, fixture: Some(Outlet)),
    },
    rows: [
        "########",
        "#......#",
        "#Gao...#",
        "########",
    ],
    spawns: [(5, 1)],
    items: [
        (5, 1, "metal"),
        (5, 1, "cable_coil"),
        (5, 1, "machine_board.transceiver"),
        (5, 1, "network_card"),
        (5, 1, "encryption_key.medical"),
        (5, 1, "encryption_key"),
        (5, 1, "screwdriver"),
        (5, 1, "crowbar"),
    ],
    machines: [
        (4, 1, "transceiver"),
    ],
    cables: [(1, 2, 2), (2, 2, 3), (3, 2, 1)],
)]==], 0)

local p = t.join()
t.run_ticks(20)

local function take(x, y, id)
    t.click(p, x, y, t.target_at(x, y, id))
    t.run_ticks(2)
    assert(t.hands(p).held == id, "expected " .. id .. " in hand")
end

local function put_down()
    t.drop(p)
    t.run_ticks(2)
end

local function work(seconds)
    t.click(p, 6, 1, t.target_at(6, 1, "machine_frame"))
    t.run_seconds(seconds)
end

-- The screwdriver against a short assembly, and what it says is
-- missing. One line, one shortage at a time (the refusal contract:
-- an engineer fetches one thing at a time).
local function still_needs(line)
    take(5, 1, "screwdriver")
    local _ = t.messages(p)
    work(4.5)
    local heard = table.concat(t.messages(p), " | ")
    assert(heard:find(line, 1, true), "expected '" .. line .. "', got: " .. heard)
    put_down()
end

-- ---------------------------------------------------------------
-- 1. THE LADDER, with the board naming each empty socket in turn:
--    the address first, then the two key sockets, counted down as
--    they fill, then the board's own length of cable.
-- ---------------------------------------------------------------
take(5, 1, "metal")
t.build(p, "metal", "machine_frame", 6, 1)
t.run_seconds(8.5)
assert(t.structure_at(6, 1).id == "machine_frame", "five sheets box up into a frame")

put_down()
take(5, 1, "cable_coil")
work(2.5)
assert(t.structure_at(6, 1).state == "wired", "five lengths of cable wire it")

put_down()
take(5, 1, "machine_board.transceiver")
work(0.5)
assert(t.structure_at(6, 1).state == "boarded", "and the board says what it is becoming")
put_down()

still_needs("It still needs 1 x network card.")
take(5, 1, "network_card")
work(0.5)

still_needs("It still needs 2 x encryption key.")
take(5, 1, "encryption_key.medical")
work(0.5)

still_needs("It still needs 1 x encryption key.")
take(5, 1, "encryption_key")
work(0.5)
take(5, 1, "cable_coil")
work(0.5)
put_down()

take(5, 1, "screwdriver")
work(4.5)
assert(t.structure_at(6, 1) == nil, "the frame is spent into the tower")
put_down()
t.run_ticks(40)

-- ---------------------------------------------------------------
-- 2. THE SENTENCE. An empty hand on the tower gets this pack's own
--    words for what the sockets make of it
--    (fixtures/transceiver.luau): the built one carries the word its
--    key is cut with, the mapped one -- all plain rungs, and a blank
--    key says nothing -- carries no channel at all.
-- ---------------------------------------------------------------
local _ = t.messages(p)
t.click(p, 6, 1, t.target_at(6, 1))
t.tick()
assert(
    said(p, "The transceiver is on the air, carrying Lifeline."),
    "a keyed tower names its channel, got: " .. table.concat(t.messages(p), " | ")
)
t.ui_close(p)
t.tick()

local _ = t.messages(p)
t.click(p, 4, 1, t.target_at(4, 1))
t.tick()
assert(
    said(p, "There is no channel keyed into it. Until there is, it carries nothing."),
    "a blank-keyed tower says so, got: " .. table.concat(t.messages(p), " | ")
)
t.ui_close(p)
t.tick()

-- ---------------------------------------------------------------
-- 3. AND BACK APART: panel, pry, pry. What comes out of the socket is
--    the key that went in -- one Lifeline key exists on this bench,
--    and the count holds through the whole round trip, so a teardown
--    that minted a fresh one would be caught right here. (The deck
--    count reads loose items only -- a fitted key stands on no tile --
--    so the count is asserted while the key is out in the world.)
-- ---------------------------------------------------------------
take(5, 1, "screwdriver")
t.click(p, 6, 1, t.target_at(6, 1))
t.run_ticks(2)
put_down()
take(5, 1, "crowbar")
t.click(p, 6, 1, t.target_at(6, 1))
t.run_ticks(2)
local frame = t.structure_at(6, 1)
assert(frame ~= nil and frame.id == "machine_frame" and frame.state == "boarded",
    "the assembly is what is left standing, holding its parts")

-- The frame's own crowbar is the one path the parts come back out by.
t.click(p, 6, 1, t.target_at(6, 1, "machine_frame"))
t.run_ticks(2)
put_down()
assert(t.item_at(6, 1, "encryption_key.medical") ~= nil,
    "the key that went in is the key that comes out")
assert(t.count_items("encryption_key.medical") == 1, "and no second one was invented")

-- ---------------------------------------------------------------
-- 4. RE-FIT THE SAME KEY, and the tower still answers Lifeline: the
--    channel rode the entity through the teardown, not the machine.
-- ---------------------------------------------------------------
local hands = t.hands(p)
assert(hands[1] == "machine_board.transceiver" or hands[2] == "machine_board.transceiver",
    "the board came back to a hand: " .. tostring(hands[1]) .. ", " .. tostring(hands[2]))
-- The board landed in the free hand while the crowbar was working, so
-- it may be the inactive one.
if t.hands(p).held ~= "machine_board.transceiver" then
    t.swap_hands(p)
    t.tick()
end
work(0.5)
take(6, 1, "network_card")
work(0.5)
take(6, 1, "encryption_key.medical")
work(0.5)
take(6, 1, "encryption_key")
work(0.5)
take(6, 1, "cable_coil")
work(0.5)
put_down()
take(5, 1, "screwdriver")
work(4.5)
assert(t.structure_at(6, 1) == nil, "rebuilt")
put_down()
t.run_ticks(40)

local _ = t.messages(p)
t.click(p, 6, 1, t.target_at(6, 1))
t.tick()
assert(
    said(p, "The transceiver is on the air, carrying Lifeline."),
    "the refitted key still carries its word, got: " .. table.concat(t.messages(p), " | ")
)
