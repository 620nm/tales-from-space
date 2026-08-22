-- The machines a MAP lays already set up.
--
-- tg's atmospherics roster is mostly presets: eighteen filter subtypes
-- and an air mixer, each the base machine with two or three lines of
-- its atmos block different (filter.dm:224-241, mixer.dm's `/airmix`).
-- They exist because a department's plumbing is not something anybody
-- tunes at roundstart -- a waste loop is a CHAIN of filters, and a
-- station whose air mixer had to be dialled in by hand before anyone
-- could breathe would be a station shipping mis-configured.
--
-- Two of them have never been exercised: the air mixer and the carbon
-- dioxide filter. Both are map-only (no `build` rule -- the fitting in
-- your hands only ever knows how to become the plain machine), so a
-- spec has to put them down the way a mapper does and then leave them
-- alone. Nobody in this file touches a switch: every panel is opened
-- to READ it, and the machines are already working by the time anyone
-- looks.
--
-- Which needs pure gas, and there is exactly one way to author it: a
-- sealed chamber holding one gas as room air, with a passive vent
-- opening it onto the run. That is tg's own gas storage -- chambers,
-- not bottles -- and it is what chillstation.ron does either side of
-- its own air mixer. The pipe under the chamber wall is the whole
-- trick: a run is subfloor and does not care what turf stands over it.

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

-- Moles of one gas standing in the run under a tile, or 0.
local function gas(x, y, which)
    local held = t.pipe_gas(x, y)
    return (held and held[which]) or 0.0
end

local function moles(x, y)
    local held = t.pipe_gas(x, y)
    if not held then
        return 0.0
    end
    local n = 0.0
    for _, amount in pairs(held) do
        n = n + amount
    end
    return n
end

-- ---------------------------------------------------------------
-- THE AIR MIXER MAKES THE AIR.
--
-- A nitrogen chamber on the back intake, an oxygen chamber on the
-- side, and a machine that ships ON at 79/21 with its dial wound to
-- MAX_OUTPUT_PRESSURE. What comes out of the front is what a station
-- breathes, and nobody opened a window to make it happen.
--
-- The two chambers are one tile each, sealed on all four sides, with
-- the run leaving under the wall. The mixer's only complete facing is
-- east -- back to the nitrogen line, side dropping south to the
-- oxygen one, outlet east -- so the engine aims it there.
-- ---------------------------------------------------------------
t.world([==[(
    name: "air mixer",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "##########",
        "#.#......#",
        "###..a..g#",
        "##########",
        "#####.####",
        "##########",
    ],
    spawns: [(5, 2)],
    // Fifty atmospheres of one gas apiece, which is what a tg gas
    // storage chamber holds.
    room_gas: [(1, 1, "n2", 5000.0), (5, 4, "o2", 5000.0)],
    pipes: [
        (2, 1, 4), (3, 1, 4), (4, 1, 4),
        (6, 1, 4), (7, 1, 4), (8, 1, 4),
        (5, 2, 4), (5, 3, 4),
    ],
    structures: [
        (1, 1, "passive_vent"),
        (5, 4, "passive_vent"),
        (5, 1, "gas_mixer_airmix"),
    ],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3), (7, 1, 3), (8, 1, 3),
        (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3), (7, 2, 3), (8, 2, 3),
        (5, 3, 3),
        (5, 4, 3),
    ],
)]==], 7)

local p = t.join()
t.tick()
-- The outlet main before the machine has had a pass at it, kept for the
-- end: what a running air mixer does is only visible against where it
-- started.
local early = t.pipe_pressure(7, 1)

local m = t.structure_at(5, 1)
assert(m ~= nil and m.id == "gas_mixer_airmix", "the air mixer is where the map put it")
assert(m.state == "running", "and unlike a plain mixer it opens the shift RUNNING")

-- The chambers are what the map said, which is what makes the mix
-- assertion below mean anything at all.
local n2_store = t.room_gas(1, 1)
local o2_store = t.room_gas(5, 4)
assert(n2_store.n2 > 1000.0, "the nitrogen chamber is charged: " .. n2_store.n2)
assert(n2_store.o2 == nil, "with nitrogen and nothing else")
assert(o2_store.o2 > 1000.0, "and the oxygen chamber likewise: " .. o2_store.o2)
assert(o2_store.n2 == nil, "oxygen and nothing else")

-- One pass of the passive vents floods each intake with its chamber's
-- gas; the air that was standing in the run is a rounding error beside
-- fifty atmospheres of one substance.
t.run_seconds(2)
local back_pure = gas(3, 1, "n2") / moles(3, 1)
local side_pure = gas(5, 2, "o2") / moles(5, 2)
assert(back_pure > 0.97, "the back intake carries nitrogen: " .. back_pure)
assert(side_pure > 0.97, "and the side intake oxygen: " .. side_pure)

-- ---- the panel, read and not touched ----
t.click(p, 5, 1, t.target_at(5, 1, "gas_mixer_airmix"))
t.tick()
local ui = t.ui(p)
assert(ui and ui.kind == "gas_mixer", "an air mixer is a gas mixer's window")
assert(ui.toggles[1].field == "power" and ui.toggles[1].on == true, "shipped switched on")
near(ui.setpoints[1].value, 4500.0, 0.001, "its dial wound to MAX_OUTPUT_PRESSURE")
near(ui.setpoints[2].value, 79.0, 0.001, "and the split at tg's N2STANDARD")
local mix = nil
for _, r in ipairs(ui.readouts) do
    if r.label == "mix" then
        mix = r.value
    end
end
assert(mix == "79% back / 21% side", "which the panel says in both halves: " .. tostring(mix))
t.ui_close(p)

