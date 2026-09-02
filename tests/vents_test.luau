-- The vents: the two machines that reach out of the plumbing and into
-- a ROOM, and between them the entire reason a distribution main is
-- worth laying.
--
-- room_devices_test.luau has the scrubber and the injector, and
-- vent_construction_test.luau has these two being carried, bolted down
-- and taken up again. This file is about their ARITHMETIC, which is
-- what a station lives or dies by and what nothing else asserts.
--
-- A powered vent is a setpoint machine and that is the whole of it
-- (atmos_machines/vent.rs, tg's vent_pump with both bounds live):
-- below 0.99 of an atmosphere it releases into the room, above 1.08 it
-- siphons the room back into the run, and between those two lines it
-- does nothing at all. Those three numbers are the MACHINE's, off
-- structures/vent.luau -- vent_panel_test.luau is where they get moved
-- and where the sim is made to prove it reads them; this file is what
-- the pack's own defaults do. A passive vent is a HOLE -- no setpoint, no
-- power, no direction -- and it equalises the run and the room by molar
-- density, whichever way that runs (tg's `internal.equalize(external)`).
--
-- Neither is switched, so nobody joins these worlds: every scenario
-- below is what the STATION does while the crew is somewhere else,
-- which is also what keeps the mole books exact -- a crewman standing
-- in the room would be breathing on them.

local ONE_ATM = 101.325
-- The two lines the powered vent lives between, in kPa: the pack's own
-- `release_below_kpa` and `siphon_above_kpa` (structures/vent.luau).
local SUPPLIES_UNDER = ONE_ATM * 0.99
local SIPHONS_OVER = ONE_ATM * 1.08

local R, T20C = 8.314, 293.15
-- A canister is tg's 2000 L.
local CAN_M3 = 2.0

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

-- Moles in a volume at a pressure and room temperature -- the ideal gas
-- law, so a canister's GAUGE can be weighed against the mole books the
-- run and the room are read in.
local function moles(kpa, m3)
    return kpa * 1000.0 * m3 / (R * T20C)
end

-- Everything standing in the run under a tile, in moles.
local function pipe_moles(x, y)
    local n = 0.0
    for _, amount in pairs(t.pipe_gas(x, y) or {}) do
        n = n + amount
    end
    return n
end

-- ...and everything in the room over a list of tiles. A room is one
-- cell per TILE and a vent only ever works the tile it stands on, so
-- anything asserted about a room filling, emptying or holding still is
-- asserted on the whole room's conserved quantity.
local function room_moles(tiles)
    local n = 0.0
    for _, tile in ipairs(tiles) do
        for _, amount in pairs(t.room_gas(tile[1], tile[2]) or {}) do
            n = n + amount
        end
    end
    return n
end

-- A whole room's air as ONE pressure: its moles spread over its tiles.
-- A single tile's reading sloshes for a long time after anything
-- violent happens to a room -- gas crosses tile to tile at its own pace
-- -- so a room that is meant to be holding STILL is read this way, on
-- the conserved quantity, and never off one tile.
local function room_kpa(tiles)
    return room_moles(tiles) * R * T20C / (#tiles * 1000.0)
end

local function row(x0, x1, y)
    local tiles = {}
    for x = x0, x1 do
        tiles[#tiles + 1] = { x, y }
    end
    return tiles
end

-- ---------------------------------------------------------------
-- A VENT WORKS A ROOM TO ONE ATMOSPHERE AND THEN STOPS.
--
-- The sentence room_devices_test.luau names the injector against ("a
-- vent works a room to one atmosphere and stops; this keeps going")
-- and never proves, because proving it is this file's job.
--
-- The compartment below is a sealed corridor with a vent at one end, a
-- canister on a connector port in the middle of it, and a real wired
-- grid: a generator, an APC, a backbone pair and a room circuit running
-- west under everything to the vent's own tile. That grid is not
-- decoration -- cable is what powers a station, so a map without it is
-- a map whose fan never turns.
--
-- Open the deck beside the vent, let the corridor blow down, put the
-- deck back, and then watch the one number that matters: the tile the
-- fan stands on, sampled every second for two and a half minutes, must
-- climb to the setpoint and NEVER cross it. tg's release arithmetic is
-- demand-limited (`(SETPOINT - room_pa) * volume / RT` at the run's
-- temperature), which means overshoot is not clamped away afterwards --
-- it is unrepresentable.
-- ---------------------------------------------------------------
local SUPPLY_MAP = [==[(
    name: "supply vent",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'c': (turf: Plating),
        'g': (turf: Plating, fixture: Some(Generator)),
        'a': (turf: Plating, fixture: Some(Apc)),
    },
    rows: [
        "#########",
        "#...c.ga#",
        "#########",
    ],
    spawns: [(5, 1)],
    // The pump regulates the vent's feed at one atmosphere off the
    // bottle's forty -- tg's own station shape, because a fastened
    // bottle IS its line and a vent on a forty-atmosphere main would
    // out-blow the very breach this file is about.
    pipes: [],
    blends: {
        "canister_air": (rows: [("o2", 392.86967015394526), ("n2", 1477.93828296008)], temperature_k: 293.15, amount: per_tile),
    },
    structures: [
        (2, 1, "vent"),
        (3, 1, "gas_pump", "running", { "dir": "west" }),
        (4, 1, "connector_port", { "pipe": "west" }),
        (4, 1, "canister", { "blend": "canister_air" }),
    ],
    // Backbone (L2) under the generator and the APC; room circuit (L1) from the
    // APC's own tile west along the corridor to the vent.
    cables: [
        (6, 1, 3), (7, 1, 3),
        (5, 1, 1), (4, 1, 1), (3, 1, 1), (2, 1, 1),
    ],
)]==]

t.world(SUPPLY_MAP, 7)
-- An INERT SKY, and every bench in this file gets one. A hull radiating
-- against a sink at its own temperature emits exactly what it absorbs,
-- so nothing here cools -- by physics, not by a bypass flag. Without it
-- a bench watched for three minutes is also watching the station bleed
-- heat into space, and a corridor that cooled two kelvin reads a
-- kilopascal light on a gauge that was meant to be measuring the vent.
t.set_environment({ sink_k = 293.15, insolation = 0 })
t.tick()

local apc = t.apc_at(7, 1)
assert(apc ~= nil, "the map wired an APC")
assert(apc.equipment == true, "and the generator behind it is feeding the equipment channel")
assert(t.canister_pressure(4, 1) > 4000.0, "a fresh canister is at 45 atm")
assert(t.room_pressure(2, 1) > 90.0, "and the corridor opens breathable off the regulated feed")

-- Tear the deck open beside the vent. There is no breach STATE anywhere
-- (CLAUDE.md): a hull breach is a floor that became space, so that is
-- literally what this is, through the one geometry seam.
assert(t.set_turf(1, 1, "space"), "the deck beside the vent opens")
t.run_seconds(20)
local emptied = t.room_pressure(2, 1)
assert(
    emptied < SUPPLIES_UNDER,
    "the corridor blew down past the vent's release line: " .. emptied .. " kPa"
)
assert(t.set_turf(1, 1, "plating"), "and the deck goes back")
t.tick()

-- Two and a half minutes, sampled every second of them. The peak is
-- the assertion.
local peak = 0.0
for _ = 1, 150 do
    t.run_seconds(1)
    peak = math.max(peak, t.room_pressure(2, 1))
end
assert(
    peak <= ONE_ATM + 0.5,
    "the fan never once blew its own tile past one atmosphere: " .. peak .. " kPa"
)
assert(
    t.room_pressure(5, 1) > SUPPLIES_UNDER,
    "and the corridor is back inside the band: " .. t.room_pressure(5, 1) .. " kPa"
)

-- ...and it STAYS stopped, which is the half of "arrest" a single
-- reading cannot show. A settled room is a room the vent has no demand
-- from, so the canister behind it stops spending -- exactly the
-- assertion canister_test.luau opens with, said the other way round.
local settled_room = t.room_pressure(5, 1)
local settled_can = t.canister_pressure(4, 1)
t.run_seconds(60)
near(t.room_pressure(5, 1), settled_room, 0.5, "a minute later the room has not moved")
near(t.canister_pressure(4, 1), settled_can, 1.0, "and a settled room costs the bottle nothing")

-- ---------------------------------------------------------------
-- WITH THE BREAKER OUT, IT IS A GRILLE.
--
-- The same corridor, the same full canister, the same charged run --
-- and the fan between them stops being a machine. tg opens
-- `process_atmos` with `if(!on || !is_operational) return` and that is
-- the whole of it: no coasting, no reserve, no trickle.
--
-- The proof is deliberately the cruellest arrangement there is. Trip
-- the station breaker, open the hull, weld it shut again, and then
-- leave a sealed near-vacuum sitting under a live distribution main
-- with 45 atmospheres of air on the end of it for a full minute. It
-- stays a vacuum, the run never gives up a mole, and the gauge never
-- moves.
-- ---------------------------------------------------------------
t.outage()
t.run_seconds(3)
local dark = t.apc_at(7, 1)
assert(dark.equipment == false, "the breaker took the equipment channel down")
assert(dark.alarmed == true, "and the APC is calling it")

local dark_net = pipe_moles(3, 1)
local dark_can = t.canister_pressure(4, 1)
assert(t.set_turf(1, 1, "space"), "the deck opens again")
t.run_seconds(45)
assert(t.set_turf(1, 1, "plating"), "and is sealed again")
t.tick()

local CORRIDOR = row(1, 7, 1)
local sealed = room_kpa(CORRIDOR)
assert(sealed < 40.0, "sealed on well under half an atmosphere: " .. sealed .. " kPa")
t.run_seconds(60)
near(room_kpa(CORRIDOR), sealed, 0.001, "a dead vent gives the room nothing back")
near(pipe_moles(3, 1), dark_net, 0.001, "and takes not one mole out of the run")
near(
    t.canister_pressure(4, 1),
    dark_can,
    0.5,
    "so the bottle behind it is never asked for anything either"
)

-- ---------------------------------------------------------------
-- OVER-PRESSURE RUNS THE SAME MACHINE BACKWARDS.
--
-- The second bound, which is what makes a vent a vent rather than an
-- injector: above 1.08 atmospheres the fan turns round and puts the
-- room's surplus back down the main it came up.
--
-- No canister here on purpose. The room and the run are the only two
-- books in this world, so what leaves one is on the other to the mole,
-- and the sum is a closed proof rather than a direction.
-- ---------------------------------------------------------------
local RELIEF_MAP = [==[(
    name: "relief vent",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'g': (turf: Plating, fixture: Some(Generator)),
        'a': (turf: Plating, fixture: Some(Apc)),
    },
    rows: [
        "#########",
        "#....ga.#",
        "#########",
    ],
    spawns: [(4, 1)],
    pipes: [(2, 1, 4), (3, 1, 4), (4, 1, 4)],
    structures: [(1, 1, "vent")],
    cables: [
        (5, 1, 3), (6, 1, 3),
        (4, 1, 1), (3, 1, 1), (2, 1, 1), (1, 1, 1),
    ],
)]==]

t.world(RELIEF_MAP, 7)
t.set_environment({ sink_k = 293.15, insolation = 0 }) -- inert sky, as above
t.tick()

local ROOM = row(1, 7, 1)
assert(t.apc_at(6, 1).equipment == true, "this bench is wired too")

-- A room already inside the band is a room the vent has nothing to say
-- to, in EITHER direction. The negative comes first because it is the
-- one a machine with a sloppy dead band would fail.
local idle_room = room_moles(ROOM)
local idle_net = pipe_moles(2, 1)
assert(idle_net > 0.0, "the run opens the shift charged")
t.run_seconds(10)
near(room_moles(ROOM), idle_room, 0.001, "a room at one atmosphere is not touched")
near(pipe_moles(2, 1), idle_net, 0.001, "and neither is the run behind the vent")

-- Foul it well past the siphon line. Thirty moles a tile is what a
-- runaway would put in a corridor; `t.foul_room` is the same
-- precondition setter station_air_test.luau uses for a crew's exhaust.
for x = 1, 7 do
    assert(t.foul_room(x, 1, "n2", 30.0), "gas goes into every tile of the room")
end
t.tick()

local fouled_room = room_moles(ROOM)
near(fouled_room, idle_room + 210.0, 0.001, "two hundred and ten moles went in")
assert(
    t.room_pressure(1, 1) > SIPHONS_OVER,
    "which puts the vent's own tile over its siphon line: " .. t.room_pressure(1, 1) .. " kPa"
)
local fouled_far = t.room_pressure(7, 1)
local books = fouled_room + pipe_moles(2, 1)

t.run_seconds(120)

assert(
    t.room_pressure(1, 1) <= SIPHONS_OVER + 0.05,
    "the tile the fan stands on is back inside its dead band: "
        .. t.room_pressure(1, 1) .. " kPa, the line being " .. SIPHONS_OVER
)
assert(
    t.room_pressure(1, 1) > ONE_ATM,
    "and it stopped THERE rather than emptying the room -- a vent has a"
        .. " floor as well as a ceiling, which is the whole difference"
        .. " between it and a scrubber set to siphon: " .. t.room_pressure(1, 1)
)
assert(
    t.room_pressure(7, 1) < fouled_far - 40.0,
    "the far end of the corridor came down with it, at the pace gas"
        .. " crosses tiles rather than the pace the fan works: "
        .. fouled_far .. " -> " .. t.room_pressure(7, 1) .. " kPa"
)
assert(
    pipe_moles(2, 1) > idle_net + 5.0,
    "and the surplus went down the main: " .. idle_net .. " -> " .. pipe_moles(2, 1) .. " mol"
)
near(
    room_moles(ROOM) + pipe_moles(2, 1),
    books,
    0.001,
    "with every mole of it still somewhere"
)

-- ---------------------------------------------------------------
-- A PASSIVE VENT IS A HOLE, AND A HOLE WORKS BOTH WAYS.
--
-- No power, no setpoint, no direction, no switch: each pass it moves
-- gas until the run and the tile over it hold the same molar DENSITY,
-- and that is the entire machine. Which way that runs is not a property
-- of the vent at all -- it is a property of which side is fuller, and
-- this scenario drives it both ways in one world.
--
-- Nothing here is wired. That is the point: the powered vent above
-- became a grille the moment the breaker went, and this one does not
-- care, which is exactly why a distribution line is fed through one.
-- ---------------------------------------------------------------
local PASSIVE_MAP = [==[(
    name: "passive vent",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'c': (turf: Plating),
    },
    rows: [
        "#########",
        "#....c..#",
        "#########",
    ],
    spawns: [(4, 1)],
    pipes: [(3, 1, 4), (4, 1, 4)],
    blends: {
        "canister_air": (rows: [("o2", 392.86967015394526), ("n2", 1477.93828296008)], temperature_k: 293.15, amount: per_tile),
    },
    structures: [
        (2, 1, "passive_vent"), (5, 1, "connector_port"),
        (5, 1, "canister", { "blend": "canister_air", "open": true }),
    ],
)]==]

t.world(PASSIVE_MAP, 7)
t.set_environment({ sink_k = 293.15, insolation = 0 }) -- inert sky, as above
t.tick()

local BAY = row(1, 7, 1)
-- No regulator anywhere, on purpose -- and that now has the meaning tg
-- gives it: a passive vent is a hole, the fastened bottle IS the line,
-- so the bay runs to the system's own uniform density, far past
-- breathable. An unpowered bay off a fat bottle is a pressure chamber;
-- a breathable one needs the powered vent's setpoint, which is the
-- other half of this file.
assert(t.pipe_pressure(3, 1) > 90.0, "the bottle charged the run through its socket")
t.run_seconds(20)
local settled_bay = t.room_pressure(2, 1)
assert(settled_bay > 300.0, "the bay runs far past an atmosphere: " .. settled_bay)

-- Open the deck beside the vent. There is no valve anywhere in this
-- world: the bay empties into space and the run empties into the bay
-- after it, so the bottle is left pouring itself out through a hole in
-- the floor -- which is what an open vent costs you, and why tg gives
-- the powered one a shut-off and this one none.
-- Ten seconds of hole, not thirty: the bottle is ONE body with its
-- line now, so a breach drinks the whole reserve at line speed rather
-- than at a valve's metered trickle -- leave it open half a minute and
-- there is nothing left to refill the bay WITH.
local before_hole = t.canister_pressure(5, 1)
assert(t.set_turf(1, 1, "space"), "the deck opens")
t.run_seconds(10)
assert(
    t.room_pressure(2, 1) < settled_bay * 0.5,
    "the bay blew down: " .. settled_bay .. " -> " .. t.room_pressure(2, 1)
)
assert(
    t.canister_pressure(5, 1) < before_hole - 50.0,
    "and the bottle paid for every second of it: "
        .. before_hole .. " -> " .. t.canister_pressure(5, 1) .. " kPa"
)
assert(t.set_turf(1, 1, "plating"), "and is sealed again")
t.tick()

-- ---- sealed again: the whole system comes level ----
--
-- Nothing is powered and nothing regulates, so the one thing this
-- world can do once the hole is shut is come to ONE density across
-- bay, run and bottle -- `internal.equalize` writ across every holder
-- there is. Direction is whatever the breach left uneven; the claims
-- are that it levels, and that not a mole moves in or out of a sealed
-- world while it does.
local bay_0 = room_moles(BAY)
local net_0 = pipe_moles(3, 1)
local can_0 = moles(t.canister_pressure(5, 1), CAN_M3)
t.run_seconds(120)
local bay_1 = room_moles(BAY)
local net_1 = pipe_moles(3, 1)
local can_1 = moles(t.canister_pressure(5, 1), CAN_M3)

near(
    t.pipe_pressure(3, 1),
    t.room_pressure(2, 1),
    1.0,
    "run and bay came level -- at one temperature, equal pressure IS"
        .. " equal density, which is the whole of `internal.equalize`"
)
near(
    t.canister_pressure(5, 1),
    t.room_pressure(2, 1),
    5.0,
    "and the bottle came level with both: it is one body with its line"
)
near(
    bay_1 + net_1 + can_1,
    bay_0 + net_0 + can_0,
    0.001,
    "and a sealed world neither made nor lost a mole while it settled"
)

-- ---- bay -> run: the same hole, the other way ----
--
-- Foul the bay and it is the fuller side, so the flow reverses -- into
-- the run, and on into the bottle, which takes its share like the
-- volume it is (there is no release valve in this coupling to leave it
-- out). The three books are closed, so the sum is exact.
local base_bay = room_moles(BAY)
local base_net = pipe_moles(3, 1)
local base_can = t.canister_pressure(5, 1)
local base_held = base_bay + base_net + moles(base_can, CAN_M3)
for x = 1, 7 do
    assert(t.foul_room(x, 1, "n2", 30.0), "gas goes into every tile of the bay")
end
t.tick()
t.run_seconds(120)

assert(
    pipe_moles(3, 1) > base_net + 5.0,
    "a fouled room pushes back INTO the line: "
        .. base_net .. " -> " .. pipe_moles(3, 1) .. " mol"
)
assert(
    room_moles(BAY) < base_bay + 210.0 - 5.0,
    "and the bay is lighter than what was put in it: " .. room_moles(BAY) .. " mol"
)
assert(
    t.canister_pressure(5, 1) > base_can + 0.5,
    "the bottle took its share of what was pushed back: "
        .. base_can .. " -> " .. t.canister_pressure(5, 1) .. " kPa"
)
near(
    room_moles(BAY) + pipe_moles(3, 1) + moles(t.canister_pressure(5, 1), CAN_M3),
    base_held + 210.0,
    0.001,
    "and the books balance to the mole across all three holders"
)
near(
    t.pipe_pressure(3, 1),
    t.room_pressure(2, 1),
    1.0,
    "level again, from the other side"
)
