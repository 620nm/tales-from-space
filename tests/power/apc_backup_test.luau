local network_channels = require("@helpers/network_channels")

-- A station down to its cells, and the two things it does about it.
--
-- An APC that has lost its mains runs the room off the cell in its own
-- casing. It cannot run the WHOLE room off it -- that is the point of
-- a reserve -- so the map says which of the panel's output layers are
-- worth the charge (`l1_reserve` and its two siblings,
-- docs/power/map-format.md) and the panel feeds those and lets the
-- rest go dark. Commissioned room circuits flag L1, because L1 is the room
-- circuit.
--
-- What a crewman sees is two things at once, and this spec asserts
-- both:
--
--   * THE PORTS say which is which. A flagged layer still carrying
--     reads `emergency` rather than `nominal` -- carrying, but only
--     off a reserve -- and an unflagged one reads `starved`, which is
--     the word for a run with a source on it that is not supplying.
--     Those are the two lamp words tests/uop_test.luau cannot reach,
--     and this is where they live.
--
--   * THE FITTINGS follow the lamps, and then some. The one on the
--     layer the panel let go drops to the emergency cell in its own
--     casing and burns tg's dim red (content/fixtures/light.luau), with
--     nothing touched but the wire under it. The one on the flagged
--     layer is still burning
--     AND is dimmer: the panel puts a `low_power` flag on its own
--     network as it crosses, and every fitting it feeds is a
--     hardwired child of it and hears the flag as coming from its
--     parent (content/fixtures/apc.luau, content/fixtures/light.luau).
--     A room on batteries dims without anybody wiring a light to a
--     panel.
--
-- The flag carries no colour, deliberately: a station on its cells is
-- not an emergency anybody needs colour-coding, it is a station with
-- the lights turned down, which is what a building running off
-- batteries looks like.

-- The bench: a generator on the yellow backbone into a panel flagged
-- for L1, a red room circuit and a blue spare main running east out of
-- it, a port on both and -- through a wall the blue main runs under --
-- a port on blue alone, each with a fitting in cord reach. The wall is
-- load-bearing: a cord reaches the NEAREST port it can walk to, so
-- without it the far fitting would simply plug into the near one and
-- the whole point of the second circuit would be invisible. The panel
-- is placed rather than laid in the legend because the reserve flag is
-- a PLACEMENT property.
t.world(
    [==[(
    name: "reserve",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base")]), fixture: Some(Generator)),
        'o': (composition: (components: [(component: "station_base")]), fixture: Some(Outlet)),
        'l': (composition: (components: [(component: "station_base")]), fixture: Some(Light)),
    },
    rows: [
        "############",
        "#G....o#..o#",
        "#....l.#..l#",
        "############",
    ],
    structures: [
        (3, 2, "player_spawn"),
        (4, 1, "apc", { "l1_reserve": true }),
    ],
    items: [(3, 2, "wirecutters"), (3, 2, "cable_coil")],
    networks: [
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l3", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l3", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l3", kind: "cable", facing: 15),
        (x: 7, y: 1, network: "power", channel: "l3", kind: "cable", facing: 15),
        (x: 8, y: 1, network: "power", channel: "l3", kind: "cable", facing: 15),
        (x: 9, y: 1, network: "power", channel: "l3", kind: "cable", facing: 15),
        (x: 10, y: 1, network: "power", channel: "l3", kind: "cable", facing: 15),
    ],
    labels: [(4, 1, "Engineering")],
)]==],
    0
)

local p = t.join()
t.tick()
t.run_seconds(3) -- the electrical pass is 0.5 Hz; let one land
t.run_ticks(40) -- and the device pass, which is what sews the fittings

-- ---------------------------------------------------------------
-- 1. THE MAINS ARE UP. Both lamps green on the port that stands on
--    both lines, both fittings burning at what their own prototype
--    says a tube throws.
-- ---------------------------------------------------------------
local both = assert(t.outlet_at(6, 1))
assert(both ~= nil, "the port on the room circuit answers")
assert(both.channels["l1"] == "nominal", "the room circuit is carrying: " .. both.channels["l1"])
assert(both.channels["l3"] == "nominal", "so is the spare main: " .. both.channels["l3"])
assert(both.feed == "l1", "and it draws off the room circuit: " .. tostring(both.feed))

local blue = assert(t.outlet_at(10, 1))
assert(blue.channels["l3"] == "nominal", "the far port is carrying too: " .. blue.channels["l3"])

