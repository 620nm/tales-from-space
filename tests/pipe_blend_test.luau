-- Two charged runs at different temperatures, and the wheel between
-- them. What this file is about is the JOULE BOOK.
--
-- atmos_devices_test.luau already settles what a manual valve IS: shut
-- it is a wall two pipelines cannot see past, open it is not a machine
-- at all but a single body of gas reconciling by volume (tg's
-- `custom_reconcilation`, valve.dm:56-61), and the moles come out even
-- on both sides of the turn. All of that is pressure, and all of it is
-- proved over there. None of it is re-proved here.
--
-- What a pressure cannot say is where the ENERGY went. A fusion that
-- landed both ends on the right kPa while quietly minting or losing
-- heat would read perfectly on every gauge in that file -- the two runs
-- would even come out at plausible temperatures. So every assertion
-- below is weighed on `t.pipe_energy`, the conserved quantity, and the
-- temperature that comes out is checked against what those joules say
-- it must be rather than against a number somebody expected.
--
-- The two runs are deliberately LOPSIDED -- five lengths against one --
-- because that is what separates the right answer from the plausible
-- one. An energy blend is the mole-weighted mean of the two
-- temperatures; the answer that feels right is the plain average of
-- them; and on equal runs those are the same number and prove nothing.
--
-- Nothing a player can reach makes one pipe hotter than another yet, so
-- the gradient comes from `t.heat_pipe` -- precondition scaffolding
-- with the same standing as `t.set_health`, never an assertion, and it
-- goes away the day a burn chamber exists.

local T20C = 293.15

-- tg's UNARY_PIPE_VOLUME * 2 per length, and the 200 L component
-- mixture standing in every device port (components_base.dm:39). What
-- they are FOR here is the last scenario: a shut valve divides one body
-- of gas by volume, so these say what each side's share of the blend
-- ought to be.
local PIPE_M3 = 0.070
local PORT_M3 = 0.200
local WEST_M3 = 5.0 * PIPE_M3 + PORT_M3
local EAST_M3 = 1.0 * PIPE_M3 + PORT_M3

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function moles_in(x, y)
    local sum = 0.0
    for _, moles in pairs(t.pipe_gas(x, y) or {}) do
        sum = sum + moles
    end
    return sum
end

-- Five lengths west, one east, a wheel between them, and an engineer
-- standing under it with their hands empty.
t.world([==[(
    name: "lopsided runs",
    legend: {
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "##########",
        "#........#",
        "#........#",
        "##########",
    ],
    spawns: [(6, 2)],
    pipes: [(1, 1, 4), (2, 1, 4), (3, 1, 4), (4, 1, 4), (5, 1, 4), (7, 1, 4)],
    structures: [(6, 1, "manual_valve")],
)]==], 7)

local p = t.join()
t.tick()

assert(t.structure_at(6, 1).id == "manual_valve", "the wheel is where the map put it")
assert(t.structure_at(6, 1).state == "shut", "and it opens the shift shut")
assert(t.pipe(6, 1) == 0, "a run does not pass through a machine")
assert(t.pipe_pressure(1, 1) > 90.0, "both mapped runs are handed over charged")
assert(t.pipe_pressure(7, 1) > 90.0)
near(t.pipe_temperature(1, 1), T20C, 0.01, "both at room temperature")
near(t.pipe_temperature(7, 1), T20C, 0.01, "the short one too")

-- ---- one molar heat capacity, and both runs answer to it ----
--
-- E / nT out of each run's own three readings. They agree because the
-- two are the same standard admixture, which is what lets a
-- mole-weighted mean of TEMPERATURES be the same statement as an
-- energy book. Taken off the world rather than written down, so a
-- station that changes what its mains are charged with does not
-- silently invalidate the arithmetic below.
local west_n_0 = moles_in(1, 1)
local east_n_0 = moles_in(7, 1)
local cv = t.pipe_energy(1, 1) / (west_n_0 * t.pipe_temperature(1, 1))
near(
    t.pipe_energy(7, 1) / (east_n_0 * t.pipe_temperature(7, 1)),
    cv,
    1e-9,
    "both runs carry the same admixture, so one capacity serves both books"
)
assert(
    west_n_0 > east_n_0 * 1.9,
    "and the west run is the heavy one: " .. west_n_0 .. " vs " .. east_n_0 .. " mol"
)

-- ---- the gradient, on the SMALL side ----
t.heat_pipe(7, 1, 200000.0)
t.tick()
local hot_k = t.pipe_temperature(7, 1)
local cold_k = t.pipe_temperature(1, 1)
assert(hot_k > 1000.0, "the short run is glowing: " .. hot_k)
near(cold_k, T20C, 0.01, "and the long one has not noticed: " .. cold_k)
near(moles_in(7, 1), east_n_0, 1e-9, "heat is not moles: nothing was added")

-- The books, read TWICE, because a shut valve leaves two nets and each
-- reports its own.
local energy_0 = t.pipe_energy(1, 1) + t.pipe_energy(7, 1)
local moles_0 = west_n_0 + east_n_0
local east_energy_0 = t.pipe_energy(7, 1)
local west_energy_0 = t.pipe_energy(1, 1)

-- ---------------------------------------------------------------
-- A SHUT VALVE STOPS HEAT AS WELL AS GAS.
--
-- The negative that costs nothing and would be embarrassing to miss. A
-- thousand kelvin standing one tile from room temperature, with the
-- machine between them shut: half a minute later neither number has
-- moved. A valve is a boundary between two pipelines, not a plate heat
-- exchanger, and it does not conduct on the quiet.
-- ---------------------------------------------------------------
t.run_seconds(30)
near(t.pipe_temperature(7, 1), hot_k, 0.5, "the hot run stayed hot behind the wheel")
near(t.pipe_temperature(1, 1), cold_k, 0.5, "and the cold run stayed cold")
near(t.pipe_energy(1, 1) + t.pipe_energy(7, 1), energy_0, 1.0, "with the books untouched")

