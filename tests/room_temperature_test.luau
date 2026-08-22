-- How hot the air in a ROOM is, and what happens to that when somebody
-- lets a hot pipe into it.
--
-- WHAT IS READABLE HERE, because it shapes every assertion below. A run
-- of pipe hands out three numbers, and `t.pipe_energy` is the conserved
-- one -- which is why the thermal machines can be weighed directly
-- (thermal_devices_test.luau). A ROOM hands out `t.room_pressure` and
-- `t.room_gas`, and NEITHER is temperature. The one thermometer a
-- crewman can put on the air is the gas analyzer, which prints the
-- temperature in both scales rounded to a hundredth (tg's `atmos_scan`,
-- gas_analyzer.dm:185-230). That line, parsed, is the instrument this
-- file is built on, and 0.01 K is the finest claim it can make.
--
-- Room ENERGY is not exposed at all, so the books here are
-- reconstructed rather than read: the molar heat capacity comes off the
-- RUN's own three numbers (E / nT), the run and the room are SHOWN to
-- be the same 21/79 mixture so one capacity serves both, and the room's
-- joules follow from its moles and its thermometer. That reconstruction
-- is only as honest as the composition check, which is why the check is
-- made explicitly and not assumed.
--
-- The gradient itself is scaffolding: `t.foul_room` deposits at T20C by
-- construction and `t.heat_pipe` is the only heat source a spec has
-- until a burn chamber exists. Both are preconditions, never assertions.

local T20C = 293.15
local R_GAS = 8.314
local TILE_L = 1000.0

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function total(x, y)
    local sum = 0.0
    for _, moles in pairs(t.room_gas(x, y) or {}) do
        sum = sum + moles
    end
    return sum
end

local function pipe_total(x, y)
    local sum = 0.0
    for _, moles in pairs(t.pipe_gas(x, y) or {}) do
        sum = sum + moles
    end
    return sum
end

local function room_moles(tiles)
    local sum = 0.0
    for _, tile in ipairs(tiles) do
        sum = sum + total(tile[1], tile[2])
    end
    return sum
end

-- The thermometer. Point the analyzer at the deck under your own boots
-- and read the temperature line off what it said. A tile of plating
-- with no run buried in it is the AIR (analyzer.luau dispatches to the
-- pipe first where there is one), which is what makes this a room
-- reading rather than a pipe reading.
local function analyzed(p, x, y)
    local _ = t.messages(p)
    t.click(p, x, y)
    t.run_ticks(2)
    local air, temp_k = false, nil
    for _, line in ipairs(t.messages(p)) do
        local kelvin = string.match(line, "^Temperature: .+ %(([%d%.%-]+) K%)$")
        if kelvin then
            temp_k = tonumber(kelvin)
        end
        air = air or line == "Results of analysis of the air."
    end
    assert(air, "the analyzer read the AIR over " .. x .. "," .. y .. ", not a pipe")
    assert(temp_k ~= nil, "and printed a temperature for it")
    return temp_k
end

-- ---------------------------------------------------------------
-- A SEALED ROOM HOLDS ITS TEMPERATURE, AND FOULING IT DOES NOT HEAT IT.
--
-- The negative first, and it is doing two jobs. One: nothing in this
-- engine warms or cools a room on its own -- there is no wall to
-- conduct into (a wall is the ABSENCE of a cell, docs/MATTER.md §7),
-- no boundary cell to drain to on a fully walled map, and no reaction
-- with anything to react. Six tiles of standard air left alone for two
-- minutes read the same number, to the hundredth, that they opened at.
--
-- Two: it pins what `t.foul_room` is. Ten moles of carbon dioxide
-- arrive AT ROOM TEMPERATURE -- the scaffolding adds substance, never a
-- gradient -- so the pressure climbs and the thermometer does not move.
-- Anything later in this file that wants hot gas has to get it from a
-- pipe, and this is why.
-- ---------------------------------------------------------------
t.world([==[(
    name: "sealed room",
    legend: {
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#####",
    ],
    spawns: [(2, 2)],
    items: [(2, 2, "analyzer")],
)]==], 7)

local p = t.join()
t.tick()
t.click(p, 2, 2, t.target_at(2, 2, "analyzer"))
t.run_ticks(2)
assert(t.hands(p).held == "analyzer", "analyzer in hand")

