-- The shape of the approach, worked out on paper and then checked
-- against the machine pass by pass.
--
-- thermomachine_test.luau asserts that the approach is monotone and
-- that it arrests on the setpoint. Both of those would still hold if
-- the unit closed a tenth of the gap per pass, or half, or all of it,
-- and WHICH it does is the difference between a freezer loop and a
-- magic wand. tg's conduction is a closed form:
--
--   Q      = CALCULATE_CONDUCTION_ENERGY(target - T, C_port, C_bath)
--          = (target - T) * (C_port * C_bath / (C_port + C_bath))
--   T_next = T + Q / C_port
--          = target - (target - T) * C_port / (C_port + C_bath)
--
-- so every pass closes the SAME FRACTION of whatever gap is left, and
-- the whole curve is one number: r = C_port / (C_port + C_bath), with
-- C_bath the 5000 J/K the machine's two matter bins are worth
-- (thermomachine.dm:90, and `heat_j_per_k` in the unit's own file).
-- This file computes r off the world's own books and predicts every
-- pass from it.
--
-- THE BATH IS VIRTUAL, and this is where that costs something. Nothing
-- on the other side of the exchanger cools when the gas warms: the
-- joules are minted into the port and paid for out of the equipment
-- channel, which is why no spec may weigh `pipe_energy` across this
-- machine the way thermal_devices_test.luau weighs it across a
-- temperature pump. What CAN be weighed -- and is, below -- is that the
-- gas book moved by exactly Q and not by one joule more.
--
-- The bench: a 2500 L tank charges the line through a hand valve, and
-- then the valve is SHUT, leaving the mouth holding a run of one
-- authored gas at three atmospheres with no reservoir behind it to
-- buffer the approach. Changing one word of the map changes the gas and
-- nothing else, which is what the second half of this file needs.

local T20C = 293.15
local C_BATH = 5000.0
local TARGET = 150.0

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function pass()
    t.run_ticks(10)
end

local function moles(x, y)
    local n = 0.0
    for _, amount in pairs(t.pipe_gas(x, y) or {}) do
        n = n + amount
    end
    return n
end

local BENCH = [==[(
    name: "charging bench",
    legend: {
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "##########",
        "#........#",
        "#..a....g#",
        "##########",
    ],
    spawns: [(3, 2)],
    pipes: [(2, 1, 4), (4, 1, 4), (5, 1, 4)],
    structures: [
        (1, 1, "stationary_tank", "anchored", ("%s", 400.0)),
        (3, 1, "manual_valve"),
        (6, 1, "thermomachine"),
    ],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3), (7, 1, 3), (8, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3), (7, 2, 3), (8, 2, 3),
    ],
)]==]

local MOUTH_X, MOUTH_Y = 5, 1

-- Charge the line off the tank, shut the valve behind it, and stand the
-- engineer at the unit with its panel open. Everything after this is
-- one body of gas and one machine.
local function bench(gas)
    t.world(BENCH:format(gas), 7)
    local p = t.join()
    t.tick()

    t.click(p, 3, 1, t.target_at(3, 1, "manual_valve"))
    t.run_seconds(4)
    assert(t.structure_at(3, 1).state == "open", "the hand valve is open")
    t.click(p, 3, 1, t.target_at(3, 1, "manual_valve"))
    t.run_seconds(3)
    assert(t.structure_at(3, 1).state == "shut", "and shut again behind the charge")
    assert(
        t.pipe_pressure(MOUTH_X, MOUTH_Y) > 300.0,
        "the run is charged: " .. t.pipe_pressure(MOUTH_X, MOUTH_Y) .. " kPa"
    )
    near(t.pipe_temperature(MOUTH_X, MOUTH_Y), T20C, 0.01, "and still at room temperature")

    for _ = 1, 3 do
        t.move(p, "east")
        t.run_ticks(5)
    end
    t.click(p, 6, 1, t.target_at(6, 1, "thermomachine"))
    t.tick()
    assert(t.ui(p), "the unit answers an empty hand with its panel")
    return p
end

-- The port's heat capacity, off the world's own readings the way
-- pipe_blend_test.luau takes it: E = C * T. Nothing below is written
-- down from the gas roster, so a station that recharges its lines with
-- something else does not silently invalidate the arithmetic.
local function capacity()
    return t.pipe_energy(MOUTH_X, MOUTH_Y) / t.pipe_temperature(MOUTH_X, MOUTH_Y)