-- ---- and what it made ----
near(early, 101.325, 0.001, "the outlet main opened the shift at one atmosphere")
t.run_seconds(8)

near(
    t.pipe_pressure(7, 1),
    4500.0,
    1.0,
    "and the mixer filled it to the setpoint with nobody touching it"
)
assert(t.pipe_pressure(7, 1) <= 4500.0, "and not one kPa past it: " .. t.pipe_pressure(7, 1))

local out_n2, out_o2, out_all = gas(7, 1, "n2"), gas(7, 1, "o2"), moles(7, 1)
near(out_n2 / out_all, 0.79, 0.02, "and what stands in it is 79% nitrogen")
near(out_o2 / out_all, 0.21, 0.02, "and 21% oxygen -- which is air")
near(out_n2 + out_o2, out_all, 1e-9, "with nothing else in it at all")

-- ---------------------------------------------------------------
-- THE CARBON DIOXIDE FILTER SEPARATES WITHOUT BEING ASKED.
--
-- gas_filter_test.luau proves the nitrogen preset ships configured and
-- running. This is the other one, on the job a waste loop actually
-- has: a line carrying a MIXTURE, and one gas to be taken out of it.
--
-- The mixture is authored the same way -- a carbon dioxide chamber at
-- three atmospheres opening onto the input main, which was already
-- holding standard air -- so what reaches the machine is a genuine
-- three-gas line and "the co2 went to the side port" cannot be read
-- off a pressure.
-- ---------------------------------------------------------------
t.world([==[(
    name: "co2 filter",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "#########",
        "#.#.....#",
        "###.a..g#",
        "#########",
    ],
    spawns: [(4, 2)],
    room_gas: [(1, 1, "co2", 100.0)],
    pipes: [(2, 1, 4), (3, 1, 4), (5, 1, 4), (6, 1, 4), (4, 2, 4)],
    structures: [(1, 1, "passive_vent"), (4, 1, "gas_filter_co2")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3), (7, 1, 3),
        (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3), (7, 2, 3),
    ],
)]==], 7)

local q = t.join()
t.tick()

local f = t.structure_at(4, 1)
assert(f ~= nil and f.id == "gas_filter_co2", "the preset filter is on the line")
assert(f.state == "running", "and it opens the shift running")

-- The two output nets as the map handed them over: ordinary air, and
-- not a mole of carbon dioxide in either.
local side_o2, side_n2 = gas(4, 2, "o2"), gas(4, 2, "n2")
local main_o2, main_n2 = gas(5, 1, "o2"), gas(5, 1, "n2")
assert(gas(4, 2, "co2") == 0.0, "the side port starts with none of the gas it collects")
assert(gas(5, 1, "co2") == 0.0, "and neither does the pass-through")

-- The input main is a MIXTURE, not a co2 line: the chamber charges it
-- over the standard air already standing there, so all three gases
-- reach the machine and "the co2 went to the side port" is a question
-- only the books can answer.
t.run_seconds(2)
local in_co2, in_o2, in_n2 = gas(3, 1, "co2"), gas(3, 1, "o2"), gas(3, 1, "n2")
assert(in_co2 > 1.0, "the chamber charged the input with carbon dioxide: " .. in_co2)
assert(in_o2 > 0.5 and in_n2 > 1.0, "over the air already in it: " .. in_o2 .. " / " .. in_n2)

-- Both output nets are sealed runs, so the whole ledger is the input
-- net, the two outputs, and the chamber that feeds them.
local function books(which)
    return gas(3, 1, which)
        + gas(4, 2, which)
        + gas(5, 1, which)
        + ((t.room_gas(1, 1) or {})[which] or 0.0)
end
local books_co2, books_o2, books_n2 = books("co2"), books("o2"), books("n2")

-- ---- the panel, read and not touched ----
t.click(q, 4, 1, t.target_at(4, 1, "gas_filter_co2"))
t.tick()
local panel = t.ui(q)
assert(panel and panel.kind == "gas_filter", "the filter's own window")
assert(panel.toggles[1].field == "power" and panel.toggles[1].on == true, "shipped switched on")
near(panel.setpoints[1].value, 200.0, 0.001, "at tg's MAX_TRANSFER_RATE")
local roster = 0
for _, sw in ipairs(panel.toggles) do
    if sw.field == "filter" then
        roster = roster + 1
        assert(
            sw.on == (sw.option == "co2"),
            "the preset selected carbon dioxide and only that, not " .. tostring(sw.option)
        )
    end
end
assert(roster > 1, "the whole registry is still on offer: " .. roster .. " gases")
t.ui_close(q)

-- ---- and what it did ----
t.run_seconds(12)

assert(
    gas(4, 2, "co2") > 1.0,
    "the side port collected the carbon dioxide: " .. gas(4, 2, "co2")
)
assert(
    gas(5, 1, "o2") > main_o2 + 0.5 and gas(5, 1, "n2") > main_n2 + 1.0,
    "and the breathable half carried straight on"
)

-- The two numbers a wrong preset would move, and they are exact: this
-- machine can put NO carbon dioxide out of the front, and nothing at
-- all but carbon dioxide out of the side.
near(gas(5, 1, "co2"), 0.0, 1e-9, "not one mole of co2 reached the pass-through")
near(gas(4, 2, "o2"), side_o2, 1e-9, "no oxygen was ever diverted")
near(gas(4, 2, "n2"), side_n2, 1e-9, "and no nitrogen either")

near(books("co2"), books_co2, 1e-6, "every mole of carbon dioxide is still somewhere")
near(books("o2"), books_o2, 1e-6, "and every mole of oxygen")
near(books("n2"), books_n2, 1e-6, "and every mole of nitrogen")