local SEALED = {}
for x = 1, 3 do
    for y = 1, 2 do
        SEALED[#SEALED + 1] = { x, y }
    end
end

local opening = analyzed(p, 2, 2)
near(opening, T20C, 0.005, "a station opens at room temperature")
local held_0 = room_moles(SEALED)
local kpa_0 = t.room_pressure(2, 2)

t.run_seconds(120)
local later = analyzed(p, 2, 2)
assert(later == opening, "and two minutes of nothing changes nothing: " .. later)
assert(room_moles(SEALED) == held_0, "not a mole moved out of the room either")

t.foul_room(2, 2, "co2", 10.0)
t.run_seconds(20)
local fouled = analyzed(p, 2, 2)
near(room_moles(SEALED), held_0 + 10.0, 1e-6, "ten moles of carbon dioxide went in")
assert(
    t.room_pressure(2, 2) > kpa_0 + 3.0,
    "the room is over-pressured for it: " .. kpa_0 .. " -> " .. t.room_pressure(2, 2)
)
assert(
    fouled == opening,
    "AND IT IS NO WARMER: fouling deposits at room temperature, so the "
        .. "scaffolding cannot be mistaken for a heater ("
        .. opening .. " -> " .. fouled .. ")"
)

-- ---------------------------------------------------------------
-- HOT GAS ENTERING A COOLER ROOM BLENDS BY ENERGY.
--
-- A four-tile room with an air injector standing in the corner of it,
-- and the run behind that injector buried under six tiles of hull where
-- no room can reach it. The injector is the machine for this because it
-- has no setpoint and no ceiling (air_injector.luau): switched on it
-- empties its own run into the room it faces, so the whole charge --
-- every mole and every joule of it -- ends up on the crew's side of the
-- nozzle and there is nothing left behind to argue about.
--
-- The claim is what the thermometer reads afterwards. Not the hot gas's
-- temperature: the room did not become the pipe. Not the average of the
-- two temperatures either, which is the answer that FEELS right and is
-- wrong by a hundred and fifty kelvin here, because there are six times
-- more moles of cool air than hot. What comes out is the blend the
-- joules say: total energy over total moles over the heat capacity, and
-- the engine gets it right to the hundredth of a kelvin the analyzer
-- can print.
-- ---------------------------------------------------------------
t.world([==[(
    name: "hot injection",
    legend: {
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "##########",
        "#..#######",
        "#..#######",
        "##########",
    ],
    spawns: [(1, 2)],
    items: [(1, 2, "analyzer")],
    pipes: [(3, 1, 4), (4, 1, 4), (5, 1, 4), (6, 1, 4), (7, 1, 4), (8, 1, 4)],
    structures: [(2, 1, "air_injector")],
)]==], 7)

local q = t.join()
t.tick()
local ROOM = { { 1, 1 }, { 2, 1 }, { 1, 2 }, { 2, 2 } }

assert(t.structure_at(2, 1).id == "air_injector", "an injector in the corner")
assert(t.structure_at(2, 1).state == "off", "off out of the crate")
assert(t.turf(4, 1) == "wall", "its run is buried under the hull")
assert(t.room_pressure(4, 1) == nil, "where there is no room for it to be part of")

-- ---- the one heat capacity, taken off the run's own three numbers ----
--
-- E / nT is joules per mole per kelvin, and it is only allowed to speak
-- for the ROOM as well if the two bodies of gas are the same admixture.
-- They are, and it is checked rather than assumed: both are tg's
-- standard 21/79, so one molar capacity serves the whole book.
local n_pipe_0 = pipe_total(5, 1)
local cv = t.pipe_energy(5, 1) / (n_pipe_0 * t.pipe_temperature(5, 1))
assert(cv > 1.0, "the run's molar heat capacity is readable: " .. cv)
near(t.pipe_temperature(5, 1), T20C, 0.01, "and it opens at room temperature")

local n_room_0 = room_moles(ROOM)
local function o2_share(gas, n)
    return gas.o2 / n
end
near(
    o2_share(t.pipe_gas(5, 1), n_pipe_0),
    o2_share(t.room_gas(1, 2), total(1, 2)),
    1e-9,
    "the run and the room are the SAME admixture, so one capacity serves both"
)

-- ---- the gradient ----
t.heat_pipe(5, 1, 300000.0)
t.tick()
local hot_k = t.pipe_temperature(5, 1)
local energy_0 = t.pipe_energy(5, 1) + n_room_0 * cv * T20C
assert(hot_k > 800.0, "the run is glowing: " .. hot_k)
near(pipe_total(5, 1), n_pipe_0, 1e-9, "and heating it moved no moles at all")
assert(
    n_room_0 > n_pipe_0 * 5.0,
    "the room outweighs the run six to one: " .. n_room_0 .. " vs " .. n_pipe_0
)

-- ---- open the nozzle ----
--
-- The analyzer moves to the off hand: an item in the working hand is
-- the item, not an interface, so the panel is opened bare-handed and
-- the instrument is picked back up afterwards.
t.click(q, 1, 2, t.target_at(1, 2, "analyzer"))
t.run_ticks(2)
t.swap_hands(q)
t.click(q, 2, 1, t.target_at(2, 1, "air_injector"))
t.tick()
assert(t.ui(q).setpoints[1].field == "rate", "the injector's dial is a volume rate")
t.ui_act(q, "set", '{"field":"rate","value":200}')
t.ui_act(q, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.structure_at(2, 1).state == "injecting", "and it is running")

t.run_seconds(30)
assert(
    pipe_total(5, 1) < n_pipe_0 * 1e-6,
    "the run is spent -- an injector has no notion of enough: " .. pipe_total(5, 1)
)
near(room_moles(ROOM), n_room_0 + n_pipe_0, 1e-6, "every mole of it is in the room")

-- ---- what the thermometer says ----
t.swap_hands(q)
local px, py = t.pos(q)
local blended = analyzed(q, px, py)
local n_room_1 = room_moles(ROOM)
local predicted = energy_0 / (n_room_1 * cv)

near(
    blended,
    predicted,
    0.05,
    "THE BLEND IS THE ENERGY BOOK: total joules over total moles over "
        .. "the heat capacity, and no joule was minted on the way in"
)
assert(blended > T20C + 50.0, "the room did get hot: " .. T20C .. " -> " .. blended)
assert(
    blended < hot_k - 400.0,
    "but nothing like as hot as what arrived -- it is not the pipe's "
        .. "temperature: " .. hot_k .. " vs " .. blended
)
assert(
    math.abs(blended - (T20C + hot_k) / 2.0) > 150.0,
    "and it is NOT the average of the two temperatures, which is the "
        .. "wrong answer by a wide margin here: " .. (T20C + hot_k) / 2.0
        .. " vs " .. blended
)

-- The last cross-check, between the two readouts a room actually has:
-- the gauge is the ideal gas law applied to the moles and the
-- temperature the analyzer just printed. A blend that warmed the air
-- without the pressure following would be a thermometer disagreeing
-- with the station it is standing in.
near(
    t.room_pressure(px, py),
    total(px, py) * R_GAS * blended / TILE_L,
    0.05,
    "and the gauge on the wall agrees with the thermometer in your hand"
)
