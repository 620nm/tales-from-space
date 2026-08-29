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
-- A room's book has a THIRD column, and it is the big one: the deck.
-- `t.deck(x, y)` reads the solid mass a tile stands on -- its floor plus
-- its share of the walls beside it -- which outweighs the air over it by
-- two orders of magnitude and therefore decides where a warmed room
-- settles (docs/MATTER-WORLD.md §3). Air alone has not been the whole of a
-- room since that landed, and a spec that counted only the air would
-- read a warm floor as a leak.
--
-- The gradient itself is scaffolding: `t.foul_room` deposits at T20C by
-- construction and `t.heat_pipe` is the only heat source a spec has
-- until a burn chamber exists. Both are preconditions, never assertions.
--
-- AND THERE IS A FOURTH COLUMN, outside the room entirely: the sky. A
-- deck is a slab with a face over it and a face under it, and both look
-- at space, so every tile of every room radiates whether or not anybody
-- opened a door (docs/MATTER-WORLD.md §3 step 5d). Where the station is
-- parked -- how cold the sink is and whether a star is shining on it --
-- is rolled once per shift off the game mode (docs/GAMEMODES.md), which
-- is why the blocks below that want a room to sit still say so with
-- `t.set_environment`: a sink at the station's own temperature radiates
-- back exactly what the hull emits, so the sky goes quiet by PHYSICS
-- rather than by a bypass flag. The two blocks at the end take the flag
-- off and weigh what the sky does.

local T20C = 293.15
local R_GAS = 8.314
local TILE_L = 1000.0
-- Stefan-Boltzmann, W/(m^2 K^4). Not a tg number: tg has no radiation.
local SIGMA = 5.670374419e-8

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

-- The deck under a set of tiles: what it holds, and what it would take
-- to warm it a kelvin. Every deck is finite and readable, plating
-- included -- it is the hull plate, massed as the slab it is
-- (docs/MATTER-WORLD.md §5) -- but the maps in this file are laid in floor
-- so that one deck capacity serves every tile in the arithmetic.
local function deck_energy(tiles)
    local sum = 0.0
    for _, tile in ipairs(tiles) do
        local deck = t.deck(tile[1], tile[2])
        assert(deck, "every floor tile stands on something: " .. tile[1] .. "," .. tile[2])
        sum = sum + deck.energy
    end
    return sum
end

local function deck_capacity(tiles)
    local sum = 0.0
    for _, tile in ipairs(tiles) do
        sum = sum + t.deck(tile[1], tile[2]).capacity
    end
    return sum
end

-- The thermometer. Point the analyzer at the deck under your own boots
-- and read the temperature line off what it said. A tile of floor
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
-- The negative first, and it is doing two jobs. One: nothing INSIDE
-- this engine warms or cools a room on its own. The deck under it is
-- real and it is heavy, but it opens at the same room temperature the
-- air does, and conduction with no gradient is nothing; there is no
-- boundary cell to drain to on a fully walled map, and nothing to react
-- with. The one thing outside is the sky, and it is silenced the only
-- honest way there is: `t.set_environment` parks this station under a
-- sink at its own temperature, so the hull absorbs exactly what it
-- radiates and the net is zero by Stefan-Boltzmann rather than by a
-- switch. Six tiles of standard air left alone for two minutes then
-- read the same number, to the hundredth, that they opened at -- and so
-- does their deck.
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
        '.': (turf: Floor),
        '#': (turf: Wall),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "#####",
        "#...#",
        "#.ag#",
        "#####",
    ],
    spawns: [(2, 2)],
    items: [(2, 2, "analyzer")],
    cables: [
        (1, 1, 1, 2, 4), (1, 1, 2, 2, 4), (2, 1, 1, 0, 2), (2, 1, 1, 0, 4),
        (2, 1, 1, 0, 8), (2, 1, 2, 0, 2), (2, 1, 2, 0, 4), (2, 1, 2, 0, 8),
        (3, 1, 1, 2, 8), (3, 1, 2, 2, 8),
        (1, 2, 1, 1, 4), (1, 2, 2, 1, 4), (2, 2, 1, 0, 1), (2, 2, 1, 0, 4),
        (2, 2, 1, 0, 8), (2, 2, 2, 0, 1), (2, 2, 2, 0, 4), (2, 2, 2, 0, 8),
        (3, 2, 1, 0, 1), (3, 2, 1, 0, 8), (3, 2, 2, 0, 1), (3, 2, 2, 0, 8),
    ],
)]==], 7)

