local ui_controls = require("@helpers/ui_controls")

-- The short petrochemical bench: naphtha can be finished as either a
-- polymer binder or a wax flow aid, and the two solids make printer toner.
-- Catalysts select the route and remain in the vessel, so a crew can run
-- the chain with a dispenser, beaker and heater during one shift.
local PRESS = 0.75
local RESIN = 0.20
local LEG = 0.05

local function near(a: number, b: number, slack: number, what: string)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function amount(handle, key: string)
    return (assert(t.contents(handle)))[key] or 0
end

t.world(
    [==[(
    name: "petrochemical bench",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
        'g': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
    },
    rows: [
        "######",
        "#g.o.#",
        "#...a#",
        "######",
    ],
    structures: [(2, 2, "player_spawn"), (4, 2, "apc")],
    items: [(1, 2, "beaker"), (4, 2, "beaker")],
    machines: [(3, 1, "chem_dispenser"), (4, 1, "chem_heater")],
    networks: [
        (x: 1, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
    ],
)]==],
    0
)

local p = t.join()
t.tick()

local dispenser = assert(t.target_at(p, 3, 1), "the dispenser is visible")
local heater = assert(t.target_at(p, 4, 1), "the heater is visible")
local resin_vessel = assert(t.target_at(p, 1, 2, "beaker"))
local wax_vessel = assert(t.target_at(p, 4, 2, "beaker"))

local function take(handle, x, y)
    t.click(p, x, y, handle)
    t.tick()
    assert(t.hands(p).held == "beaker", "the vessel was picked up")
end

local function dock(machine, x, y)
    t.click(p, x, y, machine)
    t.tick()
    assert(t.hands(p).held == nil, "the vessel went into the machine: " .. tostring(t.hands(p).held))
end

local function panel(machine, x, y)
    t.click(p, x, y, machine)
    t.tick()
end

local function dial_amount(moles)
    ui_controls.set(p, "amount", moles)
    t.run_ticks(2)
end

local function press(key)
    ui_controls.toggle(p, "dispense", key)
    t.run_ticks(2)
end

local function heat(kelvin, seconds)
    ui_controls.set(p, "temperature", kelvin)
    ui_controls.toggle(p, "power")
    t.run_seconds(seconds)
    ui_controls.toggle(p, "power")
end

local function eject()
    ui_controls.toggle(p, "eject")
    t.run_ticks(2)
    assert(t.hands(p).held == "beaker", "the vessel came back from the machine")
end

-- Resin needs its catalyst and its 365--375 K window. Missing catalyst
-- and a cold chamber both leave the naphtha untouched. The catalyst is
-- not consumed when the conversion does run.
take(resin_vessel, 1, 2)
t.move(p, "east")
t.tick()
dock(dispenser, 3, 1)
panel(dispenser, 3, 1)
dial_amount(RESIN)
press("naphtha")
dial_amount(PRESS)
eject()
dock(heater, 4, 1)
panel(heater, 4, 1)
heat(330, 30)
near(amount(resin_vessel, "naphtha"), RESIN, 1e-5, "cold naphtha has no resin route")
near(amount(resin_vessel, "polymer_resin"), 0.0, 1e-8, "missing catalyst blocks resin")

eject()
dock(dispenser, 3, 1)
panel(dispenser, 3, 1)
dial_amount(LEG)
press("polymer_catalyst")
dial_amount(PRESS)
eject()
dock(heater, 4, 1)
panel(heater, 4, 1)
heat(365, 120)
near(amount(resin_vessel, "polymer_resin"), RESIN, 1e-4, "naphtha makes resin in its window")
near(amount(resin_vessel, "naphtha"), 0.0, 1e-5, "resin consumes its naphtha feed")
near(amount(resin_vessel, "polymer_catalyst"), LEG, 1e-5, "polymer catalyst is retained")

-- Add carbon black while the resin is still the held batch, then park
-- that batch on the dispenser tile for the wax pour.
eject()
dock(dispenser, 3, 1)
panel(dispenser, 3, 1)
dial_amount(LEG)
press("carbon")
dial_amount(PRESS)
eject()
t.drop(p)
t.tick()
local parked_resin = assert(t.target_at(p, 3, 2, "beaker"), "the resin batch is parked")

-- Wax is the alternate route. Sulphuric acid selects it, and it also
-- remains available after the batch. This small batch is later poured
-- into the resin vessel for the toner composite.
-- Move around the heater and retrieve the second beaker.
t.move(p, "east")
t.move(p, "south")
t.move(p, "east")
t.run_ticks(3)
take(wax_vessel, 4, 2)
dock(dispenser, 3, 1)
panel(dispenser, 3, 1)
dial_amount(LEG)
press("naphtha")
press("sulfuric_acid")
dial_amount(PRESS)
eject()
dock(heater, 4, 1)
panel(heater, 4, 1)
heat(385, 120)
near(amount(wax_vessel, "wax"), LEG, 1e-4, "naphtha makes wax in its warmer window")
near(amount(wax_vessel, "naphtha"), 0.0, 1e-5, "wax consumes its naphtha feed")
near(amount(wax_vessel, "sulfuric_acid"), LEG, 1e-5, "sulphuric acid is retained")

-- Pour the wax batch into the parked resin batch.
eject()
t.click(p, 3, 2, parked_resin)
t.tick()
near(amount(resin_vessel, "wax"), LEG, 1e-5, "the wax batch pours into the resin batch")

take(parked_resin, 3, 2)
dock(heater, 4, 1)
panel(heater, 4, 1)
heat(330, 120)
near(amount(resin_vessel, "toner"), LEG, 1e-4, "resin, carbon and wax make toner")
near(amount(resin_vessel, "polymer_resin"), 0.0, 1e-4, "toner spends the resin binder")
near(amount(resin_vessel, "carbon"), 0.0, 1e-4, "toner spends the pigment")
near(amount(resin_vessel, "wax"), 0.0, 1e-4, "toner spends the flow aid")
