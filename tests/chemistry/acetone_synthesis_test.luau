local ui_controls = require("@helpers/ui_controls")

-- Acetone is the balanced oxidation bench: pseudo-C8H16 naphtha and two
-- oxygen molecules make two acetone, two carbon and two water. The bottle
-- must be sealed for the oxygen charge, the salt catalyst must be present,
-- and the whole batch still comes through the dispenser and its dock.
-- The source recipe is tg's `/datum/chemical_reaction/acetone`, 3 acetone
-- from oil, welding fuel and oxygen (recipes/others.dm:477-481).

local BATCH = 0.025

local function near(a: number, b: number, slack: number, what: string)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function amount(handle: SpecObservedTarget, key: string): number
    local contents = assert(t.contents(handle))
    return contents[key] or 0.0
end

local function gas(handle: SpecObservedTarget, key: string): number
    local row = assert(t.vessel(handle)).contents[key]
    return if row == nil then 0.0 else (row.gas or 0.0)
end

t.world(
    [==[(
    name: "acetone synthesis bench",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Apc)),
        'g': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
    },
    rows: [
        "#####",
        "#o..#",
        "#...#",
        "#ag.#",
        "#####",
    ],
    blends: {
        "oxygen_supply": (rows: [("o2", 2400.0)], temperature_k: 300.0, amount: per_tile),
    },
    structures: [
        (2, 1, "player_spawn"),
        (2, 2, "canister", { "blend": "oxygen_supply" }),
    ],
    items: [(1, 2, "bottle"), (3, 2, "bottle")],
    machines: [(3, 1, "chem_dispenser")],
    networks: [
        (x: 1, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
    ],
)]==],
    0,
    "free_build"
)

local p = t.join()
t.tick()

local dispenser = assert(t.target_at(p, 3, 1), "the dispenser is on the bench")
local canister = assert(t.target_at(p, 2, 2, "canister"), "the oxygen canister is present")
local oxygen_missing = assert(t.target_at(p, 1, 2, "bottle"), "the first bottle is present")
local catalyst_missing = assert(t.target_at(p, 3, 2, "bottle"), "the second bottle is present")

local function dock(handle: SpecObservedTarget)
    t.click(p, 3, 1, assert(t.target_at(p, 3, 1, dispenser)))
    t.tick()
    assert(t.hands(p).held == nil, "the bottle docks")
    t.click(p, 3, 1, assert(t.target_at(p, 3, 1, dispenser)))
    t.tick()
end

local function dispense(key: string)
    ui_controls.set(p, "amount", BATCH)
    t.run_ticks(2)
    ui_controls.toggle(p, "dispense", key)
    t.run_ticks(4)
end

local function eject_and_drop()
    ui_controls.toggle(p, "eject")
    t.run_ticks(2)
    assert(t.hands(p).held == "bottle", "the bottle comes back out")
    t.drop(p)
    t.tick()
end

-- A sealed bottle with naphtha and the catalyst still refuses without its
-- oxygen charge. This also establishes the exact one-batch feed amounts.
t.click(p, 1, 2, assert(t.target_at(p, 1, 2, oxygen_missing)))
t.tick()
dock(oxygen_missing)
dispense("naphtha")
dispense("salt")
eject_and_drop()
t.run_seconds(30)
near(amount(oxygen_missing, "naphtha"), BATCH, 1e-6, "missing oxygen leaves naphtha alone")
near(amount(oxygen_missing, "salt"), BATCH, 1e-6, "the catalyst remains available")
near(amount(oxygen_missing, "acetone"), 0.0, 1e-9, "missing oxygen makes no acetone")
near(amount(oxygen_missing, "carbon"), 0.0, 1e-9, "missing oxygen makes no carbon")
near(amount(oxygen_missing, "water"), 0.0, 1e-9, "missing oxygen makes no water")

-- Charge that same sealed bottle from the seeded canister. The source is
-- deliberately much larger than one batch, so naphtha is the clamp.
t.click(p, 2, 1, assert(t.target_at(p, 2, 1, oxygen_missing)))
t.tick()
local source_o2 = gas(canister, "o2")
t.click(p, 2, 2, assert(t.target_at(p, 2, 2, canister)))
t.run_ticks(4)
local initial_o2 = source_o2 - gas(canister, "o2")
assert(initial_o2 > 2.0 * BATCH, "the canister supplies two oxygen molecules per batch")
dock(oxygen_missing)
eject_and_drop()
t.run_seconds(300)

near(amount(oxygen_missing, "salt"), 0.025, 1e-6, "oxidation catalyst is retained")
local spent_naphtha = BATCH - amount(oxygen_missing, "naphtha")
local spent_o2 = initial_o2 - gas(oxygen_missing, "o2")
local acetone = amount(oxygen_missing, "acetone")
local carbon = amount(oxygen_missing, "carbon")
local water = amount(oxygen_missing, "water")
assert(spent_naphtha > 0.02, "one batch consumed the naphtha: " .. spent_naphtha)
near(spent_o2, 2.0 * spent_naphtha, 1e-5, "two oxygen molecules per naphtha")
near(acetone, 2.0 * spent_naphtha, 1e-5, "two acetone per naphtha")
near(carbon, 2.0 * spent_naphtha, 1e-5, "two carbon per naphtha")
near(water, 2.0 * spent_naphtha, 1e-5, "two water per naphtha")
assert(acetone > 0.04, "the product is usable acetone: " .. acetone)

-- Check the pseudoformula directly rather than only checking product
-- coefficients: C8H16 + 2 O2 -> 2 C3H6O + 2 C + 2 H2O.
near(8.0 * spent_naphtha, 3.0 * acetone + carbon, 1e-5, "carbon atoms balance")
near(16.0 * spent_naphtha, 6.0 * acetone + 2.0 * water, 1e-5, "hydrogen atoms balance")
near(2.0 * spent_o2, acetone + water, 1e-5, "oxygen atoms balance")

-- Rounded molar masses preserve the same batch mass: 112 + 2*32 ~=
-- 2*58 + 2*12 + 2*18 grams per extent.
local input_mass = 112.0 * spent_naphtha + 32.0 * spent_o2
local output_mass = 58.0 * acetone + 12.0 * carbon + 18.0 * water
near(output_mass, input_mass, 0.01, "rounded atom masses balance")

-- Oxygen alone is insufficient. A fresh sealed bottle with the same
-- canister charge and naphtha, but no salt catalyst, remains unchanged.
t.click(p, 3, 2, assert(t.target_at(p, 3, 2, catalyst_missing)))
t.tick()
t.click(p, 2, 2, assert(t.target_at(p, 2, 2, canister)))
t.run_ticks(4)
local catalyst_missing_o2 = gas(catalyst_missing, "o2")
assert(catalyst_missing_o2 > 2.0 * BATCH, "the second bottle also has oxygen")
dock(catalyst_missing)
dispense("naphtha")
eject_and_drop()
t.run_seconds(60)
near(amount(catalyst_missing, "naphtha"), BATCH, 1e-6, "missing catalyst leaves naphtha alone")
near(amount(catalyst_missing, "acetone"), 0.0, 1e-9, "missing catalyst makes no acetone")
near(amount(catalyst_missing, "carbon"), 0.0, 1e-9, "missing catalyst makes no carbon")
near(amount(catalyst_missing, "water"), 0.0, 1e-9, "missing catalyst makes no water")
