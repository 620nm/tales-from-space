-- The three lamps on a utility outlet port, and what each of them
-- means.
--
-- A port is the one place on the deck where the wiring under it is
-- READABLE. Everything else about a circuit is invisible: a crewman
-- standing in a lit room cannot tell a backbone from a room circuit,
-- or a parted cable from a panel with its breaker thrown, and the
-- difference is exactly what an electrician has to know. So a port
-- carries one lamp per cable layer beneath it, each answering a
-- different question about that layer alone
-- (docs/content-schema/fixture-states.md):
--
--   disconnected  no cable of that layer under the port at all
--   inactive      cable, and nothing on its run that could supply it
--   starved       something could supply it; the run is not carrying
--   emergency     carrying, but only off a panel's reserve
--   nominal       carrying
--
-- WHICH LAYER IT DRAWS FROM is a separate fact and not one of the
-- lamps: it is the first live layer in the station's order, L2 before
-- L1 before L3 (docs/power/topology.md). Three green lamps mean a
-- choice was made, not that three things are being drawn from -- so
-- this bench parts one line at a time and watches the choice walk down
-- the list without anybody rewiring anything.
--
-- `emergency` is the one word not asserted here: it needs a panel
-- running down its own cell with the layer flagged worth the reserve,
-- which is the whole subject of tests/apc_backup_test.luau.

-- The bench. A generator on the yellow backbone runs east to a panel,
-- which opens a red room circuit and a blue spare main and runs both
-- east to a port standing on all three. A second port sits on a red
-- spur alone. A third stands on bare plating. A fourth stands on a
-- length of blue cable connected to nothing whatsoever, which is the
-- only way to get a lamp to say `inactive` -- a run with no supply on
-- it at all.
t.world([==[(
    name: "ports and lamps",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'G': (turf: Plating, fixture: Some(Generator)),
        'a': (turf: Plating, fixture: Some(Apc)),
        'o': (turf: Plating, fixture: Some(Outlet)),
    },
    rows: [
        "##########",
        "#G..a..o.#",
        "#.o..o..o#",
        "##########",
    ],
    spawns: [(6, 2)],
    items: [(6, 2, "wirecutters")],
    cables: [
        (1, 1, 2), (2, 1, 2), (3, 1, 2), (4, 1, 2), (5, 1, 2), (6, 1, 2), (7, 1, 2),
        (4, 1, 1), (5, 1, 1), (6, 1, 1), (7, 1, 1), (5, 2, 1),
        (4, 1, 4), (5, 1, 4), (6, 1, 4), (7, 1, 4),
        (8, 2, 4),
    ],
    labels: [(4, 1, "Engineering")],
)]==], 0)

local p = t.join()
t.tick()
t.run_seconds(3) -- the electrical pass is 0.5 Hz; let one land

-- ---------------------------------------------------------------
-- 1. A PORT ON NOTHING. Three dark lamps, no layer bound, and no
--    panel behind it -- which is the honest report for a bollard
--    somebody bolted down and never wired.
-- ---------------------------------------------------------------
local bare = t.outlet_at(2, 2)
assert(bare ~= nil, "the port on bare plating answers")
assert(bare.l1 == "disconnected", "no red under it: " .. bare.l1)
assert(bare.l2 == "disconnected", "no yellow under it: " .. bare.l2)
assert(bare.l3 == "disconnected", "no blue under it: " .. bare.l3)
assert(bare.feed == nil, "so there is nothing to bind to")
assert(not bare.powered, "and nothing to draw")
assert(bare.feeder == nil, "and no panel to name")

-- ---------------------------------------------------------------
-- 2. A PORT ON A DEAD END. There IS cable under this one, and that is
--    the whole difference: `inactive` says the layer exists and its
--    run has nothing on it that could ever supply it, where
--    `disconnected` says there is no layer at all. An electrician
--    reading the two knows whether to lay cable or to find the panel.
-- ---------------------------------------------------------------
local stub = t.outlet_at(8, 2)
assert(stub.l3 == "inactive", "blue cable on a run with no supply: " .. stub.l3)
assert(stub.l1 == "disconnected" and stub.l2 == "disconnected",
    "and nothing else under it")
assert(stub.feed == nil, "an unsupplied layer is not something to bind to")

-- ---------------------------------------------------------------
-- 3. A PORT ON ALL THREE. Every lamp green, and the bound layer is
--    the backbone -- first in the preference list, and nothing about
--    the other two says otherwise.
-- ---------------------------------------------------------------
local all = t.outlet_at(7, 1)
assert(all.l1 == "nominal", "the room circuit is carrying: " .. all.l1)
assert(all.l2 == "nominal", "so is the backbone: " .. all.l2)
assert(all.l3 == "nominal", "and so is the spare main: " .. all.l3)
assert(all.powered, "so the port is live")
assert(all.feed == 2, "and it draws off the backbone: " .. tostring(all.feed))

