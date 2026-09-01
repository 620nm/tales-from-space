-- A station's device network, built and worked by hand: an access
-- point on a wall, a router screwed together out of a frame, and the
-- one gesture that turns two boxes into a network.
--
-- Every row in this file is native state (docs/TGUI.md, the `link`
-- module) -- an address minted at spawn, a state the device pass
-- derived, a join candidacy the forest already computes. What is
-- content is which BOXES exist, what they cost and what they are
-- called; what this spec asserts is that a player with a screwdriver
-- and an ID can get from a crate of parts to a network, and can see
-- what happened to it when the lights go out.
--
-- The delivery geometry -- one hop up, sibling branches firewalled, a
-- router hearing its whole tree -- is the engine's and is tested there
-- (docs/DEVICES.md §5). It is deliberately not re-asserted here.

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

local function readout(ui, label)
    for _, r in ipairs(ui.readouts) do
        if r.label == label then
            return r.value
        end
    end
    return nil
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

local function row_for(ui, field, option)
    for _, row in ipairs(rows(ui, field)) do
        if row.option == option then
            return row
        end
    end
    return nil
end

-- The bench: a plant, a controller and a socket along the back wall, an
-- access point already bolted up by whoever built the place, and a crate
-- of parts for the router that is going next to it.
t.world([==[(
    name: "network bench",
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
        (5, 1, "machine_board.network_router"),
        (5, 1, "network_card"),
        (5, 1, "screwdriver"),
        (5, 1, "id_engineering"),
    ],
    structures: [(4, 1, "access_point", { "access": "engineering" })],
    mounts: [(4, 1, North)],
    cables: [(1, 2, 2), (2, 2, 3), (3, 2, 1)],
)]==], 7)

local p = t.join()
t.run_ticks(20)

local function take(id)
    t.click(p, 5, 1, t.target_at(5, 1, id))
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

