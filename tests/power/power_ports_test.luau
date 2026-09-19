local network_channels = require("@helpers/network_channels")

-- Three lines, and a panel with a port on each of them.
--
-- The engine holds no opinion about what a cable layer is for: a bridge
-- carries one PORT per layer, each of them an input, an output or both,
-- and what a station's wiring MEANS is the sum of the ports its map
-- placed (docs/POWER.md, "Layers and ports"). This bench says all three
-- sentences at once -- a backbone the panel takes from, a room circuit
-- it feeds, and a spare main it also feeds -- and then asks the panel
-- what each of its ports carried.
--
-- The other half is the preference list every consumer shares, 2 -> 1
-- -> 3: a SOCKET wired to its room circuit AND the backbone prefers the
-- backbone and falls through to the room circuit by itself when an
-- electrician parts it, which is the whole point of wiring a fixture to
-- two lines -- and the lamp on that socket's cord never notices.

local function near(got: number, want: number, tol: number, why: string)
    assert(math.abs(got - want) <= tol, why .. ": " .. got .. " vs " .. want)
end

-- The panel at (4, 1) stands on all three lines. The backbone runs the
-- length of the room from the generator; the room circuit runs east
-- from the panel to the near socket; the spare main drops south and
-- runs west to a socket wired to nothing else at all. A fitting stands
-- in cord reach of each (docs/POWER.md, "Outlets and cords").
t.world(
    [==[(
    name: "ports",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base")]), fixture: Some(Generator)),
        'a': (composition: (components: [(component: "station_base")])),
        'o': (composition: (components: [(component: "station_base")]), fixture: Some(Outlet)),
        'l': (composition: (components: [(component: "station_base")]), fixture: Some(Light)),
    },
    rows: [
        "########",
        "#G..a.o#",
        "#lo..l.#",
        "########",
    ],
    structures: [(6, 2, "player_spawn"), (4, 1, "apc")],
    items: [(6, 2, "wirecutters")],
    networks: [
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l3", kind: "cable", facing: 15),
        (x: 4, y: 2, network: "power", channel: "l3", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l3", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l3", kind: "cable", facing: 15),
    ],
    labels: [(4, 1, "Engineering")],
)]==],
    7
)

local p = t.join()
t.tick()
t.run_seconds(3) -- the electrical pass is 0.5 Hz; let one land

-- ---------------------------------------------------------------
-- EVERY LINE IS A LINE. The spare main is not a reserved layer any
-- more: a lamp wired to nothing but blue burns off it.
-- ---------------------------------------------------------------
assert(network_channels.at(2, 2, "power") == "l3", "the west socket is on the blue main alone")
assert(t.lit(1, 2), "and the lamp on its cord is burning")
assert(t.network_feed(2, 2, "power", "lighting") == "l3", "off the line it is standing on")
assert(t.network_segment(2, 2, "power", "l1").segment == nil, "with no red under it at all")

assert(t.lit(5, 2), "the east lamp is burning too")
assert(t.network_feed(6, 1, "power", "lighting") == "l2", "its socket is on the backbone, which comes first")
assert(t.network_segment(6, 1, "power", "l1").segment ~= nil, "though the room circuit runs under it as well")

-- ---------------------------------------------------------------
-- THE PANEL, PORT BY PORT. Three ports, four possible modes, and the watts
-- each one carried on the last pass.
-- ---------------------------------------------------------------
local ports = t.ports_at(4, 1, "power")
assert(ports ~= nil, "the panel answers for its ports")
assert(ports.id == "apc", "and says what it is: " .. ports.id)
local room_port: SpecPort = assert(ports.channels["l1"])
local backbone_port: SpecPort = assert(ports.channels["l2"])
local spare_port: SpecPort = assert(ports.channels["l3"])
assert(ports.energized, "its own pool is carrying")
assert(room_port.mode == "output", "L1 feeds the room: " .. room_port.mode)
assert(backbone_port.mode == "input", "L2 is where it takes from: " .. backbone_port.mode)
assert(spare_port.mode == "output", "L3 feeds the spare main: " .. spare_port.mode)

-- Two lamps, and only one of them on the panel's books: the east
-- socket is wired to the backbone as well, so it prefers that and
-- bypasses the panel entirely. A fitting bills the branch under the
-- socket it reached, never the tile it hangs over.
-- A lit fitting bills range x power x the rate (tg light.dm:307): a
-- stock tube at 6 and 1.0 draws 120 W.
local TUBE_W = 120.0
near(room_port.out_w, 0.0, 1e-9, "the room circuit carries nobody yet")
near(spare_port.out_w, TUBE_W, 0.001, "the spare main carries its lamp")
near(backbone_port.in_w, TUBE_W, 0.001, "and the input port carries that one alone")
near(room_port.in_w, 0.0, 1e-9, "an output port draws nothing in")
assert(t.ports_at(1, 1, "power") == nil, "a generator is not a bridge")

-- ---------------------------------------------------------------
-- THE FALL-THROUGH. Part the backbone under the east socket and it
-- picks up the room circuit by itself, one pass later. Nobody re-wires
-- anything; the preference list is the whole mechanism.
-- ---------------------------------------------------------------
t.click(p, 6, 2, t.target_at(p, 6, 2, "wirecutters"))
t.run_ticks(2)
assert(t.hands(p).held == "wirecutters", "cutters in hand")
t.click_network(p, 6, 1, assert(t.network_instance(6, 1, "power", "l2")))
t.run_seconds(1.5)
assert(network_channels.at(6, 1, "power") == "l1", "the yellow line parted, the red one under it did not")
t.run_seconds(3)

assert(t.lit(5, 2), "the lamp never went out")
assert(t.network_feed(6, 1, "power", "lighting") == "l1", "its socket is on the room circuit now")
near(
    assert(assert(t.ports_at(4, 1, "power")).channels["l1"]).out_w,
    TUBE_W,
    0.001,
    "and the panel's room circuit carries it"
)

-- ---------------------------------------------------------------
-- THE STATION BREAKER. An outage is every port at zero and every pool
-- dark -- including the spare main, which is no more privileged than
-- the other two.
-- ---------------------------------------------------------------
t.outage()
t.run_seconds(3)
assert(t.ledger_has("PowerOutage"), "the trip is on the record")

local dead = assert(t.ports_at(4, 1, "power"))
assert(not dead.energized, "the panel's pool is dark")
local dead_ports: { [string]: SpecPort } =
    { l1 = assert(dead.channels["l1"]), l2 = assert(dead.channels["l2"]), l3 = assert(dead.channels["l3"]) }
for line, port in pairs(dead_ports) do
    near(port.in_w, 0.0, 1e-9, line .. " draws nothing")
    near(port.out_w, 0.0, 1e-9, line .. " feeds nothing")
end
-- The fittings are not the grid's to put out: each drops to the
-- emergency cell in its own casing (content/fixtures/light.luau).
local EMERGENCY_RED = "#FF3232"
assert(assert(t.light_at(1, 2)).color == EMERGENCY_RED, "the spare main's lamp is on its own cell")
assert(assert(t.light_at(5, 2)).color == EMERGENCY_RED, "and so is the one off the room circuit")
local spare = t.network_segment(2, 2, "power", "l3").classes
assert(not spare.equipment and not spare.lighting, "the spare main is carrying no power")
assert(network_channels.at(2, 2, "power") == "l3", "the cable is all still there, of course")