t.set_environment({ sink_k = T20C, insolation = 0 })

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
local deck_0 = deck_energy(SEALED)
near(t.deck(2, 2).temperature, T20C, 1e-9, "the deck opens at room temperature too")

t.run_seconds(120)
local later = analyzed(p, 2, 2)
assert(later == opening, "and two minutes of nothing changes nothing: " .. later)
assert(room_moles(SEALED) == held_0, "not a mole moved out of the room either")
assert(deck_energy(SEALED) == deck_0, "and not a joule moved into the deck")

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
-- two temperatures either, which is the answer that FEELS right. Not
-- even the blend of the two bodies of GAS, which is the answer that was
-- right before the deck existed and is now wrong by seventy kelvin.
-- What comes out is the blend the whole book says -- air plus deck --
-- and the deck is a hundred and seventy times the air, so a glowing
-- run emptied into a small room moves the thermometer by less than a
-- degree. That is the shape of a station: a lot of steel and not much
-- air, and it is the steel that decides.
-- ---------------------------------------------------------------
t.world([==[(
    name: "hot injection",
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "##########",
        "#..#######",
        "#ag#######",
        "##########",
    ],
    spawns: [(1, 2)],
    items: [(1, 2, "analyzer")],
    pipes: [(3, 1, 4), (4, 1, 4), (5, 1, 4), (6, 1, 4), (7, 1, 4), (8, 1, 4)],
    structures: [(2, 1, "air_injector")],
    cables: [
        (1, 1, 1, 2, 4), (1, 1, 2, 2, 4), (2, 1, 1, 0, 2), (2, 1, 1, 0, 8),
        (2, 1, 2, 0, 2), (2, 1, 2, 0, 8),
        (1, 2, 1, 0, 1), (1, 2, 1, 0, 4), (1, 2, 2, 0, 1), (1, 2, 2, 0, 4),
        (2, 2, 1, 0, 1), (2, 2, 1, 0, 8), (2, 2, 2, 0, 1), (2, 2, 2, 0, 8),
    ],
)]==], 7)

-- Inert sky again, and for the same reason: this block weighs an energy
-- book to four hundred joules over three and a half minutes, and a hull
-- radiating into real space would take a hundred times that out of it.
-- What the sky does is weighed at the end of the file, on its own.
t.set_environment({ sink_k = T20C, insolation = 0 })

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

-- ---- the third column ----
local c_air_0 = n_room_0 * cv
local c_deck = deck_capacity(ROOM)
local deck_e0 = deck_energy(ROOM)
assert(
    c_deck > c_air_0 * 100.0,
    "the deck outweighs the air it holds up by two orders of magnitude: "
        .. c_deck .. " vs " .. c_air_0
)

-- ---- the gradient ----
t.heat_pipe(5, 1, 300000.0)
t.tick()
local hot_k = t.pipe_temperature(5, 1)
local pipe_e0 = t.pipe_energy(5, 1)
local energy_0 = pipe_e0 + n_room_0 * cv * T20C + deck_e0
-- The book's fourth column: what leaves through the hull. The sky here
-- is at the station's OPENING temperature, so it is inert until the
-- injector warms the room past it -- and from that moment a warmed deck
-- radiates, a few kilojoules of it over the minutes below. That is
-- physics rather than a leak, and `t.space_radiated` is where it is
-- booked, so the book closes on four columns instead of three.
local radiated_0 = t.space_radiated()
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

-- And then let it stand. Conduction into the deck stops at half a
-- kelvin of disagreement (tg's MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER,
-- atmos_core.dm:110), so "settled" here means air and deck within that
-- of each other, which takes a couple of minutes at floor conductivity.
t.run_seconds(180)

