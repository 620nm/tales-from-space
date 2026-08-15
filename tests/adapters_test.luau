-- The two lengths of pipe that break the rules the rest of the plumbing
-- is built on.
--
-- Two rules keep a station's runs apart, and both are load-bearing.
-- LAYERS: five piping layers cross every tile and never meet, which is
-- what lets a supply main and a scrubber line share a corridor.
-- COLOUR: two pipe ends only join when their paint agrees (tg's
-- `is_connectable`), which is what makes a stripe of the wrong colour
-- across a main CUT it.
--
-- Each rule has exactly one machine that suspends it, and neither is a
-- machine at all -- tg files both under
-- `/obj/machinery/atmospherics/pipe`, not `/components/`. No switch, no
-- power, no direction of flow. They are pipe with an attribute.
--
-- HOW "ONE NET" IS ASSERTED. Not by pressure: every run on the station
-- opens the shift at the same density, and the conserving rebuild keeps
-- it that way -- pull a length out of a net and it loses that length's
-- gas AND that length's volume, so the gauge does not move. What moves
-- is the MOLE COUNT, because a pipenet is one body of gas in one cell:
-- ask two tiles how much gas is standing in the run under them and you
-- get the same answer if and only if they are the same run. So both
-- scenarios below deliberately give their two sides DIFFERENT lengths,
-- and then ask.
--
-- And each one asks twice -- once with the adapter bolted down, once
-- with it in the engineer's hands -- because a test that only ever sees
-- the joined case is not testing the adapter, it is testing the flood.

local L2 = 2
local L4 = 8
local DISTRO = 4

local PIPE_M3 = 0.070
-- A manifold's mouth is a tenth of the 200 L its own file declares
-- (layermanifold.dm:11); a colour adapter's is tg's UNARY_PIPE_VOLUME,
-- half of the 70 L length of pipe it is (pipes.dm:27-28).
local MANIFOLD_PORT_M3 = 0.020
local ADAPTER_PORT_M3 = 0.035
local ROOM_M3 = 12.0

local function moles(kpa, m3)
    return kpa * 1000.0 * m3 / (8.314 * 293.15)
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

-- How much gas is standing in the run under a tile. The reading an
-- analyser gives, and the one that can tell one net from two.
local function net_moles(x, y, layer)
    local gas = t.pipe_gas(x, y, layer)
    assert(gas ~= nil, "there is a run under (" .. x .. ", " .. y .. ")")
    return (gas.n2 or 0.0) + (gas.o2 or 0.0)
end

-- ---------------------------------------------------------------
-- A LAYER ADAPTER MAKES TEN RUNS INTO ONE.
--
-- tg's layer manifold finds a connection at BOTH of its ends on EVERY
-- piping layer and hands all of them to one pipeline
-- (`find_all_connections`/`pipeline_expansion`,
-- layermanifold.dm:90-114).
--
-- The map plumbs two of the five layers through one adapter and runs
-- them AWAY from each other so no tile is ambiguous: layer 2 goes
-- east-west along the top row, layer 4 drops south into the second.
-- Four separate runs by every rule the station has, of three different
-- lengths -- and one body of gas, because of the thing standing at
-- (3, 1).
-- ---------------------------------------------------------------
t.world([==[(
    name: "layer adapter",
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
    pipes: [
        // Layer 2 along the top row: two lengths west of the adapter,
        // THREE east of it. The asymmetry is the whole instrument.
        (1, 1, 2), (2, 1, 2), (4, 1, 2), (5, 1, 2), (6, 1, 2),
        // Layer 4, dropping south out of the same two tiles.
        (2, 1, 8), (2, 2, 8), (4, 1, 8), (4, 2, 8),
    ],
    structures: [(3, 1, "layer_adapter")],
)]==], 7)

local p = t.join()
t.tick()

assert(t.structure_at(3, 1).id == "layer_adapter", "the map stood one there")
assert(t.pipe(2, 1) == L2 + L4, "the tile west of it carries both layers")
assert(t.pipe(2, 2) == L4, "and the tile below carries only layer 4")

