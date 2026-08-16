-- Four mouths, four pipelines, one reservoir.
--
-- tg's tank is QUATERNARY (tank.dm:21): a port on every cardinal, and
-- `custom_reconcilation` folds `air_contents` into EVERY pipeline those
-- ports reach, each pass, in both directions. Nothing about that is a
-- manifold -- the four runs never see each other's pipe -- and nothing
-- about it is four separate stores. It is one body of gas with four
-- doors, which is a strange enough machine to be worth its own file.
--
-- The room below is one vessel with four runs off it, joined to nothing
-- else and no two the same length: three lengths north, two south, one
-- east, four west (the last one turns a corner, because a pipeline is
-- not a straight line). Four DIFFERENT volumes on purpose -- four equal
-- runs read identically whether the vessel served them together or in
-- turn, and identical numbers prove nothing about how they got there.

local PIPE_M3 = 0.070
local PORT_M3 = 0.200
local TANK_M3 = 2.5

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function total(mix)
    local sum = 0.0
    for _, moles in pairs(mix or {}) do
        sum = sum + moles
    end
    return sum
end

t.world([==[(
    name: "four mouths",
    legend: { '.': (turf: Plating), '#': (turf: Wall) },
    rows: [
        "#########",
        "#.......#",
        "#.......#",
        "#.......#",
        "#.......#",
        "#.......#",
        "#.......#",
        "#########",
    ],
    spawns: [(3, 3)],
    items: [(3, 3, "wrench")],
    structures: [(4, 4, "stationary_tank", "anchored", ("o2", 20000.0))],
    pipes: [
        (4, 3, 4), (4, 2, 4), (4, 1, 4),
        (4, 5, 4), (4, 6, 4),
        (5, 4, 4),
        (3, 4, 4), (2, 4, 4), (1, 4, 4), (1, 5, 4),
    ],
)]==], 7)

local p = t.join()
t.tick()