-- ---- what the thermometer says ----
t.swap_hands(q)
local px, py = t.pos(q)
local blended = analyzed(q, px, py)
local n_room_1 = room_moles(ROOM)
local air_1 = n_room_1 * cv * blended
local deck_1 = deck_energy(ROOM)

assert(
    t.pipe_energy(5, 1) < pipe_e0 * 1e-6,
    "the run kept nothing back: " .. t.pipe_energy(5, 1)
)
local radiated_1 = t.space_radiated() - radiated_0
assert(radiated_1 > 0.0, "the warmed hull did radiate: " .. radiated_1)
near(
    air_1 + deck_1 + radiated_1,
    energy_0,
    400.0,
    "THE BLEND IS THE ENERGY BOOK, and the book has four columns: what "
        .. "the run gave up is in the air, the deck and the sky between "
        .. "them, and no joule was minted on the way in"
)
near(
    blended,
    energy_0 / (n_room_1 * cv + c_deck),
    0.6,
    "and the thermometer reads the whole book, not the air's half of it"
)
-- Where it went. The air's share is what it took to WARM the air --
-- not the joules the injected moles walked in with, which were never
-- the room's to gain.
assert(
    deck_1 - deck_e0 > n_room_1 * cv * (blended - T20C) * 50.0,
    "the deck took nearly all of it: " .. (deck_1 - deck_e0) .. " J into the steel"
)

-- What the air ALONE would have said, which is the answer this file
-- used to assert and the reason the deck is worth having: a room is not
-- a bottle of gas, it is a bottle of gas bolted to a tonne of hull.
local air_only = (pipe_e0 + n_room_0 * cv * T20C) / (n_room_1 * cv)
assert(air_only > T20C + 50.0, "gas alone would have been scalding: " .. air_only)
assert(
    blended < T20C + 5.0,
    "and the room is barely warm instead: " .. T20C .. " -> " .. blended
)
assert(blended > T20C, "warmer, though -- the joules did arrive: " .. blended)
assert(
    blended < hot_k - 400.0,
    "and nothing like as hot as what arrived -- it is not the pipe's "
        .. "temperature: " .. hot_k .. " vs " .. blended
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

-- ---------------------------------------------------------------
-- IN DEAD SPACE, A ROOM COOLS -- AND IT COOLS BY STEFAN-BOLTZMANN.
--
-- One tile, walled on all four sides, and nothing in it but air and the
-- steel it stands on. The sky is the real one this time: the microwave
-- background at 2.7 K and no star, which is what a mode that says
-- nothing about where the station is parked gets.
--
-- The claim is the CLOSED FORM. A body of heat capacity C radiating
-- over an area A into a sink cold enough to ignore cools as
-- dT/dt = -sigma*A*T^4/C, which integrates to
-- 1/T1^3 - 1/T0^3 = 3*sigma*A*t/C, so where it is after ten minutes is
-- arithmetic and not a guess. Both halves of that are readable: C is
-- `t.deck(x, y).capacity`, and A is emissivity times area -- 0.5 for
-- painted steel (content/tuning.luau) over two slab faces per solid,
-- because a deck has a face over it and a face under it, plus the same
-- again for each of the four walls, every one of which leans on this
-- tile alone and hands it the lot.
--
-- Why the answer is only good to 0.05 K: the air over the deck is a
-- second body, and it hands its own joules down as the deck cools. It
-- is a three-hundredth of the deck's capacity here, so it can slow the
-- fall by about a hundredth of a kelvin and no more. Anything larger
-- than that is the engine, not the air.
-- ---------------------------------------------------------------
t.world([==[(
    name: "one cold tile",
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
        'a': (turf: Floor, fixture: Some(Apc)),
    },
    rows: [
        "###",
        "#a#",
        "###",
    ],
    spawns: [(1, 1)],
    cables: [
        (1, 1, 1, 0, 1),
    ],
)]==], 7)

t.set_environment({ sink_k = 2.7, insolation = 0 })
t.tick()

local cell_c = t.deck(1, 1).capacity
near(
    cell_c,
    20000.0 + 4.0 * 62500.0,
    1e-6,
    "the deck is its own 20 000 J/K plus four walls that lean on nothing else"
)
near(t.deck(1, 1).temperature, T20C, 1e-9, "and it opens at room temperature")
local radiated_0 = t.space_radiated()

