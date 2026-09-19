local ui_controls = require("@helpers/ui_controls")

-- Naphtha is the first petrochemical a crew can make from atmospherics:
-- 8 CO2 + 24 H2 -> naphtha + 16 water. The 2 L lab bottle is the
-- pressure vessel for a useful resin and toner batch; a 50 mL bottle is
-- enough to demonstrate the reaction but not enough to stock downstream
-- chemistry for a shift. Each gas transfer is a player-sized stroke, so
-- the lab bottle takes three ordinary charge clicks.

local function amount(handle: SpecObservedTarget, key: string): number
    local contents = assert(t.vessel(handle)).contents[key]
    if contents == nil then
        return 0.0
    end
    return (contents.gas or 0.0) + (contents.liquid or 0.0) + (contents.solid or 0.0)
end

local function gas(handle: SpecObservedTarget, key: string): number
    local contents = assert(t.vessel(handle)).contents[key]
    return if contents == nil then 0.0 else (contents.gas or 0.0)
end

local function liquid(handle: SpecObservedTarget, key: string): number
    local contents = assert(t.vessel(handle)).contents[key]
    return if contents == nil then 0.0 else (contents.liquid or 0.0)
end

local function near(a: number, b: number, slack: number, what: string)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

t.world(
    [==[(
    name: "petrochemical bench",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'g': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
    },
    rows: [
        "#########",
        "#o.a...g#",
        "#.......#",
        "#.......#",
        "#.......#",
        "#########",
    ],
    blends: {
        "syngas_supply": (rows: [("co2", 600.0), ("hydrogen", 1800.0)], temperature_k: 300.0, amount: per_tile),
        "carbon_dioxide_supply": (rows: [("co2", 600.0)], temperature_k: 300.0, amount: per_tile),
    },
    items: [
        (4, 2, "lab_flask"),
        (4, 4, "lab_flask"),
    ],
    machines: [
        (5, 3, "chem_dispenser"),
        (6, 2, "chem_heater"),
    ],
    structures: [
        (4, 3, "player_spawn"),
        (3, 3, "canister", { "blend": "syngas_supply" }),
        (3, 4, "canister", { "blend": "carbon_dioxide_supply" }),
        (3, 1, "apc"),
    ],
    networks: [
        (x: 1, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 7, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 7, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 7, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 7, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
    ],
)]==],
    0,
    "free_build"
)

local p = t.join()
t.tick()

local dispenser = assert(t.target_at(p, 5, 3), "the dispenser is on the bench")
local heater = assert(t.target_at(p, 6, 2), "the heater is on the bench")
local source = assert(t.target_at(p, 3, 3, "canister"), "the syngas supply is present")
local missing_hydrogen =
    assert(t.target_at(p, 3, 4, "canister"), "the carbon dioxide supply is present")
local lab = assert(t.target_at(p, 4, 2, "lab_flask"), "the lab flask is present")
local deficient = assert(t.target_at(p, 4, 4, "lab_flask"), "the second lab flask is present")

local function walk(dir: "east" | "west" | "north" | "south")
    t.move(p, dir)
    t.run_ticks(6)
end

local function dock(machine: SpecObservedTarget, x: number, y: number)
    t.click(p, x, y, machine)
    t.tick()
    assert(t.hands(p).held == nil, "the lab bottle docks")
end

local function panel(machine: SpecObservedTarget, x: number, y: number)
    t.click(p, x, y, machine)
    t.tick()
end

local function dispense(key: string, moles: number)
    ui_controls.set(p, "amount", moles)
    t.run_ticks(2)
    ui_controls.toggle(p, "dispense", key)
    t.run_ticks(4)
end

local function eject()
    ui_controls.toggle(p, "eject")
    t.run_ticks(2)
    assert(t.hands(p).held == "lab_flask", "the lab flask comes back out")
end

-- Charge a sealed vessel from a real atmospheric gas supply. The only
-- contents entering the bottle are moved by the player's charge gesture.
t.click(p, 4, 2, lab)
t.tick()
assert(t.hands(p).held == "lab_flask", "the empty lab flask is in hand")
local source_co2 = gas(source, "co2")
local source_hydrogen = gas(source, "hydrogen")
local source_pressure = assert(t.vessel(source)).pressure_kpa
assert(source_pressure > 5000.0, "the atmospheric supply starts at useful pressure")
for _ = 1, 3 do
    t.click(p, 3, 3, source)
    t.run_ticks(4)
end
local charged_co2 = gas(lab, "co2")
local charged_hydrogen = gas(lab, "hydrogen")
assert(charged_co2 > 1.0, "three charge strokes provide enough carbon dioxide")
assert(charged_hydrogen > 3.0, "three charge strokes provide enough hydrogen")
near(charged_hydrogen / charged_co2, 3.0, 0.05, "the charge keeps the syngas ratio")
assert(gas(source, "co2") < source_co2, "the atmospheric source paid for carbon dioxide")
assert(gas(source, "hydrogen") < source_hydrogen, "the atmospheric source paid for hydrogen")
assert(
    assert(t.vessel(source)).pressure_kpa > source_pressure - 100.0,
    "the source remains a usable atmospheric supply after charging"
)

