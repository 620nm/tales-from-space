-- Three lines, and a panel with a port on each of them.
--
-- The engine holds no opinion about what a cable colour is for: a bridge
-- carries one PORT per colour, each of them an input, an output or both,
-- and what a station's wiring MEANS is the sum of the ports its map
-- placed (docs/POWER.md, "Bridges and their ports"). This bench says all three
-- sentences at once -- a backbone the panel takes from, a room circuit
-- it feeds, and a spare main it also feeds -- and then asks the panel
-- what each of its ports carried.
--
-- The other half is the preference list every consumer shares, 1 -> 3
-- -> 2: a SOCKET wired to its room circuit AND the backbone prefers the
-- room circuit and falls through by itself when an electrician parts
-- it, which is the whole point of wiring a fixture to two lines -- and
-- the lamp on that socket's cord never notices.

local function near(got, want, tol, why)
    assert(math.abs(got - want) <= tol, why .. ": " .. got .. " vs " .. want)
end

-- The panel at (4, 1) stands on all three lines. The backbone runs the
-- length of the room from the generator; the room circuit runs east
-- from the panel to the near socket; the spare main drops south and
-- runs west to a socket wired to nothing else at all. A fitting stands
-- in cord reach of each (docs/POWER.md, "Outlets and cords").
t.world([==[(
    name: "ports",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'G': (turf: Plating, fixture: Some(Generator)),
        'a': (turf: Plating, fixture: Some(Apc)),
        'o': (turf: Plating, fixture: Some(Outlet)),
        'l': (turf: Plating, fixture: Some(Light)),
    },
    rows: [
        "########",
        "#G..a.o#",
        "#lo..l.#",
        "########",
    ],
    spawns: [(6, 2)],
    items: [(6, 2, "wirecutters")],
    cables: [
        (1, 1, 2, 0, 4), (2, 1, 2, 4, 8), (3, 1, 2, 4, 8), (4, 1, 2, 0, 4),
        (4, 1, 2, 0, 8), (5, 1, 2, 4, 8), (6, 1, 2, 0, 8),
        (4, 1, 1, 0, 4), (5, 1, 1, 4, 8), (6, 1, 1, 0, 8),
        (4, 1, 4, 0, 2), (4, 2, 4, 1, 8), (3, 2, 4, 4, 8), (2, 2, 4, 0, 4),
    ],
    labels: [(4, 1, "Engineering")],
)]==], 7)

local p = t.join()
t.tick()
t.run_seconds(3) -- the electrical pass is 0.5 Hz; let one land

-- ---------------------------------------------------------------
-- EVERY LINE IS A LINE. The spare main is not a reserved layer any
-- more: a lamp wired to nothing but blue burns off it.
-- ---------------------------------------------------------------
assert(t.cable_at(2, 2) == 4, "the west socket is on the blue main alone")
assert(t.lit(1, 2), "and the lamp on its cord is burning")
assert(t.segment_at(2, 2).lighting_feed == 4, "off the line it is standing on")
assert(t.segment_at(2, 2).l1 == nil, "with no red under it at all")

assert(t.lit(5, 2), "the east lamp is burning too")
assert(t.segment_at(6, 1).lighting_feed == 1,
    "its socket is on the room circuit, which comes first")
assert(t.segment_at(6, 1).l2 ~= nil, "though the backbone runs under it as well")

-- ---------------------------------------------------------------
-- THE PANEL, PORT BY PORT. Three ports, three modes, and the watts
-- each one carried on the last pass.
-- ---------------------------------------------------------------
local ports = t.ports_at(4, 1)
assert(ports ~= nil, "the panel answers for its ports")
assert(ports.kind == "apc", "and says what it is: " .. ports.kind)
assert(ports.energized, "its own pool is carrying")
assert(ports.l1.mode == "output", "L1 feeds the room: " .. ports.l1.mode)
assert(ports.l2.mode == "input", "L2 is where it takes from: " .. ports.l2.mode)
assert(ports.l3.mode == "output", "L3 feeds the spare main: " .. ports.l3.mode)

-- Two lamps, one socket on each output port, and the input port
-- carrying both: a fitting bills the branch under the socket it
-- reached, never the tile it hangs over.
near(ports.l1.out_w, 20.0, 0.001, "the room circuit carries its lamp")
near(ports.l3.out_w, 20.0, 0.001, "so does the spare main")
near(ports.l2.in_w, 40.0, 0.001, "and the input port carries the pair")
near(ports.l1.in_w, 0.0, 1e-9, "an output port draws nothing in")
assert(t.ports_at(1, 1) == nil, "a generator is not a bridge")

-- ---------------------------------------------------------------
-- THE FALL-THROUGH. Part the room circuit under the east socket and it
-- picks up the backbone by itself, one pass later. Nobody re-wires
-- anything; the preference list is the whole mechanism.
-- ---------------------------------------------------------------
t.click(p, 6, 2, t.target_at(6, 2, "wirecutters"))
t.run_ticks(2)
assert(t.hands(p).held == "wirecutters", "cutters in hand")
t.click_subfloor(p, 6, 1, "cable", 1, 0, 8)
t.run_seconds(1.5)
assert(t.cable_at(6, 1) == 2, "the red line parted, the yellow one under it did not")
t.run_seconds(3)

assert(t.lit(5, 2), "the lamp never went out")
assert(t.segment_at(6, 1).lighting_feed == 2, "its socket is on the backbone now")
near(t.ports_at(4, 1).l1.out_w, 0.0, 1e-9, "and the panel's room circuit is idle")

-- ---------------------------------------------------------------
-- THE STATION BREAKER. An outage is every port at zero and every pool
-- dark -- including the spare main, which is no more privileged than
-- the other two.
-- ---------------------------------------------------------------
t.outage()
t.run_seconds(3)
assert(t.ledger_has("PowerOutage"), "the trip is on the record")

local dead = t.ports_at(4, 1)
assert(not dead.energized, "the panel's pool is dark")
for _, line in ipairs({ "l1", "l2", "l3" }) do
    near(dead[line].in_w, 0.0, 1e-9, line .. " draws nothing")
    near(dead[line].out_w, 0.0, 1e-9, line .. " feeds nothing")
end
assert(not t.lit(1, 2), "the lamp off the spare main is out")
assert(not t.lit(5, 2), "and so is the one off the backbone")
assert(t.segment_at(2, 2).live == false, "no line anywhere is carrying")
assert(t.cable_at(2, 2) == 4, "the cable is all still there, of course")