-- ---------------------------------------------------------------
-- OPEN, IT IS ONE NET, AND ITS TEMPERATURE IS THE JOULES DIVIDED OUT.
--
-- Turning the wheel does not start a pump. It fuses the two pipelines
-- into one body of gas, and the giveaway is in the instrument: both
-- ends now report the SAME energy, because there is only one net left
-- to report. The books are therefore read ONCE on this side of the
-- turn, and reading them twice would double every joule in the run --
-- which is itself the sharpest thing "an open valve is not a machine"
-- could possibly mean.
-- ---------------------------------------------------------------
t.click(p, 6, 1, t.target_at(6, 1, "manual_valve"))
t.run_seconds(2)
assert(t.structure_at(6, 1).state == "open", "the wheel is over")
t.run_seconds(2)

assert(
    t.pipe_energy(1, 1) == t.pipe_energy(7, 1),
    "both ends report one net's joules, to the bit: "
        .. t.pipe_energy(1, 1) .. " vs " .. t.pipe_energy(7, 1)
)
local fused_energy = t.pipe_energy(1, 1)
local fused_moles = moles_in(1, 1)
local fused_k = t.pipe_temperature(1, 1)

near(
    fused_energy,
    energy_0,
    energy_0 * 1e-6,
    "NOT A JOULE WAS MINTED: " .. energy_0 .. " J -> " .. fused_energy .. " J"
)
near(
    fused_moles,
    moles_0,
    moles_0 * 1e-9,
    "and not a mole: " .. moles_0 .. " -> " .. fused_moles
)
near(t.pipe_temperature(7, 1), fused_k, 1e-9, "one net, one temperature, both ends")

-- The temperature is not a separate fact. It is what those joules,
-- spread through those moles, come to -- which is the same number as
-- the MOLE-weighted mean of the two runs, and is emphatically not the
-- average of the two temperatures.
near(
    fused_k,
    fused_energy / (fused_moles * cv),
    1e-6,
    "the blend is the energy book divided out"
)
near(
    fused_k,
    (west_n_0 * cold_k + east_n_0 * hot_k) / moles_0,
    0.01,
    "which is the mole-weighted mean of the two runs"
)
assert(fused_k > cold_k and fused_k < hot_k, "and it lands between them: " .. fused_k)
assert(
    math.abs(fused_k - (cold_k + hot_k) / 2.0) > 100.0,
    "NOT the average of the two temperatures, which on lopsided runs is "
        .. "a different answer by a hundred kelvin and more: "
        .. (cold_k + hot_k) / 2.0 .. " vs " .. fused_k
)

-- ---------------------------------------------------------------
-- SHUT AGAIN, BOTH SIDES KEEP THE BLEND.
--
-- Dividing one body of gas back in two divides its joules with it, by
-- volume, and neither run gets its old identity back. The short run
-- that was glowing is now merely warm and stays that way; the long run
-- that was cold is warm and stays that way; and what the short one lost
-- is exactly what the long one gained, which is the whole of "you
-- cannot un-mix by shutting the wheel".
-- ---------------------------------------------------------------
t.click(p, 6, 1, t.target_at(6, 1, "manual_valve"))
t.run_seconds(3)
assert(t.structure_at(6, 1).state == "shut", "shut again")
t.run_seconds(1)

near(t.pipe_temperature(1, 1), fused_k, 1e-6, "the west run kept the blend")
near(t.pipe_temperature(7, 1), fused_k, 1e-6, "and so did the east one")
near(
    t.pipe_energy(1, 1) + t.pipe_energy(7, 1),
    energy_0,
    energy_0 * 1e-6,
    "and the two books add back up to what went in"
)
near(
    t.pipe_energy(1, 1) / (t.pipe_energy(1, 1) + t.pipe_energy(7, 1)),
    WEST_M3 / (WEST_M3 + EAST_M3),
    1e-6,
    "split by volume, which is the same division the moles took"
)
near(
    moles_in(1, 1) / (moles_in(1, 1) + moles_in(7, 1)),
    WEST_M3 / (WEST_M3 + EAST_M3),
    1e-6,
    "as the moles say too"
)
assert(
    t.pipe_energy(7, 1) < east_energy_0 * 0.6,
    "the short run gave up most of its heat for good: "
        .. east_energy_0 .. " J -> " .. t.pipe_energy(7, 1) .. " J"
)
assert(
    t.pipe_temperature(7, 1) < hot_k - 400.0,
    "and it is nowhere near as hot as it was: " .. hot_k .. " K -> "
        .. t.pipe_temperature(7, 1) .. " K"
)
near(
    t.pipe_energy(1, 1) - west_energy_0,
    east_energy_0 - t.pipe_energy(7, 1),
    energy_0 * 1e-6,
    "and what the short run lost is exactly what the long one gained"
)

-- And it stays that way. A shut valve is a wall in both directions:
-- nothing crosses back, and neither side drifts anywhere on its own.
local rest_west = t.pipe_temperature(1, 1)
local rest_east = t.pipe_temperature(7, 1)
t.run_seconds(30)
near(t.pipe_temperature(1, 1), rest_west, 0.01, "the west run settles where it is")
near(t.pipe_temperature(7, 1), rest_east, 0.01, "and the east one with it")
near(
    t.pipe_energy(1, 1) + t.pipe_energy(7, 1),
    energy_0,
    energy_0 * 1e-6,
    "with the joule book still balancing at the end of it"
)