-- 0.5 emissivity, two slab faces, one square metre a tile: the deck's
-- own share, plus one whole wall's share for each of the four.
local EPS = 0.5
local cell_a = EPS * 2.0 + 4.0 * (EPS * 2.0)
near(cell_a, 5.0, 1e-12, "five square metres of grey body faces the sky")

t.run_seconds(600)

local closed = (1.0 / T20C ^ 3 + 3.0 * SIGMA * cell_a * 600.0 / cell_c) ^ (-1.0 / 3.0)
assert(T20C - closed >= 4.0, "ten minutes in dead space is worth real kelvin: " .. closed)
near(
    t.deck(1, 1).temperature,
    closed,
    0.05,
    "AND THE DECK IS WHERE THE FOURTH-POWER LAW PUTS IT"
)
assert(
    t.space_radiated() - radiated_0 >= 1.0,
    "with the joules booked as having left the world: " .. t.space_radiated()
)

-- ---------------------------------------------------------------
-- ...AND THE MIDDLE OF A ROOM COOLS FASTER THAN ITS CORNERS.
--
-- The same law, read as geometry. A wall is one object with one heat
-- capacity and two faces, shared among the open tiles that lean on it
-- (docs/MATTER-WORLD.md §5), so a corner tile is bolted to two walls' worth
-- of steel while a tile in the middle of the floor stands on its own
-- deck alone. Both radiate; the corner carries seven times the capacity
-- and only three times the area, so it falls at less than half the rate.
--
-- This is why a cooling room is not one number, and why every other
-- block in this file parks the station under an inert sky before
-- weighing anything: a room bleeding into space grows a temperature map
-- across its own floor, and gas drifts towards the cold end of it.
-- ---------------------------------------------------------------
t.world([==[(
    name: "cold room",
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "######",
        "#....#",
        "#.a..#",
        "#....#",
        "#...g#",
        "######",
    ],
    spawns: [(2, 2)],
    cables: [
        (1, 1, 1, 2, 4), (1, 1, 2, 2, 4), (2, 1, 1, 0, 2), (2, 1, 1, 0, 4),
        (2, 1, 1, 0, 8), (2, 1, 2, 0, 2), (2, 1, 2, 0, 4), (2, 1, 2, 0, 8),
        (3, 1, 1, 0, 2), (3, 1, 1, 0, 4), (3, 1, 1, 0, 8), (3, 1, 2, 0, 2),
        (3, 1, 2, 0, 4), (3, 1, 2, 0, 8), (4, 1, 1, 2, 8), (4, 1, 2, 2, 8),
        (1, 2, 1, 0, 1), (1, 2, 1, 0, 2), (1, 2, 1, 0, 4), (1, 2, 2, 0, 1),
        (1, 2, 2, 0, 2), (1, 2, 2, 0, 4), (2, 2, 1, 0, 1), (2, 2, 1, 0, 2),
        (2, 2, 1, 0, 4), (2, 2, 1, 0, 8), (2, 2, 2, 0, 1), (2, 2, 2, 0, 2),
        (2, 2, 2, 0, 4), (2, 2, 2, 0, 8), (3, 2, 1, 0, 1), (3, 2, 1, 0, 2),
        (3, 2, 1, 0, 4), (3, 2, 1, 0, 8), (3, 2, 2, 0, 1), (3, 2, 2, 0, 2),
        (3, 2, 2, 0, 4), (3, 2, 2, 0, 8), (4, 2, 1, 0, 1), (4, 2, 1, 0, 2),
        (4, 2, 1, 0, 8), (4, 2, 2, 0, 1), (4, 2, 2, 0, 2), (4, 2, 2, 0, 8),
        (1, 3, 1, 0, 1), (1, 3, 1, 0, 2), (1, 3, 1, 0, 4), (1, 3, 2, 0, 1),
        (1, 3, 2, 0, 2), (1, 3, 2, 0, 4), (2, 3, 1, 0, 1), (2, 3, 1, 0, 2),
        (2, 3, 1, 0, 4), (2, 3, 1, 0, 8), (2, 3, 2, 0, 1), (2, 3, 2, 0, 2),
        (2, 3, 2, 0, 4), (2, 3, 2, 0, 8), (3, 3, 1, 0, 1), (3, 3, 1, 0, 2),
        (3, 3, 1, 0, 4), (3, 3, 1, 0, 8), (3, 3, 2, 0, 1), (3, 3, 2, 0, 2),
        (3, 3, 2, 0, 4), (3, 3, 2, 0, 8), (4, 3, 1, 0, 1), (4, 3, 1, 0, 2),
        (4, 3, 1, 0, 8), (4, 3, 2, 0, 1), (4, 3, 2, 0, 2), (4, 3, 2, 0, 8),
        (1, 4, 1, 1, 4), (1, 4, 2, 1, 4), (2, 4, 1, 0, 1), (2, 4, 1, 0, 4),
        (2, 4, 1, 0, 8), (2, 4, 2, 0, 1), (2, 4, 2, 0, 4), (2, 4, 2, 0, 8),
        (3, 4, 1, 0, 1), (3, 4, 1, 0, 4), (3, 4, 1, 0, 8), (3, 4, 2, 0, 1),
        (3, 4, 2, 0, 4), (3, 4, 2, 0, 8), (4, 4, 1, 0, 1), (4, 4, 1, 0, 8),
        (4, 4, 2, 0, 1), (4, 4, 2, 0, 8),
    ],
)]==], 7)