-- A cold charge cannot react, and a hot charge without catalyst cannot
-- react either. Test both gates before adding the catalyst.
assert(amount(lab, "naphtha") == 0.0, "a fresh cold charge has no naphtha")
local catalyst_amount = 0.025

-- 430 K is deliberately below the synthesis window, so a crew can warm a
-- charge without accidentally consuming it.
walk("north")
walk("east")
dock(heater, 6, 2)
panel(heater, 6, 2)
ui_controls.set(p, "temperature", 430.0)
ui_controls.toggle(p, "power")
t.run_ticks(2)
t.run_seconds(120)
assert(amount(lab, "naphtha") == 0.0, "a cold charge stays inert below the window")
ui_controls.set(p, "temperature", 460.0)
t.run_ticks(2)
t.run_seconds(120)
assert(amount(lab, "naphtha") == 0.0, "a hot charge without catalyst stays inert")
ui_controls.set(p, "temperature", 430.0)
t.run_seconds(120)
assert(assert(t.vessel(lab)).temp_k < 450.0, "the charge cooled below the window")

-- Return the hot vessel, add the catalyst through the dispenser, and run the
-- same charge again in the successful window.
ui_controls.toggle(p, "power")
t.run_ticks(2)
eject()
walk("west")
walk("south")
dock(dispenser, 5, 3)
panel(dispenser, 5, 3)
dispense("synthesis_catalyst", catalyst_amount)
eject()
assert(amount(lab, "synthesis_catalyst") >= catalyst_amount - 1e-9, "the catalyst is in the vessel")
t.run_seconds(30)
assert(amount(lab, "naphtha") == 0.0, "catalyst addition does not bypass the temperature gate")
walk("north")
walk("east")
dock(heater, 6, 2)
panel(heater, 6, 2)
ui_controls.set(p, "temperature", 460.0)
ui_controls.toggle(p, "power")
t.run_ticks(2)
t.run_seconds(240)

local final = assert(t.vessel(lab))
assert(final.temp_k > 445.0, "the lab vessel reached the synthesis temperature")
assert(final.temp_k < 475.0, "the heater did not run away")
near(amount(lab, "synthesis_catalyst"), 0.025, 1e-6, "synthesis catalyst is retained")
local made = liquid(lab, "naphtha")
local water_made = amount(lab, "water")
assert(made > 0.125, "one gas charge makes a useful naphtha batch: " .. made)
assert(water_made > 1.0, "the synthesis leaves its water coproduct")
near(charged_co2 - gas(lab, "co2"), 8.0 * made, 0.02, "eight carbon dioxide per naphtha")
near(
    charged_hydrogen - gas(lab, "hydrogen"),
    24.0 * made,
    0.05,
    "twenty-four hydrogen per naphtha"
)
near(water_made, 16.0 * made, 0.05, "sixteen water per naphtha")

-- Cooling the vessel does not erase the useful liquid product.
ui_controls.toggle(p, "power")
t.run_ticks(2)
eject()
t.drop(p)
t.tick()
local retained = liquid(lab, "naphtha")
t.run_seconds(60)
near(liquid(lab, "naphtha"), retained, 1e-6, "naphtha survives cooldown")

-- The actual gas product can become resin without separating its water
-- coproduct or the liquid synthesis catalyst.
t.click(p, 5, 2, assert(t.target_at(p, 5, 2, lab)))
t.tick()
walk("west")
walk("south")
dock(dispenser, 5, 3)
panel(dispenser, 5, 3)
dispense("polymer_catalyst", 0.05)
eject()
walk("north")
walk("east")
dock(heater, 6, 2)
panel(heater, 6, 2)
ui_controls.set(p, "temperature", 370.0)
ui_controls.toggle(p, "power")
t.run_seconds(180)
assert(amount(lab, "polymer_resin") > 0.125, "gas-derived naphtha supplies usable resin")
near(amount(lab, "polymer_resin") + amount(lab, "naphtha"), retained, 1e-5, "resin retains the feedstock units")
ui_controls.toggle(p, "power")
t.run_ticks(2)
eject()
t.drop(p)
t.tick()

-- CO2 alone follows the same player-facing route but cannot start the
-- reaction. This protects the gas stoichiometry from becoming a shortcut.
walk("west")
walk("south")
walk("south")
t.click(p, 4, 4, deficient)
t.tick()
assert(t.hands(p).held == "lab_flask", "the deficient lab flask is in hand")
t.click(p, 3, 4, missing_hydrogen)
t.run_ticks(4)
assert(gas(deficient, "co2") > 0.05, "the deficient bottle has carbon dioxide feed")
assert(gas(deficient, "hydrogen") == 0.0, "the deficient bottle has no hydrogen")
walk("north")
dock(dispenser, 5, 3)
panel(dispenser, 5, 3)
dispense("synthesis_catalyst", catalyst_amount)
eject()
walk("north")
walk("east")
dock(heater, 6, 2)
panel(heater, 6, 2)
ui_controls.set(p, "temperature", 460.0)
ui_controls.toggle(p, "power")
t.run_ticks(2)
t.run_seconds(120)
assert(liquid(deficient, "naphtha") == 0.0, "missing hydrogen blocks naphtha")
assert(gas(deficient, "co2") > 0.05, "missing hydrogen leaves carbon dioxide untouched")
