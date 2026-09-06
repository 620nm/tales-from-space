-- A station down to its cells, and the two things it does about it.
--
-- An APC that has lost its mains runs the room off the cell in its own
-- casing. It cannot run the WHOLE room off it -- that is the point of
-- a reserve -- so the map says which of the panel's output layers are
-- worth the charge (`l1_emergency` and its two siblings,
-- docs/power/map-format.md) and the panel feeds those and lets the
-- rest go dark. Both shipped stations flag L1, because L1 is the room
-- circuit on both.
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
--     layer the panel let go is dark, with nothing touched but the
--     wire under it. The one on the flagged layer is still burning
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
t.world([==[(
    name: "reserve",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'G': (turf: Plating, fixture: Some(Generator)),
        'o': (turf: Plating, fixture: Some(Outlet)),
        'l': (turf: Plating, fixture: Some(Light)),
    },
    rows: [
        "############",
        "#G....o#..o#",
        "#....l.#..l#",
        "############",
    ],
    structures: [
        (4, 1, "apc", { "l1_emergency": true }),
    ],
    spawns: [(3, 2)],
    items: [(3, 2, "wirecutters"), (3, 2, "cable_coil")],
    cables: [
        (1, 1, 2), (2, 1, 2), (3, 1, 2), (4, 1, 2),
        (4, 1, 1), (5, 1, 1), (6, 1, 1),
        (4, 1, 4), (5, 1, 4), (6, 1, 4), (7, 1, 4), (8, 1, 4), (9, 1, 4), (10, 1, 4),
    ],
    labels: [(4, 1, "Engineering")],
)]==], 0)

local p = t.join()
t.tick()
t.run_seconds(3) -- the electrical pass is 0.5 Hz; let one land
t.run_ticks(40) -- and the device pass, which is what sews the fittings

-- ---------------------------------------------------------------
-- 1. THE MAINS ARE UP. Both lamps green on the port that stands on
--    both lines, both fittings burning at what their own prototype
--    says a tube throws.
-- ---------------------------------------------------------------
local both = t.outlet_at(6, 1)
assert(both ~= nil, "the port on the room circuit answers")
assert(both.l1 == "nominal", "the room circuit is carrying: " .. both.l1)
assert(both.l3 == "nominal", "so is the spare main: " .. both.l3)
assert(both.feed == 1, "and it draws off the room circuit: " .. tostring(both.feed))

local blue = t.outlet_at(10, 1)
assert(blue.l3 == "nominal", "the far port is carrying too: " .. blue.l3)

local near = t.light_at(5, 2)
local far = t.light_at(10, 2)
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
t.click(p, 3, 2, t.target_at(3, 2, "wirecutters"))
t.run_ticks(2)
assert(t.hands(p).held == "wirecutters", "cutters in hand")
t.click_subfloor(p, 3, 1, "cable", 2)
t.run_seconds(1.5)
assert(t.cable_at(3, 1) == 0, "the backbone is parted")
t.run_seconds(3)
t.run_ticks(40)

assert(t.apc_at(4, 1).charging == "not_charging", "nothing is topping the panel up")
assert(t.apc_at(4, 1).charge > 0.0, "and it still has a cell to run on")

both = t.outlet_at(6, 1)
assert(both.l1 == "emergency", "the flagged layer is carrying off the reserve: " .. both.l1)
assert(both.l3 == "starved", "the unflagged one has a source that stopped: " .. both.l3)
assert(both.feed == 1, "so the port draws off the flagged layer alone")

blue = t.outlet_at(10, 1)
assert(blue.l3 == "starved", "the far port's only layer went with it: " .. blue.l3)
assert(not blue.powered, "so the far port is dead")

-- ---------------------------------------------------------------
-- 3. THE ROOM GOES DOWN, NOT OUT. The fitting on the flagged layer is
--    still burning and is dimmer, and the one on the unflagged layer
--    is dark. That is the whole point of flagging a layer: a blackout
--    leaves a room a person can walk out of. The dimming is content:
--    a flag from the panel, read by the fitting, looked up in the
--    pack's own table.
-- ---------------------------------------------------------------
near = t.light_at(5, 2)
far = t.light_at(10, 2)
assert(near.lit and near.emits, "the fitting on the reserve is still burning")
assert(math.abs(near.power - 0.5) < 1e-6, "turned down: " .. near.power)
assert(near.color == TUBE, "still the colour of its own tube: " .. near.color)
assert(math.abs(near.range - 6.0) < 1e-6, "reach is untouched: a dim room is not a smaller one")
assert(not far.emits, "the fitting on the dark layer throws nothing")

-- ---------------------------------------------------------------
-- 4. THE MAINS COME BACK. Lay the parted length again and everything
--    unwinds: the lamps, the flag and the fitting's own power. A coil
--    lays yellow by default, which is the layer that was cut
--    (tests/cable_test.luau).
-- ---------------------------------------------------------------
t.drop(p)
t.run_ticks(2)
t.click(p, 3, 2, t.target_at(3, 2, "cable_coil"))
t.run_ticks(2)
t.click(p, 3, 1)
t.run_seconds(1.5)
assert(t.cable_at(3, 1) == 2, "the backbone is whole again")
t.run_seconds(3)
t.run_ticks(40)

both = t.outlet_at(6, 1)
assert(both.l1 == "nominal", "the room circuit is off the mains again: " .. both.l1)
assert(both.l3 == "nominal", "and so is the spare main: " .. both.l3)

near = t.light_at(5, 2)
assert(math.abs(near.power - 1.0) < 1e-6, "the fitting is back up: " .. near.power)
assert(near.color == TUBE, "the fitting kept the tube it always had")
assert(t.light_at(10, 2).emits, "and the dark one is burning again")
