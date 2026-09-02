-- Heat-exchanging pipe: the run that is SUPPOSED to leak heat.
--
-- Every other length on the station is a sealed tube. This one trades
-- with the air of the tile above it every pass, at tg's window
-- coefficient (0.1, `WINDOW_HEAT_TRANSFER_COEFFICIENT`) behind a 20 K
-- deadband (`minimum_temperature_difference`, he_pipes.dm:2). Two facts
-- make it a piece of kit rather than a leak:
--
--   * it joins only itself (tg's `HE_type_check`, he_pipes.dm:18-21),
--     so a cooling loop is a closed circuit and not a branch of the
--     distribution main -- and the junction is the one thing that opens
--     it (heat_exchange/junction.dm);
--   * it takes no paint, because tg fixes its colour outright
--     (he_pipes.dm:15), the same rule the colour adapter keeps.
--
-- ENERGY IS WHAT IS ASSERTED, not temperature. A run that warmed a room
-- by exactly the right number of degrees while minting the joules would
-- read perfectly on a thermometer, so the conduction scenario weighs
-- `t.pipe_energy` against `t.room_energy` and the deck under it.
--
-- HOW "ONE NET OR TWO" IS ASSERTED: by MOLE COUNT, never by pressure.
-- Every run opens the shift at the same density and the conserving
-- rebuild keeps it that way, so a gauge does not move when a net
-- splits. Ask two tiles how much gas stands in the run under them and
-- you get the same answer if and only if they are the same run --
-- which is why both scenarios below give their two sides different
-- LENGTHS and then ask. (`tests/adapters_test.luau` does the same.)

-- The RPD's dials are numbered by declaration order, as every dial
-- panel is: mode, fitting, piping layer, paint.
local RECIPE = "dial1"

local DISTRO = 4
local PIPE_M3 = 0.070
-- A colour adapter's mouth is tg's UNARY_PIPE_VOLUME, half of the 70 L
-- length of pipe it is (pipes.dm:27-28); the junction is the same
-- primitive and the same volume.
local ADAPTER_PORT_M3 = 0.035
local T20C = 293.15

local function moles(kpa, m3)
    return kpa * 1000.0 * m3 / (8.314 * T20C)
end

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

local function walk(p, dir)
    t.move(p, dir)
    t.run_ticks(5)
end

local function net_moles(x, y, layer)
    local gas = t.pipe_gas(x, y, layer)
    assert(gas ~= nil, "there is a run under (" .. x .. ", " .. y .. ")")
    return (gas.n2 or 0.0) + (gas.o2 or 0.0)
end

-- ---------------------------------------------------------------
-- TWO KINDS TOUCHING ARE STILL TWO RUNS.
--
-- Three lengths of heat-exchanging pipe and two of ordinary pipe, laid
-- end to end on one layer with nothing between them. Every other rule
-- the station has says they are one net: same layer, both reaching, no
-- paint on either. They are not, and the mole counts say so.
-- ---------------------------------------------------------------
t.world([==[(
    name: "heat exchange seam",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "########",
        "#......#",
        "########",
    ],
    spawns: [(6, 1)],
    items: [(6, 1, "pipe_painter")],
    pipes: [(1, 1, 4), (2, 1, 4), (3, 1, 4), (4, 1, 4), (5, 1, 4)],
    pipe_kind: [(1, 1, 4, "he_pipe"), (2, 1, 4, "he_pipe"), (3, 1, 4, "he_pipe")],
)]==], 7)

local p = t.join()
t.tick()

assert(t.pipe(3, 1) == DISTRO, "the last heat-exchange length is laid")
assert(t.pipe(4, 1) == DISTRO, "and the first ordinary one is right beside it")

local seam_kpa = t.pipe_pressure(1, 1)
assert(seam_kpa > 90.0, "both runs open the shift charged: " .. seam_kpa)

local exchange = net_moles(1, 1, DISTRO)
local ordinary = net_moles(5, 1, DISTRO)
near(exchange, moles(seam_kpa, 3 * PIPE_M3), 0.05, "three lengths of heat exchange")
near(ordinary, moles(seam_kpa, 2 * PIPE_M3), 0.05, "two of ordinary pipe")
assert(
    exchange > ordinary + 0.5,
    "and they are not one body of gas: " .. exchange .. " vs " .. ordinary
)
near(net_moles(3, 1, DISTRO), exchange, 0.001, "the tile at the seam is the long run")
near(net_moles(4, 1, DISTRO), ordinary, 0.001, "and the one next to it is the short one")

