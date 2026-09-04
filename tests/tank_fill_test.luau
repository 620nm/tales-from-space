-- What a map puts IN a stationary tank, to the mole.
--
-- `(x, y, "stationary_tank", "anchored", ("o2", 23000.0))` is a station
-- saying what is in THIS vessel, and it is the whole of tg's twenty
-- /tank/<gas> subtypes (tank.dm:477-555) said as a fact about a map
-- instead of as twenty prototypes. stationary_tank_test.luau settles
-- that the mechanism works and tank_annex_test.luau that seven of them
-- keep seven different gases; neither weighs the fill.
--
-- This file weighs it. A pressure is not an amount of gas -- a
-- temperature has to come with it -- so tg fills at `T20C` and solves
-- the ideal gas law for moles (`fill_to_pressure`, tank.dm:153-159):
--
--     moles = pressure_limit * volume / (R_IDEAL_GAS_EQUATION * T)
--
-- Every assertion below is that arithmetic, done here in the spec at
-- the vessel's own 2500 L and checked against what the world actually
-- holds. A fill that landed the right PRESSURE with the wrong moles
-- would read perfectly on every gauge and quietly hand the station a
-- different amount of air.
--
-- Not assertable from here, and deliberately: a fill naming a gas that
-- does not exist, or a fill on a machine that holds none, is refused
-- at BOOT (`MapFile::fill_errors`, called from main.rs's preflight) and
-- the spec runner builds its Sim past that gate. Those refusals are
-- specced in Rust beside the format, in lunatic-core's map.rs.

local R = 8.314
local T20C = 293.15
-- tg's `volume = 2500` (tank.dm:37), in m³ as the matter world counts.
local TANK_M3 = 2.5
-- tg's `max_pressure = 46000` (tank.dm:39): the number on the vessel's
-- holographic sticker, and the denominator of its gauge.
local RATED_KPA = 46000.0

-- The ideal gas law at the vessel's own size and filling temperature --
-- the engine's `fill_vessel` line, written out again on this side of
-- the boundary so the two have to agree rather than share a helper.
local function filled_moles(kpa)
    return kpa * 1000.0 * TANK_M3 / (R * T20C)
end

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function row(panel, label)
    for _, r in ipairs(panel.readouts) do
        if r.label == label then
            return r
        end
    end
    return nil
end

local function number_in(text)
    return tonumber(string.match(text, "[%d%.]+"))
end

-- The contents block: what the vessel is HOLDING, by state, in the
-- units each state is read in (docs/tgui/matter-block.md).
local function block(panel, section)
    for _, b in ipairs(panel.matter or {}) do
        if b.section == section then
            return b
        end
    end
    return nil
end

local function state(b, phase)
    for _, st in ipairs(b and b.states or {}) do
        if st.phase == phase then
            return st
        end
    end
    return nil
end

local function named(st, name)
    for _, r in ipairs(st and st.rows or {}) do
        if r.name == name then
            return r
        end
    end
    return nil
end

-- The same, across every state: what is in the vessel regardless of
-- which of the three it is standing in.
local function named_any(b, name)
    for _, st in ipairs(b and b.states or {}) do
        local found = named(st, name)
        if found then
            return found
        end
    end
    return nil
end

local function total_of(b, key)
    local sum = 0.0
    for _, st in ipairs(b and b.states or {}) do
        for _, r in ipairs(st.rows or {}) do
            if r.key == key then
                sum = sum + r.moles
            end
        end
    end
    return sum
end

-- ---------------------------------------------------------------
-- Five vessels, five authored fills, and nothing plumbed into any of
-- them: a tank shares with every net its mouths reach, so a store with
-- no pipe in it is the only place a fill can be weighed without the
-- plumbing having had an opinion first.
--
-- Two gases at two pressures each, because one gas at one pressure
-- cannot tell the ideal gas law from a lookup table -- and a fifth
-- vessel past its own sticker, which is a thing a map is allowed to
-- say (tg warns and carries on: `return_pressure() > max_pressure`,
-- tank.dm:165) and which the gauge has to survive.
-- ---------------------------------------------------------------
t.world([==[(
    name: "filling floor",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "############",
        "#..........#",
        "#..........#",
        "############",
    ],
    spawns: [(2, 2)],
    structures: [
        (2, 1, "stationary_tank", "anchored", ("o2", 23000.0)),
        (4, 1, "stationary_tank", "anchored", ("o2", 4000.0)),
        (6, 1, "stationary_tank", "anchored", ("n2", 34500.0)),
        (8, 1, "stationary_tank", "anchored", ("n2", 9200.0)),
        (10, 1, "stationary_tank", "anchored", ("co2", 60000.0)),
    ],
)]==], 7)