-- Each run's own volume: its lengths, plus the one mouth of the vessel
-- folded into it (200 L, tg's `component_mixture`). The vessel pays a
-- mouth into each of the four, which is why a tank on four runs is a
-- larger piece of plumbing than a tank on one.
local NORTH_M3 = 3.0 * PIPE_M3 + PORT_M3
local SOUTH_M3 = 2.0 * PIPE_M3 + PORT_M3
local EAST_M3 = 1.0 * PIPE_M3 + PORT_M3
local WEST_M3 = 4.0 * PIPE_M3 + PORT_M3

local runs = {
    { 4, 3, NORTH_M3, "north" },
    { 4, 5, SOUTH_M3, "south" },
    { 5, 4, EAST_M3, "east" },
    { 3, 4, WEST_M3, "west" },
}

assert(t.pipe(4, 4) == 0, "no length runs under the machine itself")
for _, run in ipairs(runs) do
    assert(t.pipe_pressure(run[1], run[2]) ~= nil, run[4] .. " is a real net")
end

-- FOUR NETS, not one. A net reports one energy from any tile in it
-- (pipe_blend_test.luau), so four different books at four tiles one
-- step from the same machine is the proof that the vessel is the only
-- thing they have in common -- there is no pipe path between them.
local energies = {}
for _, run in ipairs(runs) do
    local joules = t.pipe_energy(run[1], run[2])
    for other, seen in pairs(energies) do
        assert(math.abs(joules - seen) > 1.0,
            run[4] .. " and " .. other .. " are the same net: " .. joules)
    end
    energies[run[4]] = joules
end

-- ---------------------------------------------------------------
-- EVERY MOUTH SEES THE SAME RESERVOIR.
--
-- One pass, and the vessel and all four runs are one body of gas: the
-- pool is handed back out by volume, so what each run gets is its own
-- share and nothing to do with which mouth it hangs off. The sharp
-- reading is not the pressure -- four equal pressures could be four
-- coincidences -- it is that every holder sits at the same MOLAR
-- DENSITY, four different volumes notwithstanding.
-- ---------------------------------------------------------------
local start_moles = total(t.tank_gas(4, 4))
for _, run in ipairs(runs) do
    start_moles = start_moles + total(t.pipe_gas(run[1], run[2]))
end
t.run_ticks(10)

local density = total(t.tank_gas(4, 4)) / TANK_M3
local vessel_kpa = t.tank_pressure(4, 4)
local pooled = total(t.tank_gas(4, 4))
for _, run in ipairs(runs) do
    local x, y, volume, side = run[1], run[2], run[3], run[4]
    near(total(t.pipe_gas(x, y)) / volume, density, density * 1e-9,
        side .. " sits at the vessel's own density")
    near(t.pipe_pressure(x, y), vessel_kpa, vessel_kpa * 1e-9,
        side .. " is at the vessel's own pressure")
    pooled = pooled + total(t.pipe_gas(x, y))
end
near(pooled, start_moles, start_moles * 1e-12,
    "five holders, one pot: nothing was minted pooling them and nothing lost")

-- And the same MIXTURE, which a density cannot say. The runs opened the
-- shift on station air and the vessel on pure oxygen; one pass later
-- every holder carries the same admixture of the two, because there was
-- only ever one pot.
local function oxygen_fraction(mix)
    return mix.o2 / total(mix)
end
local blend = oxygen_fraction(t.tank_gas(4, 4))
assert(blend > 0.9, "overwhelmingly the vessel's oxygen, by weight: " .. blend)
for _, run in ipairs(runs) do
    near(oxygen_fraction(t.pipe_gas(run[1], run[2])), blend, 1e-9,
        run[4] .. " carries the vessel's mixture, not its own")
end

-- What differs is the lengths, and they differ in the right direction:
-- the four-length west run outweighs the single length east exactly in
-- proportion to the volume, and the shortest run holds the least.
near(
    total(t.pipe_gas(3, 4)) / total(t.pipe_gas(5, 4)),
    WEST_M3 / EAST_M3,
    1e-9,
    "west outweighs east exactly in proportion to volume"
)
assert(total(t.pipe_gas(5, 4)) < total(t.pipe_gas(4, 5)),
    "and the single length east holds the least of the four")

-- ---------------------------------------------------------------
-- CUT ONE, AND THE OTHER THREE DO NOT NOTICE.
--
-- A wrench on the length in the north mouth takes it out of the run and
-- ends that pipeline's claim on the vessel. The binding is DERIVED
-- every pass and never remembered, so nothing has to be told: the pass
-- after the cut pools the vessel with three nets instead of four.
--
-- Everything on the far side of the cut keeps what it was holding at
-- the same density it was holding it at -- the pull divides one net's
-- gas by volume, which is the same division the mouths were doing --
-- and from here it is on its own.
-- ---------------------------------------------------------------
t.click(p, 3, 3, t.target_at(3, 3, "wrench"))
t.run_ticks(3)
assert(t.hands(p).held == "wrench", "wrench in hand")

local severed_kpa = t.pipe_pressure(4, 2)
t.click_subfloor(p, 4, 3, "pipe", 4)
t.run_seconds(2)
assert(t.pipe(4, 3) == 0, "the length in the north mouth came up")
assert(t.pipe_pressure(4, 3) == nil, "and there is no net under that tile at all")
assert(t.count_items("pipe") > 0, "it is a length you could lay again")
near(t.pipe_pressure(4, 2), severed_kpa, severed_kpa * 1e-9,
    "the remnant kept the pressure it had -- the pull divides by volume too")

-- The other three are still the same body of gas as the vessel.
t.run_seconds(2)
local bound_kpa = t.tank_pressure(4, 4)
local bound_moles = total(t.tank_gas(4, 4))
for _, run in ipairs({ runs[2], runs[3], runs[4] }) do
    near(t.pipe_pressure(run[1], run[2]), bound_kpa, bound_kpa * 1e-9,
        run[4] .. " is still bolted to the vessel")
    bound_moles = bound_moles + total(t.pipe_gas(run[1], run[2]))
end

-- ---------------------------------------------------------------
-- WHICH IS PROVED BY DISTURBING THEM.
--
-- Two runs at one pressure can be two runs that were filled the same
-- way and are now strangers, so the standing reading is not enough:
-- warm ONE of the three that are still bound and see who answers. The
-- vessel and the other two bound runs come with it, because a parcel
-- carries its own energy through the mouths; the severed remnant, one
-- tile from the machine, sits exactly where it was left.
--
-- (`t.heat_pipe` is precondition scaffolding, as ever -- never an
-- assertion, and gone the day a burn chamber exists.)
-- ---------------------------------------------------------------
local cold_k = t.pipe_temperature(4, 2)
local rest_k = t.pipe_temperature(5, 4)
local severed_moles = total(t.pipe_gas(4, 2))
t.heat_pipe(5, 4, 2000000.0)
t.run_seconds(5)

local warmed_k = t.pipe_temperature(5, 4)
assert(warmed_k > rest_k + 3.0, "the east run took the heat: " .. warmed_k .. " K")
near(t.pipe_temperature(4, 5), warmed_k, 1e-6, "south came with it, through the vessel")
near(t.pipe_temperature(3, 4), warmed_k, 1e-6, "and west, which is two mouths away")
near(t.pipe_temperature(4, 2), cold_k, 1e-9,
    "while the severed run stayed exactly as cold as it was left")
near(total(t.pipe_gas(4, 2)), severed_moles, severed_moles * 1e-12,
    "with its mole book untouched -- nothing crosses a mouth that is not there")

-- The three that answered are still one pressure with the vessel, and
-- it is a HIGHER one than before: same moles, same volumes, more heat.
local hot_kpa = t.tank_pressure(4, 4)
assert(hot_kpa > bound_kpa, "the bound family rose together: " .. hot_kpa .. " kPa")
for _, run in ipairs({ runs[2], runs[3], runs[4] }) do
    near(t.pipe_pressure(run[1], run[2]), hot_kpa, hot_kpa * 1e-9,
        run[4] .. " rose with the vessel")
end
assert(math.abs(t.pipe_pressure(4, 2) - hot_kpa) > 100.0,
    "and the severed run did not: " .. t.pipe_pressure(4, 2) .. " vs " .. hot_kpa)

-- And the pool the three still share is the pool they shared before the
-- heat, to the mole: what went through the mouths was joules.
near(
    total(t.tank_gas(4, 4)) + total(t.pipe_gas(4, 5))
        + total(t.pipe_gas(5, 4)) + total(t.pipe_gas(3, 4)),
    bound_moles,
    bound_moles * 1e-12,
    "the bound holders carry exactly what they were left with"
)