-- ---- and it takes no paint, and says so ----
--
-- tg fixes the colour at `#404040` with FIXED_COLOUR_PRIORITY
-- (he_pipes.dm:15). A painter that silently changed nothing would be
-- the worst of both, so the refusal is spoken.
t.click(p, 6, 1, t.target_at(6, 1, "pipe_painter"))
t.run_ticks(2)
assert(t.hands(p).held == "pipe_painter", "painter in hand")
walk(p, "west")
walk(p, "west")
local _ = t.messages(p)
t.click(p, 3, 1)
t.run_ticks(4)
assert(said(p, "That pipe has a colour of its own."), "the painter says why")
assert(not t.ledger_has("PipePainted"), "and nothing reached the record")
near(net_moles(1, 1, DISTRO), exchange, 0.001, "the run is exactly as it was")

-- The ordinary run beside it still takes paint like any other, which is
-- what makes the refusal above about the KIND and not about the tile.
-- The painter's dial ships on omni, which is the colour a run already
-- wears, so it is stepped once first.
t.use_self(p)
t.run_ticks(2)
t.click(p, 4, 1)
t.run_ticks(4)
assert(t.ledger_has("PipePainted"), "ordinary pipe still paints")

-- ---------------------------------------------------------------
-- A JUNCTION WELDS THEM INTO ONE.
--
-- tg's junction is the one fitting that takes ordinary pipe on one side
-- and heat-exchanging pipe on the other (heat_exchange/junction.dm).
-- Two lengths of exchange, three of ordinary, and the thing between
-- them: one body of gas, and every tile says the same number.
--
-- Asked twice -- bolted down, then in the engineer's hands -- because a
-- test that only ever sees the joined case is testing the flood.
-- ---------------------------------------------------------------
t.world([==[(
    name: "junction",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "########",
        "#......#",
        "#......#",
        "########",
    ],
    spawns: [(6, 2)],
    items: [(6, 2, "wrench")],
    pipes: [(1, 1, 4), (2, 1, 4), (4, 1, 4), (5, 1, 4), (6, 1, 4)],
    pipe_kind: [(1, 1, 4, "he_pipe"), (2, 1, 4, "he_pipe")],
    structures: [(3, 1, "he_junction")],
)]==], 7)

local j = t.join()
t.tick()

assert(t.structure_at(3, 1).id == "he_junction", "the map stood a junction there")

local junction_kpa = t.pipe_pressure(1, 1)
local FUSED_M3 = 5 * PIPE_M3 + 2 * ADAPTER_PORT_M3
local joined = net_moles(1, 1, DISTRO)
near(joined, moles(junction_kpa, FUSED_M3), 0.05, "both kinds are one body of gas")
near(net_moles(6, 1, DISTRO), joined, 0.001, "the far end of the ordinary run agrees")

-- ---- take it out, and the kinds part again ----
t.click(j, 6, 2, t.target_at(6, 2, "wrench"))
t.run_ticks(2)
assert(t.hands(j).held == "wrench", "wrench in hand")
for _ = 1, 3 do
    walk(j, "west")
end
t.click(j, 3, 1, t.target_at(3, 1, "he_junction"))
t.run_seconds(2.5)
assert(t.structure_at(3, 1) == nil, "the junction comes up off the deck")
assert(t.count_items("he_junction_fitting") == 1, "and hands its fitting back")

local he_side = net_moles(1, 1, DISTRO)
local plain_side = net_moles(6, 1, DISTRO)
near(he_side, moles(junction_kpa, 2 * PIPE_M3), 0.05, "two lengths of exchange, alone")
near(plain_side, moles(junction_kpa, 3 * PIPE_M3), 0.05, "three of ordinary, on theirs")
assert(plain_side > he_side + 0.5, "and they are two bodies of gas again")

-- ---------------------------------------------------------------
-- A HOT RUN WARMS THE ROOM OVER IT, AND ORDINARY PIPE DOES NOT.
--
-- One sealed room with two runs under it on different layers: three
-- lengths of heat-exchanging pipe on layer 3 and three of ordinary pipe
-- on layer 2. Heat goes into BOTH -- `t.heat_pipe` is a precondition
-- setter, not the mechanism -- and only one of them gives any of it up.
--
-- The book is weighed on energy across the whole room: the air, the
-- deck it stands on (docs/matter-world/thermal.md, 5b) and the run.
-- ---------------------------------------------------------------
local L2 = 2
t.world([==[(
    name: "heat exchange room",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#####",
    ],
    spawns: [(2, 1)],
    pipes: [(1, 1, 6), (2, 1, 6), (3, 1, 6)],
    pipe_kind: [(1, 1, 4, "he_pipe"), (2, 1, 4, "he_pipe"), (3, 1, 4, "he_pipe")],
)]==], 7)

local h = t.join()
t.tick()

near(t.pipe_temperature(1, 1, DISTRO), T20C, 0.5, "the exchange run opens at room temperature")
near(t.pipe_temperature(1, 1, L2), T20C, 0.5, "and so does the ordinary one over it")
near(t.room_temperature(2, 1), T20C, 0.5, "as does the air")