-- ---------------------------------------------------------------
-- 1. WHO THE ACCESS POINT IS. A shut panel says what this box is and
--    nothing about the network behind it: its own address, because
--    that is an identifier rather than a credential and it is written
--    on the box the reader is standing at, and its state -- and then
--    no roster and no candidates at all (docs/DEVICES.md §1, §8).
-- ---------------------------------------------------------------
t.click(p, 4, 1, t.target_at(4, 1, "access_point"))
t.tick()
local panel = t.ui(p)
assert(panel ~= nil, "the access point wears a panel")
local point = readout(panel, "address")
assert(point ~= nil and #point == 17, "with an address in it: " .. tostring(point))
-- ON THE AIR ALREADY, with nothing above it. A hub with a device
-- joined to it IS a network: there is no `unrooted` suspension and
-- there never will be, because needing a router above it would make
-- the smallest useful thing in the system impossible to build
-- (docs/DEVICES.md §4).
assert(readout(panel, "state") == "online", "a hub tops its own tree, got: " .. tostring(readout(panel, "state")))
assert(#rows(panel, "link_join") == 0 and #rows(panel, "link_drop") == 0,
    "and a shut panel offers neither a roster nor a candidate")
t.ui_close(p)
t.tick()

-- ---------------------------------------------------------------
-- 2. THE ROUTER, THE LONG WAY. A frame, a board, and the one socket
--    that matters -- with the screwdriver naming the card while the
--    socket is empty, exactly as the access point's frame does.
-- ---------------------------------------------------------------
take("metal")
t.build(p, "metal", "machine_frame", 6, 1)
t.run_seconds(8.5)
assert(t.structure_at(6, 1).id == "machine_frame", "five sheets box up into a frame")

put_down()
take("cable_coil")
work(2.5)
assert(t.structure_at(6, 1).state == "wired", "five lengths of cable wire it")

put_down()
take("machine_board.network_router")
work(0.5)
assert(t.structure_at(6, 1).state == "boarded", "and the board says what it is becoming")

put_down()
take("screwdriver")
local _ = t.messages(p)
work(4.5)
local heard = table.concat(t.messages(p), " | ")
assert(
    heard:find("It still needs 1 x network card.", 1, true),
    "a router with no card has no address to route to, got: " .. heard
)

put_down()
take("network_card")
work(0.5)
take("cable_coil")
work(0.5)
put_down()
take("screwdriver")
work(4.5)
assert(t.structure_at(6, 1) == nil, "the frame is gone")
put_down()
t.run_ticks(40)

-- ---------------------------------------------------------------
-- 3. UNLOCK, AND SEE WHAT THERE IS TO JOIN.
--
-- The router was screwed together rather than placed, so no placement
-- names a claim for it: a lock with no key, which still has to be
-- worked by somebody standing at it (docs/DEVICES.md §8).
-- ---------------------------------------------------------------
local _ = t.messages(p)
t.click(p, 6, 1, t.target_at(6, 1))
t.tick()
panel = t.ui(p)
assert(panel ~= nil, "the router wears the same panel")
local router = readout(panel, "address")
assert(router ~= nil and #router == 17 and router ~= point, "with an address of its own")
assert(#rows(panel, "link_join") == 0, "and offers nothing while it is shut")

-- ...and neither does the pack's own sentence about it. A shut lock
-- protects the ROSTER, so the line a crewman gets reports the lock and
-- stops rather than counting members past it -- content walking around
-- the engine's rule would be worse than no line at all
-- (content/lib/network.luau, docs/DEVICES.md §8). It says nothing about
-- what would OPEN it either: this one was screwed together and has no
-- key at all, and the read cannot tell that from a keyed box.
assert(
    said(p, "The router is locked."),
    "a shut box says it is shut, got: " .. table.concat(t.messages(p), " | ")
)

t.ui_act(p, "toggle", '{"field":"link_lock"}')
t.tick()
panel = t.ui(p)
assert(rows(panel, "link_lock")[1].on, "it opens for whoever is standing at it")

-- A ROOT ACCEPTS HUBS, STATION-WIDE: the thing it is joining is bolted
-- to a wall somewhere else by definition, so a radius would mean
-- nothing. The access point's own lock is not consulted -- a lock
-- refuses gestures aimed AT a node, and this one is aimed at the
-- router.
local offer = row_for(panel, "link_join", point)
assert(offer ~= nil, "the access point is on offer: " .. #rows(panel, "link_join") .. " candidates")
assert(offer.label:find("hub", 1, true), "named by what it is: " .. offer.label)

-- ---------------------------------------------------------------
-- 4. THE JOIN. One press, one edge, one row on the record -- and the
--    edge is permanent until somebody cuts it.
-- ---------------------------------------------------------------
t.ui_act(p, "toggle", string.format('{"field":"link_join","option":"%s"}', point))
t.tick()
panel = t.ui(p)
local held = row_for(panel, "link_drop", point)
assert(held ~= nil, "the panel now holds it")
assert(held.label:find("online", 1, true), "saying what it is doing: " .. held.label)

local joins = t.ledger_rows("link_accepted")
assert(#joins == 1, "one edge, one row")
assert(joins[1].parent == router and joins[1].child == point, "naming both ends")
assert(joins[1].role == "hub", "and what the thing that joined is")

-- THE ANTI-HIJACK RULE. What is joinable is exactly what is UNJOINED,
-- so a bound node never appears on anybody's list again and cannot be
-- re-accepted: nobody walks past a rival's device with a stronger
-- transmitter and takes it (docs/DEVICES.md §3).
assert(#rows(panel, "link_join") == 0, "and it is on nobody's list any more")

-- The sentence again, now that there is something to count -- and it
-- counts in ACCESS POINTS, because a root carries hubs and never
-- devices. The two callers of `lib/network.luau` differ in exactly that
-- one word (content/fixtures/network_router.luau).
t.ui_close(p)
t.tick()
local _ = t.messages(p)
t.click(p, 6, 1, t.target_at(6, 1))
t.tick()
assert(
    said(p, "The router is on the air, carrying one access point."),
    "the router counts what a root holds, got: " .. table.concat(t.messages(p), " | ")
)

-- ---------------------------------------------------------------
-- 5. AND CUT. A release is deliberate and says so.
-- ---------------------------------------------------------------
t.ui_act(p, "toggle", string.format('{"field":"link_drop","option":"%s"}', point))
t.tick()
panel = t.ui(p)
assert(row_for(panel, "link_drop", point) == nil, "the edge is cut")
assert(row_for(panel, "link_join", point) ~= nil, "and it is offerable again")
assert(#t.ledger_rows("link_released") == 1, "with the cut on the record")

t.ui_act(p, "toggle", string.format('{"field":"link_join","option":"%s"}', point))
t.tick()
assert(row_for(t.ui(p), "link_drop", point) ~= nil, "joined again")

-- ---------------------------------------------------------------
-- 6. THE ACCESS POINT'S OWN VIEW, which needs the claim its placement
--    names -- this one was built into the station rather than screwed
--    together by hand, so it has a key and the key is engineering's.
-- ---------------------------------------------------------------
t.ui_close(p)
t.tick()
t.click(p, 4, 1, t.target_at(4, 1, "access_point"))
t.tick()
t.ui_act(p, "toggle", '{"field":"link_lock"}')
t.tick()
assert(not rows(t.ui(p), "link_lock")[1].on, "an empty hand does not open a keyed lock")

take("id_engineering")
t.ui_act(p, "toggle", '{"field":"link_lock"}')
t.tick()
panel = t.ui(p)
assert(rows(panel, "link_lock")[1].on, "the claim does")
assert(readout(panel, "state") == "online", "and it is on the air under the router now")

-- ---------------------------------------------------------------
-- 7. THE LIGHTS GO OUT. Suspension is derived every pass, right behind
--    the power pass, so the branch whose outlet just died is off the
--    air by the tick that killed it -- and the panel says which state
--    it is in rather than simply going blank.
-- ---------------------------------------------------------------
put_down()
t.ui_close(p)
t.tick()
t.click(p, 6, 1, t.target_at(6, 1))
t.tick()
assert(row_for(t.ui(p), "link_drop", point).label:find("online", 1, true),
    "on the air while the breaker is in")

t.outage()
t.run_ticks(60)
panel = t.ui(p)
assert(panel ~= nil, "the panel keeps reporting")
assert(readout(panel, "state") == "unpowered", "the router itself has stopped carrying traffic")
local dark = row_for(panel, "link_drop", point)
assert(dark ~= nil, "the edge survives the outage: a bond is not a signal")
assert(dark.label:find("unpowered", 1, true),
    "and the roster says why it went quiet: " .. dark.label)