local p = t.join()
t.tick()

local authored = {
    { 2, 1, "o2", 23000.0 },
    { 4, 1, "o2", 4000.0 },
    { 6, 1, "n2", 34500.0 },
    { 8, 1, "n2", 9200.0 },
    { 10, 1, "co2", 60000.0 },
}

for _, entry in ipairs(authored) do
    local x, y, gas, kpa = entry[1], entry[2], entry[3], entry[4]
    local where = gas .. " at " .. kpa .. " kPa"
    local held = t.tank_gas(x, y)
    assert(held, where .. ": a vessel stands there")

    -- ONE key, and it is the one the map named. A fill deposits a
    -- single substance; anything else in the mixture would be gas the
    -- station never asked for.
    local keys = 0
    for key, moles in pairs(held) do
        keys = keys + 1
        assert(key == gas, where .. " holds " .. key .. " (" .. moles .. " mol)")
    end
    assert(keys == 1, where .. " holds ONE gas, not " .. keys)

    -- And the amount is the arithmetic, not an approximation of it.
    -- Both sides evaluate the same expression on the same doubles, so
    -- a part in a trillion is a generous allowance.
    local want = filled_moles(kpa)
    near(held[gas], want, want * 1e-12, where .. " is the ideal gas law in moles")
    near(t.tank_pressure(x, y), kpa, kpa * 1e-12, where .. " reads back its own pressure")
end

-- The two gases are not the same gas at a different number: at these
-- pressures the 34 500 kPa nitrogen vessel outweighs the 23 000 kPa
-- oxygen one in moles by exactly the ratio of their pressures, which is
-- what "a mole is a mole whatever the gas" means and is the reason a
-- fill can be authored in kPa at all.
near(
    t.tank_gas(6, 1).n2 / t.tank_gas(2, 1).o2,
    34500.0 / 23000.0,
    1e-12,
    "moles scale with the authored pressure, not with the substance"
)

-- ---------------------------------------------------------------
-- The window, which is the only instrument on the machine.
--
-- tg has no interface for a tank at all -- it has a pane of glass with
-- the gas swirling behind it and a sticker giving the rating -- so this
-- panel IS those two readings, and it has to be exact about both.
-- ---------------------------------------------------------------
t.click(p, 2, 1, t.target_at(2, 1))
t.tick()
local half = t.ui(p)
assert(half and half.document == "modules" and half.presentation == "modules",
    "the vessel opens its contents document")

-- The gauge is a PERCENTAGE of the sticker, not of anything else. Half
-- the rating, on the nose: tg's own `starting_pressure_percent = 0.5`.
near(
    half.gauge,
    t.tank_pressure(2, 1) / RATED_KPA * 100.0,
    1e-9,
    "the gauge is the pressure against the rating"
)
near(half.gauge, 50.0, 1e-9, "which for this vessel is half the sticker")

-- One row per substance present, NAMED -- the swirling colour, written
-- down -- inside the state it is actually in.
local half_gas = state(block(half, "contents"), "gas")
assert(half_gas, "a charged vessel holds a gas")
local gas_row = named(half_gas, "oxygen")
assert(gas_row, "a row for the substance that is in there, by its own name")
near(gas_row.moles, t.tank_gas(2, 1).o2, 1e-6,
    "carrying the moles the vessel holds")
assert(named(half_gas, "nitrogen") == nil, "and no row for one that is not")

near(half_gas.measure, 23000.0, 0.5, "the state's own reading is the pressure")
near(block(half, "contents").temperature_k, T20C, 1e-6,
    "and the temperature it was filled at -- a pressure alone is not an amount of gas")
near(block(half, "contents").volume_l, 2500.0, 1e-9, "the size of the thing")
assert(row(half, "rating").value == "46000 kPa",
    "and its sticker, which the block cannot say: " .. row(half, "rating").value)