-- Enough to matter, and well clear of the 20 K deadband, but nowhere
-- near the 673 K where superconduction would join in.
t.heat_pipe(1, 1, 12000.0, DISTRO)
t.heat_pipe(1, 1, 12000.0, L2)
t.tick()
local hot_he = t.pipe_temperature(1, 1, DISTRO)
local hot_plain = t.pipe_temperature(1, 1, L2)
assert(hot_he > T20C + 50.0, "the exchange run is hot: " .. hot_he)
near(hot_plain, hot_he, 1.0, "and the ordinary run is exactly as hot")

local room_0 = t.room_temperature(2, 1)
local books_0 = t.room_energy(2, 1) + t.deck(2, 1).energy + t.pipe_energy(1, 1, DISTRO)

t.run_seconds(30)

local settled_he = t.pipe_temperature(1, 1, DISTRO)
local settled_plain = t.pipe_temperature(1, 1, L2)
assert(settled_he < hot_he - 20.0, "the exchange run gave heat up: " .. settled_he)
near(settled_plain, hot_plain, 1.0, "the ordinary run gave up none of its own")
assert(
    t.room_temperature(2, 1) > room_0 + 0.5,
    "and the room felt it: " .. room_0 .. " -> " .. t.room_temperature(2, 1)
)

-- The conserved quantity, across the boundary the heat crossed.
local books_1 = t.room_energy(2, 1) + t.deck(2, 1).energy + t.pipe_energy(1, 1, DISTRO)
assert(
    math.abs(books_1 - books_0) < math.abs(books_0) * 0.02,
    "and no joule was minted or lost: " .. books_0 .. " J -> " .. books_1 .. " J"
)

-- ---- the deadband ----
--
-- tg conducts only once the two sides differ by more than
-- `minimum_temperature_difference` (he_pipes.dm:38). Left alone, the
-- run and the room close to within that band and then stop, rather than
-- crawling to equality forever.
local parked_pipe = t.pipe_temperature(1, 1, DISTRO)
local parked_room = t.room_temperature(2, 1)
t.run_seconds(120)
assert(
    math.abs(t.pipe_temperature(1, 1, DISTRO) - t.room_temperature(2, 1)) > 0.0,
    "the two never have to meet"
)
assert(
    t.pipe_temperature(1, 1, DISTRO) <= parked_pipe + 0.5,
    "the run only ever cooled: " .. parked_pipe .. " -> " .. t.pipe_temperature(1, 1, DISTRO)
)
local _ = parked_room

-- ---------------------------------------------------------------
-- THE SHELF AND THE DISPENSER OFFER IT.
--
-- tg's "Heat Exchange" category (`GLOB.atmos_pipe_recipes`,
-- _globalvars/lists/pipe_recipes.dm:29-34). tg lists Pipe, Manifold and
-- 4-Way Manifold as three objects; a length's shape is derived from
-- what it joins here, so one "Pipe" entry covers all three, and the
-- plate tg lists last was already on the shelf.
-- ---------------------------------------------------------------
t.world([==[(
    name: "heat exchange shelf",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "#####",
        "#o..#",
        "#a.g#",
        "#####",
    ],
    spawns: [(3, 1)],
    items: [(3, 1, "rpd")],
    machines: [(2, 1, "pipe_dispenser")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3),
    ],
)]==], 7)

local e = t.join()
t.tick()

-- ---- the machine on the wall ----
t.click(e, 2, 1, t.target_at(2, 1))
t.tick()
local shelf = {}
for _, rec in ipairs(t.ui(e).products) do
    shelf[rec.payload.product] = rec
end
assert(shelf.he_pipe, "the dispenser stocks a length of heat-exchanging pipe")
assert(shelf.he_pipe.category == "Heat Exchange", "under tg's own heading")
assert(shelf.he_pipe.label == "Pipe", "by tg's own word for it")
assert(shelf.he_junction_fitting.label == "Junction", "and the junction beside it")
assert(shelf.he_junction_fitting.category == "Heat Exchange")
assert(
    shelf.heat_exchanger_fitting.category == "Heat Exchange",
    "with the plate that was already there"
)
t.ui_close(e)
t.run_ticks(2)

-- ---- and the gun in your hand ----
t.click(e, 3, 1, t.target_at(3, 1, "rpd"))
t.run_ticks(2)
assert(t.hands(e).held == "rpd", "the RPD is in hand")
t.use_self(e)
t.tick()

local offered = {}
for _, tog in ipairs(t.ui(e).toggles) do
    if tog.field == RECIPE and tog.option ~= nil and tog.group == "Heat Exchange" then
        offered[tog.label] = tog.icon
    end
end
assert(offered["Pipe"] == "he_pipe", "the shelf offers a length, with its own picture")
assert(offered["Junction"] == "he_junction_loose", "and the junction that meets ordinary pipe")
