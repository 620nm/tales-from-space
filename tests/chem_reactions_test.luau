-- The roster's gates: what a recipe will not do without, and what it
-- will not do cold.
--
-- Three of tg's recipes, chosen because each one refuses for a
-- different reason. Thermite refuses because a reactant is MISSING --
-- and nothing in its file says so, because the engine's conservation
-- clamp takes the extent as the minimum of what every reactant can
-- supply and a missing one supplies nothing. Carbon dioxide and ash
-- refuse because the beaker is COLD, which is the reaction chamber's
-- whole reason to exist.
--
-- Everything is pressed out of the dispenser and poured with the hands.
local PRESS = 0.75
local BRIM = 1.25

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function amount(handle, key)
    local contents = t.contents(handle)
    assert(contents ~= nil, "that is a vessel")
    return contents[key] or 0
end

-- What the SEALED ROOM holds of a gas, over every tile of it. A vessel
-- standing open breathes its gas phase out into the air
-- (sim/chemistry/vent.rs), so a recipe whose product is a gas is
-- counted in the room rather than in the beaker that made it.
local function room(key)
    local n = 0
    for x = 1, 3 do
        for y = 1, 3 do
            local gases = t.room_gas(x, y)
            n = n + ((gases and gases[key]) or 0)
        end
    end
    return n
end

t.world([==[(
    name: "chem bench",
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
    items: [
        (1, 2, "beaker"),
        (3, 2, "beaker"),
        (1, 3, "beaker"),
        (3, 3, "beaker"),
    ],
    machines: [(1, 1, "chem_dispenser"), (3, 1, "chem_heater")],
)]==], 0)

local p = t.join()
t.tick()

-- The crewman stands in the middle of the bench, so both machines and
-- all four beakers are within arm's reach and the spec is never about
-- walking.
local dispenser = t.target_at(1, 1)
local heater = t.target_at(3, 1)
local a = t.target_at(1, 2, "beaker")
local slop = t.target_at(3, 2, "beaker")
local c = t.target_at(1, 3, "beaker")
local d = t.target_at(3, 3, "beaker")

-- Every gesture in this spec is one of five, so they get names.
local function take(handle, x, y)
    t.click(p, x, y, handle)
    t.tick()
end

local function dock(machine, x, y)
    t.click(p, x, y, machine)
    t.tick()
    assert(t.hands(p).held == nil, "the vessel went into the machine")
end

local function panel(machine, x, y)
    t.click(p, x, y, machine)
    t.tick()
end

local function press(key)
    t.ui_act(p, "toggle", '{"field":"dispense","option":"' .. key .. '"}')
    t.run_ticks(2)
end

local ejects = 0
local function eject()
    ejects += 1
    t.ui_act(p, "toggle", '{"field":"eject"}')
    t.run_ticks(2)
    assert(t.hands(p).held == "beaker", "the vessel comes back out (eject " .. ejects .. ")")
end

-- ---------------------------------------------------------------
-- ONE: THERMITE IS THREE THINGS OR IT IS NOTHING.
--
-- tg: 1 aluminium + 1 iron + 1 oxygen -> 3 thermite
-- (recipes/pyrotechnics.dm:214-217). Two of the three sit in a beaker
-- for as long as you like and do nothing at all, and no rule in the
-- file says they should: the conservation clamp already does.
-- ---------------------------------------------------------------
take(a, 1, 2)
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
press("aluminium")
press("iron")
near(amount(a, "aluminium"), PRESS, 1e-9, "a press of aluminium")
near(amount(a, "iron"), BRIM - PRESS, 1e-9, "and iron to the brim")

t.run_seconds(60)
near(amount(a, "thermite"), 0.0, 1e-12, "two thirds of a recipe is not a recipe")

-- Pour a fifth off into the slop beaker to make room for the third
-- leg. The pour is proportional, so what leaves is a fifth of each.
eject()
take(slop, 3, 2)
near(amount(slop, "aluminium"), 0.25 * (PRESS / BRIM), 1e-9, "some aluminium poured off")
near(amount(slop, "iron"), 0.25 * (0.5 / BRIM), 1e-9, "and some iron with it")

dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
press("o2")
near(amount(a, "o2"), 0.25, 1e-9, "the station's own oxygen, to the brim again")

t.run_seconds(60)
near(amount(a, "thermite"), 0.75, 1e-6, "and now it goes: three out for one of each in")
near(amount(a, "aluminium"), 0.6 - 0.25, 1e-6, "the aluminium that was in excess remains")
near(amount(a, "iron"), 0.4 - 0.25, 1e-6, "and so does the iron")
near(amount(a, "o2"), 0.0, 1e-6, "the oxygen was the limit, and it is spent")
-- ...and the beaker that got the pour still has two of the three, still
-- sitting there. The gate is about what is in the VESSEL, not about
-- what the shift has been doing.
near(amount(slop, "thermite"), 0.0, 1e-12, "a pair is inert wherever it is standing")

-- ---------------------------------------------------------------
-- TWO: CARBON DIOXIDE NEEDS 777 K.
--
-- tg: 1 carbon + 2 oxygen -> 3 CO2, `required_temp = 777` because
-- "pure carbon isn't especially reactive" (recipes/others.dm:142-146).
-- The product goes into the BUILTIN gas, in the gas phase -- the same
-- substance an atmos cell carries, which is the whole unification.
-- ---------------------------------------------------------------
eject()
t.drop(p)
t.tick()

take(c, 1, 3)
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
press("carbon")
press("o2")
t.run_seconds(60)
near(amount(c, "co2"), 0.0, 1e-12, "a cold beaker of carbon and oxygen is a cold beaker")

eject()
dock(heater, 3, 1)
panel(heater, 3, 1)
t.ui_act(p, "set", '{"field":"temperature","value":800}')
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_seconds(90)
assert(t.holder_k(c) > 777.0, "the chamber got there: " .. t.holder_k(c))
near(room("co2"), 0.75, 1e-3, "and three moles of gas for one of carbon, breathed out into the room")
near(amount(c, "o2"), 0.0, 1e-6, "the oxygen was the limit again")
near(amount(c, "carbon"), PRESS - 0.25, 1e-6, "the rest of the carbon is still carbon")

-- Take the heat away and it stops where it is: the window is a gate on
-- the RATE, so a rule outside it does not run slowly, it does not run.
t.ui_act(p, "toggle", '{"field":"power"}')
eject()
t.drop(p)
t.tick()

-- ---------------------------------------------------------------
-- THREE: OIL, AND THEN ASH AT 480 K.
--
-- The chain the reaction chamber exists for. tg: 1 welding fuel +
-- 1 carbon + 1 hydrogen -> 3 oil (recipes/others.dm:578-581), then
-- 1 oil -> 1 ash at `required_temp = 480` (recipes/others.dm:589-593).
-- Oil is the first thing on this bench that is made out of something a
-- welder carries; ash is the first thing that cannot be made at all
-- without a hotplate.
-- ---------------------------------------------------------------
take(d, 3, 3)
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
press("welding_fuel")
press("carbon")
t.run_seconds(30)
near(amount(d, "oil"), 0.0, 1e-12, "fuel and carbon without hydrogen is fuel and carbon")

eject()
take(slop, 3, 2)
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
press("hydrogen")
t.run_seconds(60)
near(amount(d, "oil"), 0.75, 1e-6, "three of oil for one of each")
near(amount(d, "ash"), 0.0, 1e-12, "and no ash at all, because the beaker is cold")

eject()
dock(heater, 3, 1)
panel(heater, 3, 1)
t.ui_act(p, "set", '{"field":"temperature","value":500}')
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_seconds(120)
assert(t.holder_k(d) > 480.0, "the chamber crossed the threshold: " .. t.holder_k(d))
near(amount(d, "ash"), 0.75, 1e-6, "every mole of oil became a mole of ash")
near(amount(d, "oil"), 0.0, 1e-6, "and there is none of it left")