-- ---- and it LOOKS like what it is joined to ----
--
-- tg draws an adapter as a bare centre band with one half-tile of pipe
-- per end per layer it actually found (`get_attached_image`,
-- layermanifold.dm:59-82). This one bridges two layers, so it shows
-- four arms: layer 2 and layer 4, west and east. Not ten, and not the
-- picture of ten -- `manifoldlayer`, the all-connections drawing, is
-- what a fitting in your HANDS wears and the one thing a bolted
-- adapter must never be mistaken for.
local drawn = t.layers(p, t.target_at(3, 1, "layer_adapter"))
local expect = {
    "pipe_half_l2_8",
    "pipe_half_l2_4",
    "pipe_half_l4_8",
    "pipe_half_l4_4",
    "layer_adapter_ew",
}
assert(#drawn == #expect, "four arms and a centre band, and nothing else: " .. #drawn)
for i, name in ipairs(expect) do
    assert(
        drawn[i] == name,
        "layer " .. i .. " is " .. tostring(drawn[i]) .. ", wanted " .. name
    )
end

-- Nine lengths and four mouths -- two layers x two ends of the machine,
-- at a twentieth of a cubic metre apiece. Layers 1, 3 and 5 have no run
-- to reach, so those six mouths bind to nothing and pay in nothing.
local FUSED_M3 = 9 * PIPE_M3 + 4 * MANIFOLD_PORT_M3

local start_kpa = t.pipe_pressure(1, 1, L2)
assert(start_kpa > 90.0, "the runs open the shift charged: " .. start_kpa)

-- Every one of the four tiles reports the SAME gas, and it is the whole
-- fused volume's worth. Four runs of three different lengths cannot do
-- that; one net has to.
local fused = net_moles(1, 1, L2)
near(fused, moles(start_kpa, FUSED_M3), 0.05, "the adapter's net is all nine lengths")
near(net_moles(6, 1, L2), fused, 0.001, "the long layer 2 run reads the same gas")
near(net_moles(2, 2, L4), fused, 0.001, "and so does layer 4 west, on another layer")
near(net_moles(4, 2, L4), fused, 0.001, "and layer 4 east")

local books = fused + moles(t.room_pressure(3, 2), ROOM_M3)

-- ---- take the adapter out, and the layers part ----
t.click(p, 6, 2, t.target_at(6, 2, "wrench"))
t.run_ticks(2)
assert(t.hands(p).held == "wrench", "wrench in hand")
for _ = 1, 3 do
    walk(p, "west")
end
t.click(p, 3, 1, t.target_at(3, 1, "layer_adapter"))
t.run_seconds(2.5)
assert(t.structure_at(3, 1) == nil, "the adapter comes up off the deck")
assert(
    t.count_items("layer_adapter_fitting") == 1,
    "and hands its fitting back, wherever the vented mouths blew it"
)

-- Four nets now, and they say so: each holds its own run's worth and no
-- two of the different-length ones agree.
local west2 = net_moles(1, 1, L2)
local east2 = net_moles(6, 1, L2)
local west4 = net_moles(2, 2, L4)
local east4 = net_moles(4, 2, L4)
near(west2, moles(start_kpa, 2 * PIPE_M3), 0.05, "layer 2 west is two lengths again")
near(east2, moles(start_kpa, 3 * PIPE_M3), 0.05, "layer 2 east is three")
near(west4, moles(start_kpa, 2 * PIPE_M3), 0.05, "and the layer 4 runs are two apiece")
near(east4, moles(start_kpa, 2 * PIPE_M3), 0.05, "both of them")
assert(east2 > west2 + 0.5, "the long run holds more than the short one, as it must")

-- Conservation across the split: the nine lengths kept their gas and
-- the four mouths hissed into the room on the way out, which is what
-- unbolting a machine out of a charged line costs.
local parted = west2 + east2 + west4 + east4 + moles(t.room_pressure(3, 2), ROOM_M3)
assert(
    math.abs(parted - books) < books * 0.02,
    "and the books balance across the split: " .. books .. " mol -> " .. parted .. " mol"
)

-- ---------------------------------------------------------------
-- A COLOUR ADAPTER JOINS TWO PAINT JOBS.
--
-- Paint is plumbing here: `pipes/paint.rs` refuses to flood two ends
-- whose colours disagree, so a red main and a blue main lying end to
-- end on the same layer are two networks. tg's colour adapter carries
-- `PIPING_ALL_COLORS` (color_adapter.dm:10) and joins them anyway,
-- without either run losing its own livery.
--
-- Same instrument, same two questions.
-- ---------------------------------------------------------------
t.world([==[(
    name: "color adapter",
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
    items: [(6, 2, "wrench"), (6, 2, "pipe_painter")],
    // Two lengths of red, three of blue, meeting at the adapter.
    pipes: [(1, 1, 4), (2, 1, 4), (4, 1, 4), (5, 1, 4), (6, 1, 4)],
    pipe_paint: [
        (1, 1, 4, "#FF0000"), (2, 1, 4, "#FF0000"),
        (4, 1, 4, "#0000FF"), (5, 1, 4, "#0000FF"), (6, 1, 4, "#0000FF"),
    ],
    structures: [(3, 1, "color_adapter")],
)]==], 7)

local c = t.join()
t.tick()

assert(t.structure_at(3, 1).id == "color_adapter", "a colour adapter between them")

local ADAPTER_M3 = 5 * PIPE_M3 + 2 * ADAPTER_PORT_M3
local paint_kpa = t.pipe_pressure(1, 1)
assert(paint_kpa > 90.0, "both runs are charged: " .. paint_kpa)

local joined = net_moles(1, 1, DISTRO)
near(joined, moles(paint_kpa, ADAPTER_M3), 0.05, "red and blue are one body of gas")
near(net_moles(6, 1, DISTRO), joined, 0.001, "the far end of the blue run reads the same")

local paint_books = joined + moles(t.room_pressure(3, 2), ROOM_M3)

-- ---- painting it is refused, and says so ----
--
-- tg's `paintable = FALSE` (color_adapter.dm:16). A thing whose whole
-- job is to join every colour has no colour to be, and a painter that
-- silently changed nothing would be the worst of both.
t.click(c, 6, 2, t.target_at(6, 2, "pipe_painter"))
t.run_ticks(2)
assert(t.hands(c).held == "pipe_painter", "painter in hand")
for _ = 1, 3 do
    walk(c, "west")
end
local _ = t.messages(c)
t.click(c, 3, 1)
t.run_ticks(4)
assert(
    said(c, "The color adapter takes no paint."),
    "the refusal names the thing that refused"
)
assert(
    not t.ledger_has("PipePainted"),
    "and nothing was painted, so there is nothing on the record"
)
near(net_moles(1, 1, DISTRO), joined, 0.001, "and the net is exactly as it was")

-- ---- take it out, and the colours part ----
t.drop(c)
t.run_ticks(2)
for _ = 1, 3 do
    walk(c, "east")
end
t.click(c, 6, 2, t.target_at(6, 2, "wrench"))
t.run_ticks(2)
assert(t.hands(c).held == "wrench", "wrench in hand")
for _ = 1, 3 do
    walk(c, "west")
end

t.click(c, 3, 1, t.target_at(3, 1, "color_adapter"))
t.run_seconds(2.5)
assert(t.structure_at(3, 1) == nil, "the adapter comes up")
assert(t.count_items("color_adapter_fitting") == 1, "and hands its fitting back")

local red = net_moles(1, 1, DISTRO)
local blue = net_moles(6, 1, DISTRO)
near(red, moles(paint_kpa, 2 * PIPE_M3), 0.05, "two lengths of red, on their own")
near(blue, moles(paint_kpa, 3 * PIPE_M3), 0.05, "three of blue, on theirs")
assert(blue > red + 0.5, "and they are no longer the same body of gas")
assert(t.pipe(2, 1) == DISTRO, "both runs are still where they always were")
assert(t.pipe(4, 1) == DISTRO)

local paint_parted = red + blue + moles(t.room_pressure(3, 2), ROOM_M3)
assert(
    math.abs(paint_parted - paint_books) < paint_books * 0.02,
    "and the books balance: " .. paint_books .. " mol -> " .. paint_parted .. " mol"
)