end

-- ---------------------------------------------------------------
-- PASS BY PASS, TO SIX DECIMAL PLACES.
--
-- A nitrogen line driven from room temperature down to 150 K. r is
-- taken off the books BEFORE the switch is thrown and never adjusted
-- afterwards: every temperature below is r to the power of the pass.
-- ---------------------------------------------------------------
local p = bench("n2")

local n2_moles = moles(MOUTH_X, MOUTH_Y)
local n2_c = capacity()
-- tg's 20 J/K per mole for nitrogen (gas_types.dm), read off the world.
near(n2_c / n2_moles, 20.0, 1e-9, "a nitrogen line carries twenty joules per mole per kelvin")
local r = n2_c / (n2_c + C_BATH)
assert(r > 0.2 and r < 0.25, "which puts this run's pass fraction near a fifth: " .. r)

t.ui_act(p, "set", '{"field":"temperature","value":150}')
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.structure_at(6, 1).state == "running", "the unit is running")

local start_k = t.pipe_temperature(MOUTH_X, MOUTH_Y)
local previous_k = start_k
local previous_j = t.pipe_energy(MOUTH_X, MOUTH_Y)
for n = 1, 6 do
    -- What the formula says this pass will do, from where the gas is:
    -- the energy first, because Q is the quantity the machine computes
    -- and the temperature is only Q divided out.
    local q = (TARGET - previous_k) * (n2_c * (C_BATH / (n2_c + C_BATH)))
    pass()
    local now_k = t.pipe_temperature(MOUTH_X, MOUTH_Y)
    local now_j = t.pipe_energy(MOUTH_X, MOUTH_Y)

    near(now_k, TARGET + (start_k - TARGET) * r ^ n, 1e-6, "pass " .. n .. " lands where r^" .. n .. " says")
    -- THE GAS BOOK MOVED BY EXACTLY Q. The joules came out of nowhere
    -- (that is the mains' problem), but HOW MANY is not a free
    -- parameter.
    near(now_j - previous_j, q, math.abs(q) * 1e-9, "and by exactly the joules the formula asked for")
    assert(q < 0.0, "which on a cooling pass is joules leaving the gas: " .. q)
    -- ...and the capacity never moved, which is the same statement as
    -- "not one mole was transferred" -- a machine venting a little gas
    -- each pass could hit the same temperatures.
    near(capacity(), n2_c, n2_c * 1e-9, "the run's heat capacity is untouched")

    previous_k, previous_j = now_k, now_j
end
near(moles(MOUTH_X, MOUTH_Y), n2_moles, n2_moles * 1e-9, "and the mole book never moved at all")

-- The same six numbers said the other way round: the gap left after
-- each pass is r times the gap before it, forever, which is the whole
-- content of "asymptotic rather than a snap".
local gap = t.pipe_temperature(MOUTH_X, MOUTH_Y) - TARGET
for n = 1, 4 do
    pass()
    local left = t.pipe_temperature(MOUTH_X, MOUTH_Y) - TARGET
    near(left, gap * r, math.abs(gap * r) * 1e-6, "gap " .. n .. " closes by the same fraction as the last")
    gap = left
end

t.run_seconds(30)
near(t.pipe_temperature(MOUTH_X, MOUTH_Y), TARGET, 1e-6, "and the line arrests on the setpoint")
local n2_settled_j = t.pipe_energy(MOUTH_X, MOUTH_Y)
t.run_seconds(20)
near(t.pipe_energy(MOUTH_X, MOUTH_Y), n2_settled_j, 1e-6, "with the book flat once it is there")

-- ---------------------------------------------------------------
-- THE SAME MACHINE IS SLOWER THROUGH A HEAVIER GAS.
--
-- One word of the map changes: the tank is filled with nitrous oxide
-- instead of nitrogen. tg gives it 40 J/K per mole against nitrogen's
-- 20 (gas_types.dm), and the ideal gas law charges the line to the same
-- PRESSURE with the same number of MOLES either way -- so this is the
-- one-variable experiment: twice the heat capacity behind the same
-- mouth, the same 5000 J/K thermostat in front of it. r = C/(C + 5000)
-- rises with C, so the heavier line closes less of its gap per pass --
-- and it is not slower to a different destination, which is the second
-- half of the assertion.
-- ---------------------------------------------------------------
local heavy = bench("n2o")

local n2o_moles = moles(MOUTH_X, MOUTH_Y)
local n2o_c = capacity()
near(n2o_moles, n2_moles, n2_moles * 1e-9, "the same pressure in the same pipes is the same moles")
assert(
    n2o_c > n2_c * 1.8,
    "and this lot carries nearly twice the heat: " .. n2_c .. " vs " .. n2o_c .. " J/K"
)

t.ui_act(heavy, "set", '{"field":"temperature","value":150}')
t.ui_act(heavy, "toggle", '{"field":"power"}')
t.run_ticks(2)
for _ = 1, 3 do
    pass()
end
local heavy_gap = t.pipe_temperature(MOUTH_X, MOUTH_Y) - TARGET
local light_gap = (T20C - TARGET) * r ^ 3
assert(
    heavy_gap > light_gap * 2.5,
    "three passes in, the heavy line is still miles off what the light one had closed: "
        .. heavy_gap .. " K left against " .. light_gap .. " K"
)
near(
    t.pipe_temperature(MOUTH_X, MOUTH_Y),
    TARGET + (T20C - TARGET) * (n2o_c / (n2o_c + C_BATH)) ^ 3,
    1e-6,
    "and it is exactly where ITS own r puts it -- same formula, heavier gas"
)

t.run_seconds(60)
near(t.pipe_temperature(MOUTH_X, MOUTH_Y), TARGET, 1e-6, "it gets there in the end, on the same setpoint")

-- ---------------------------------------------------------------
-- AND NOTHING AT ALL, FOREVER, INTO AN EMPTY LINE.
--
-- tg opens the pass with `if(!port.total_moles()) return`
-- (thermomachine.dm:179): a unit plumbed into a line with nothing in it
-- is not one that heats a vacuum slowly, it is one that does nothing.
-- The distinction matters because the arithmetic above divides by
-- C_port, and C_port of an empty pipe is zero -- the one input that
-- turns this closed form into a NaN and the port into a permanently
-- poisoned mixture.
--
-- An empty run is a run somebody laid this shift (fittings_test.luau):
-- the mapped length comes up on a wrench and goes straight back down.
-- ---------------------------------------------------------------
t.world([==[(
    name: "dry line",
    legend: {
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "########",
        "#......#",
        "#..a..g#",
        "########",
    ],
    spawns: [(3, 2)],
    items: [(3, 2, "wrench")],
    pipes: [(2, 1, 4)],
    structures: [(3, 1, "thermomachine")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
    ],
)]==], 7)

local d = t.join()
t.tick()
t.click(d, 3, 2, t.target_at(3, 2, "wrench"))
t.run_ticks(2)
t.click_subfloor(d, 2, 1, "pipe", 4)
t.run_seconds(1.5)
assert(t.pipe(2, 1) == 0, "the mapped length came up")
t.drop(d)
t.run_ticks(2)
t.click(d, 2, 1, t.target_at(2, 1, "pipe"))
t.run_ticks(2)
assert(t.hands(d).held == "pipe", "and it is a length you can lay again")
t.click(d, 2, 1)
t.run_seconds(1.5)
t.drop(d)
t.run_ticks(2)
assert(t.pipe(2, 1) == 4, "so it goes straight back down")
near(t.pipe_pressure(2, 1), 0.0, 1e-9, "empty, because nobody filled it")
near(t.pipe_energy(2, 1), 0.0, 1e-9, "with no joules in it either")

t.click(d, 3, 1, t.target_at(3, 1, "thermomachine"))
t.tick()
-- The thermometer is this window's first row (sim/ui/settings/thermo.rs).
local mouth = t.ui(d).readouts[1].value
assert(mouth ~= "no pipe", "the unit's mouth found the new length: " .. mouth)
t.ui_act(d, "set", '{"field":"temperature","value":500}')
t.ui_act(d, "toggle", '{"field":"power"}')
t.run_seconds(60)

assert(t.structure_at(3, 1).state == "running", "it is switched on and fed -- there is simply nothing to condition")
near(t.pipe_energy(2, 1), 0.0, 1e-9, "and a minute later the line still holds no joules")
near(moles(2, 1), 0.0, 1e-9, "and no moles")
local dry_k = t.pipe_temperature(2, 1)
assert(dry_k == dry_k, "the empty line's temperature is a number, not a NaN: " .. dry_k)
near(dry_k, 2.7, 1e-9, "and it is TCMB, where an empty mixture sits")