local near = assert(t.light_at(5, 2))
local far = assert(t.light_at(10, 2))
assert(near.lit and near.emits, "the near fitting is burning")
assert(far.lit and far.emits, "and so is the far one")
assert(math.abs(near.power - 1.0) < 1e-6, "at its own power: " .. near.power)
local TUBE = near.color

-- ---------------------------------------------------------------
-- 2. THE MAINS GO. Part the backbone between the generator and the
--    panel: nothing is feeding the panel's input any more, so it is
--    on its own cell -- and a cell is exactly what tells the two
--    layers apart.
-- ---------------------------------------------------------------
t.click(p, 3, 2, t.target_at(p, 3, 2, "wirecutters"))
t.run_ticks(2)
assert(t.hands(p).held == "wirecutters", "cutters in hand")
t.click_network(p, 3, 1, assert(t.network_instance(3, 1, "power", "l2")))
t.run_seconds(1.5)
assert(network_channels.at(3, 1, "power") == "", "the backbone is parted")
t.run_seconds(3)
t.run_ticks(40)

assert(assert(t.store_at(4, 1)).charging == "idle", "nothing is topping the panel up")
assert(assert(t.store_at(4, 1)).level > 0.0, "and it still has a cell to run on")

both = assert(t.outlet_at(6, 1))
assert(both.channels["l1"] == "emergency", "the flagged layer is carrying off the reserve: " .. both.channels["l1"])
assert(both.channels["l3"] == "starved", "the unflagged one has a source that stopped: " .. both.channels["l3"])
assert(both.feed == "l1", "so the port draws off the flagged layer alone")

blue = assert(t.outlet_at(10, 1))
assert(blue.channels["l3"] == "starved", "the far port's only layer went with it: " .. blue.channels["l3"])
assert(not blue.powered, "so the far port is dead")

-- ---------------------------------------------------------------
-- 3. THE ROOM GOES DOWN, NOT OUT. The fitting on the flagged layer is
--    still burning and is dimmer, and the one on the unflagged layer
--    is on its own cell in tg's emergency red at a quarter of its
--    reach (light.dm:67-73). That is the whole point of flagging a
--    layer: a blackout leaves a room a person can walk out of. Both
--    looks are content: a flag from the panel, or the fitting's own
--    source edge, looked up in the pack's own table.
-- ---------------------------------------------------------------
near = assert(t.light_at(5, 2))
far = assert(t.light_at(10, 2))
assert(near.lit and near.emits, "the fitting on the reserve is still burning")
assert(math.abs(near.power - 0.5) < 1e-6, "turned down: " .. near.power)
assert(near.color == TUBE, "still the colour of its own tube: " .. near.color)
assert(math.abs(near.range - 6.0) < 1e-6, "reach is untouched: a dim room is not a smaller one")
assert(far.lit and far.emits, "the fitting on the dark layer runs off its own cell")
assert(far.color == "#FF3232", "in tg's emergency red: " .. far.color)
assert(math.abs(far.range - 1.5) < 1e-6, "at a quarter of its reach: " .. far.range)
assert(math.abs(far.power - 0.75) < 0.01, "and three quarters of its power: " .. far.power)

-- ---------------------------------------------------------------
-- 4. THE MAINS COME BACK. Lay the parted length again and everything
--    unwinds: the lamps, the flag and the fitting's own power. A coil
--    lays yellow by default, which is the layer that was cut
--    (tests/cable_test.luau).
-- ---------------------------------------------------------------
t.drop(p)
t.run_ticks(2)
t.click(p, 3, 2, t.target_at(p, 3, 2, "cable_coil"))
t.run_ticks(2)
t.click(p, 3, 1)
t.run_seconds(1.5)
assert(network_channels.at(3, 1, "power") == "l2", "the backbone is whole again")
t.run_seconds(3)
t.run_ticks(40)

both = assert(t.outlet_at(6, 1))
assert(both.channels["l1"] == "nominal", "the room circuit is off the mains again: " .. both.channels["l1"])
assert(both.channels["l3"] == "nominal", "and so is the spare main: " .. both.channels["l3"])

near = assert(t.light_at(5, 2))
assert(math.abs(near.power - 1.0) < 1e-6, "the fitting is back up: " .. near.power)
assert(near.color == TUBE, "the fitting kept the tube it always had")
far = assert(t.light_at(10, 2))
assert(far.emits and far.color == TUBE, "and the far one is back on the mains in its own colour")