t.set_environment({ sink_k = 2.7, insolation = 0 })
t.tick()

near(t.deck(1, 1).capacity, 20000.0 + 2.0 * 62500.0, 1e-6, "a corner leans on two walls")
near(t.deck(2, 2).capacity, 20000.0, 1e-6, "and the middle of the floor on none")

t.run_seconds(600)
local corner_k = t.deck(1, 1).temperature
local middle_k = t.deck(2, 2).temperature
assert(T20C - corner_k >= 1.0, "the corner cooled: " .. corner_k)
assert(
    corner_k - middle_k >= 2.0,
    "and the middle of the room cooled further, standing on less steel: "
        .. middle_k .. " vs " .. corner_k
)

-- ---------------------------------------------------------------
-- UNDER A STAR, THE SAME DECK WARMS.
--
-- Insolation is the other half of step 5d and it uses the same eA: a
-- grey body absorbs exactly the fraction it emits (Kirchhoff), and the
-- sun reaches one face of a slab that radiates from two, which is the
-- halving in `P_in = S*eA/2`. At 2700 W/m^2 -- a close solar orbit, the
-- rarest roll on the station's roster -- that beats what a
-- room-temperature hull radiates several times over, so the deck climbs
-- instead of falling, and the net register runs NEGATIVE: sunlight is
-- energy arriving from outside the world's own books.
-- ---------------------------------------------------------------
t.world([==[(
    name: "one hot tile",
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
        'a': (turf: Floor, fixture: Some(Apc)),
    },
    rows: [
        "###",
        "#a#",
        "###",
    ],
    spawns: [(1, 1)],
    cables: [
        (1, 1, 1, 0, 1),
    ],
)]==], 7)

t.set_environment({ sink_k = 2.7, insolation = 2700 })
t.tick()
near(t.deck(1, 1).temperature, T20C, 1e-9, "the same deck, opening at the same place")

t.run_seconds(600)
local warmed = t.deck(1, 1).temperature
assert(warmed - T20C >= 5.0, "ten minutes sunward warms the deck: " .. warmed)
assert(
    t.space_radiated() <= 0.0,
    "and the net radiated register runs backwards under a star: " .. t.space_radiated()
)

-- The station knows where it is parked, and says so in the same shape
-- content reads it in (`sim.environment`).
local sky = t.environment()
assert(sky.sink_k == 2.7, "the sink is the one that was set: " .. sky.sink_k)
assert(sky.insolation == 2700, "and so is the sunlight: " .. sky.insolation)
assert(
    sky.id == "custom",
    "a hand-set sky stops being the roster's roll and says so: " .. sky.id
)