-- The port on the red spur alone reaches the same power by the only
-- layer it has, and names the panel that opened that circuit.
local spur = t.outlet_at(5, 2)
assert(spur.l1 == "nominal", "the spur is carrying: " .. spur.l1)
assert(spur.l2 == "disconnected" and spur.l3 == "disconnected", "and stands on nothing else")
assert(spur.feed == 1, "so it binds to the one layer it has")
assert(spur.feeder ~= nil, "with a panel behind it")

-- ---------------------------------------------------------------
-- 4. THE CHOICE WALKS DOWN THE LIST. Part the backbone east of the
--    panel and the port on all three falls through to the red circuit
--    -- one pass later, with nobody rewiring anything. The parted
--    layer reads `inactive`, not `starved`: the panel takes FROM the
--    backbone rather than feeding it, so the far half of a cut
--    backbone has no supply on it at all.
-- ---------------------------------------------------------------
t.click(p, 6, 2, t.target_at(p, 6, 2, "wirecutters"))
t.run_ticks(2)
assert(t.hands(p).held == "wirecutters", "cutters in hand")

t.click_subfloor(p, 6, 1, "cable", 2)
t.run_seconds(1.5)
t.run_seconds(3)
all = t.outlet_at(7, 1)
assert(all.l2 == "inactive", "the parted backbone has no supply behind it: " .. all.l2)
assert(all.l1 == "nominal", "the room circuit never noticed")
assert(all.feed == 1, "so the port draws off it instead: " .. tostring(all.feed))

-- ...and again, onto the spare main, which is last only because the
-- list says so.
t.click_subfloor(p, 6, 1, "cable", 1)
t.run_seconds(1.5)
t.run_seconds(3)
all = t.outlet_at(7, 1)
assert(all.l1 == "inactive", "the room circuit is parted too: " .. all.l1)
assert(all.l3 == "nominal", "the spare main is still carrying")
assert(all.feed == 4, "so the port ends up on blue: " .. tostring(all.feed))

-- ---------------------------------------------------------------
-- 5. STARVED IS NOT INACTIVE. Throw the panel's main breaker and the
--    circuits it opens stop carrying -- but the panel is still a
--    declared source sitting on them, so the lamps say the run is
--    starved rather than that there is nothing to feed it. That is
--    the difference between "find a cable" and "find the panel", and
--    it is the whole reason a port wears five words instead of two.
-- ---------------------------------------------------------------
t.drop(p) -- an empty hand, or the click is a tool going into the panel
t.run_ticks(2)
t.move(p, "west")
t.run_ticks(5)
t.move(p, "west")
t.run_ticks(5)
t.click(p, 4, 1, t.target_at(p, 4, 1))
t.tick()
assert(t.ui(p) ~= nil, "the panel opens")
ui_controls.toggle(p, "breaker")
t.run_seconds(3)
assert(not t.apc_at(4, 1).operating, "the breaker is open")

local starved = t.outlet_at(5, 2)
assert(starved.l1 == "starved", "the run is fed by a panel that stopped: " .. starved.l1)
assert(not starved.powered, "so the port is dead")
assert(starved.feed == nil, "with nothing live to bind to")

all = t.outlet_at(7, 1)
assert(all.l3 == "starved", "the spare main is starved for the same reason: " .. all.l3)
assert(all.l2 == "inactive", "where the parted backbone still has no source at all")

-- Close it again and the room comes back exactly as it was.
ui_controls.toggle(p, "breaker")
t.run_seconds(3)
assert(t.outlet_at(5, 2).l1 == "nominal", "the spur is carrying again")
assert(t.outlet_at(7, 1).feed == 4, "and the port is back on blue")

-- ---------------------------------------------------------------
-- 6. THE PANEL BEHIND IT. A port names the panel feeding the layer it
--    bound to, which is the other half of what an electrician came to
--    read: a lamp says the run is dead, and the feeder says whose
--    breaker to go and look at. A port on a run no panel supplies
--    names nobody.
-- ---------------------------------------------------------------
assert(t.outlet_at(7, 1).feeder ~= nil, "the port on the spare main has a panel behind it")
assert(t.outlet_at(8, 2).feeder == nil, "the dead-end port has none")
assert(t.outlet_at(2, 2).feeder == nil, "and neither has the one on bare plating")

-- `starved` and `emergency` are the two words a bench like this cannot
-- reach: both need a panel down to its own cell, which is the whole
-- subject of tests/apc_backup_test.luau and is staged there.