assert(#half.toggles == 0 and #half.setpoints == 0, "no controls, because there are none")

-- ---------------------------------------------------------------
-- Past the sticker. A map may author more than the vessel is rated for
-- -- tg does not clamp `fill_to_pressure` either -- and the panel has
-- to stay a readable instrument when it happens: the gauge pins at full
-- rather than running off its own scale, and the pressure row goes to
-- the warning tone tg prints in `examine`.
-- ---------------------------------------------------------------
for _ = 1, 8 do
    t.move(p, "east")
    t.run_ticks(5)
end
t.click(p, 10, 1, t.target_at(10, 1))
t.tick()
local over = t.ui(p)
assert(over and over.document == "modules" and over.presentation == "modules",
    "the over-filled vessel opens its document too")
assert(t.tank_pressure(10, 1) > RATED_KPA * 1.3, "it is a third past its rating")
near(over.gauge, 100.0, 1e-9, "and the gauge pins at full: " .. over.gauge)
assert(row(over, "rating").tone == "off",
    "with the sticker flagged: " .. tostring(row(over, "rating").tone))
local over_block = block(over, "contents")
local co2_row = named_any(over_block, "carbon dioxide")
assert(co2_row, "the row names the substance as a reader would say it, not by its key")
assert(co2_row.key == "co2", "the key travels beside the name, never instead of it")
assert(named_any(over_block, "co2") == nil, "the key is not a label")
-- Summed across the states: six hundred atmospheres is past carbon
-- dioxide's own line, so some of the fill is lying in the bottom of it
-- and the BOOK is what the fill authored.
near(total_of(over_block, "co2"), filled_moles(60000.0), 1e-6,
    "and it is the fill, weighed")

-- ---------------------------------------------------------------
-- Every shape a placement can take, in one world, because the shapes
-- are told apart by what they LOOK like rather than by position: a
-- trailing string is an assembly state, a trailing pair is a fill, and
-- either may be missing (`PlacedTail`, lunatic-core map.rs). A vessel
-- filled but left in its opening state has to read as itself.
-- ---------------------------------------------------------------
t.world([==[(
    name: "four shapes",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#...#",
        "#####",
    ],
    spawns: [(2, 2)],
    structures: [
        (1, 1, "stationary_tank"),
        (3, 1, "stationary_tank", "anchored"),
        (1, 3, "stationary_tank", ("n2", 5000.0)),
        (3, 3, "stationary_tank", "anchored", ("o2", 23000.0)),
    ],
)]==], 7)

local q = t.join()
t.tick()

local shapes = {
    { 1, 1, "(x, y, id)", nil },
    { 3, 1, "(x, y, id, state)", nil },
    { 1, 3, "(x, y, id, fill)", { "n2", 5000.0 } },
    { 3, 3, "(x, y, id, state, fill)", { "o2", 23000.0 } },
}

for _, shape in ipairs(shapes) do
    local x, y, form, fill = shape[1], shape[2], shape[3], shape[4]
    local standing = t.structure_at(x, y)
    assert(standing and standing.id == "stationary_tank",
        form .. " stands a vessel up: " .. tostring(standing and standing.id))
    -- A sealed vessel has exactly one assembly state, so every form
    -- lands in it -- named or not, the picture and the plumbing agree.
    assert(standing.state == "anchored", form .. " is anchored: " .. tostring(standing.state))

    local held = t.tank_gas(x, y)
    if fill then
        local gas, kpa = fill[1], fill[2]
        local want = filled_moles(kpa)
        near(held[gas], want, want * 1e-12, form .. " carries its fill")
        near(t.tank_pressure(x, y), kpa, kpa * 1e-12, form .. " at the authored pressure")
    else
        local keys = 0
        for _ in pairs(held) do
            keys = keys + 1
        end
        assert(keys == 0, form .. " brings no gas of its own, and brought " .. keys)
        assert(t.tank_pressure(x, y) == 0.0,
            form .. " reads empty: " .. t.tank_pressure(x, y))
    end
end

-- An empty vessel's window SAYS so. The alternative is eleven rows
-- reading 0.0 mol, or worse a row for a gas nobody put in -- and a
-- station engineer reading a phantom row off a tank they are about to
-- cut open is exactly the failure this panel exists to prevent.
t.click(q, 3, 1, t.target_at(3, 1))
t.tick()
local empty = t.ui(q)
assert(empty and empty.document == "modules" and empty.presentation == "modules",
    "an empty vessel opens a document like any other")
near(empty.gauge, 0.0, 1e-12, "the gauge is at rest: " .. empty.gauge)
local nothing = block(empty, "contents")
assert(nothing, "an empty vessel still has a block")
assert(nothing.states == nil or #nothing.states == 0,
    "and it says empty ONCE, with no state at all, phantom or otherwise")
assert(state(nothing, "gas") == nil, "nothing to read")
-- Nothing in it has no temperature, so the mixture answers with the
-- floor the matter world clamps to (TCMB, invariant I2) rather than
-- with a room-temperature fiction. An empty vessel is cold.
near(nothing.temperature_k, 2.7, 0.05,
    "and it reads the cosmic background rather than a comfortable lie")
near(nothing.volume_l, 2500.0, 1e-9, "while it is the size it always was")
near(nothing.headspace_l, 2500.0, 1e-9, "all of it headspace")
assert(row(empty, "rating").value == "46000 kPa",
    "and the sticker says what it always said")
