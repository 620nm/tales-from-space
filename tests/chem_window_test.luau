-- Nitrous oxide: fifty kelvin wide, and the reason the reaction
-- chamber has a dial rather than a switch.
--
-- tg gives this recipe the tightest window in the base game --
-- required 525, optimal 550, overheat 575, and a temperature exponent
-- of 0.2 so the edges are nearly as good as the middle
-- (recipes/others.dm:149-160). Ported through the documented bell
-- mapping it is 525 / 550 / 575 / 600, which means a chamber dialled to
-- 500 does nothing at all and a chamber dialled past 600 stops.
--
-- BOTH REFUSALS ARE HARD TO STAGE, and the staging is the interesting
-- part. A heater ramps, so a beaker holding all three reactants cannot
-- get from room temperature to 650 K without crossing the window on the
-- way. The second beaker therefore gets the third reactant LAST,
-- pressed in while the vessel is already too hot -- which is a thing a
-- chemist can actually do, and the only honest way to ask "what happens
-- at 650 K" of a rule that would otherwise have fired at 560.
local PRESS = 0.75

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function amount(handle, key)
    local contents = t.contents(handle)
    assert(contents ~= nil, "that is a vessel")
    return contents[key] or 0
end

-- What the SEALED ROOM holds of a gas, over every tile of it. An open
-- vessel breathes its gas phase into the air (sim/chemistry/vent.rs),
-- so a recipe whose product is a gas fills the room rather than the
-- beaker -- and the room is where it has to be counted, because the
-- air moves between tiles the moment it is there.
local function room(key)
    local n = 0
    for x = 1, 3 do
        for y = 1, 2 do
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
        "#####",
    ],
    spawns: [(2, 2)],
    items: [(1, 2, "beaker"), (3, 2, "beaker")],
    machines: [(1, 1, "chem_dispenser"), (3, 1, "chem_heater")],
)]==], 0)

local p = t.join()
t.tick()

local dispenser = t.target_at(1, 1)
local heater = t.target_at(3, 1)
local cold = t.target_at(1, 2, "beaker")
local hot = t.target_at(3, 2, "beaker")

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

local function eject()
    t.ui_act(p, "toggle", '{"field":"eject"}')
    t.run_ticks(2)
    assert(t.hands(p).held == "beaker", "the vessel comes back out")
end

local function dial(kelvin)
    t.ui_act(p, "set", '{"field":"temperature","value":' .. kelvin .. '}')
    t.run_ticks(2)
end

-- Ammonia first, in both beakers: three of hydrogen to one of nitrogen
-- (recipes/others.dm:432-439), which the shelf makes in one vessel with
-- two presses and no help at all.
local function brew_ammonia(beaker)
    dock(dispenser, 1, 1)
    panel(dispenser, 1, 1)
    press("hydrogen")
    press("n2")
    t.run_seconds(30)
    near(amount(beaker, "ammonia"), PRESS, 1e-6, "three of hydrogen made three of ammonia")
    near(amount(beaker, "n2"), 0.25, 1e-6, "and a quarter of the nitrogen is spare")
end

-- ---------------------------------------------------------------
-- ONE: BELOW THE WINDOW, NOTHING.
-- ---------------------------------------------------------------
take(cold, 1, 2)
brew_ammonia(cold)
press("o2")
near(amount(cold, "o2"), 0.25, 1e-9, "and oxygen to the brim: all three reactants present")

eject()
dock(heater, 3, 1)
panel(heater, 3, 1)
dial(500)
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_seconds(120)
near(t.holder_k(cold), 500.0, 1.0, "the chamber holds it at 500 K")
near(amount(cold, "n2o"), 0.0, 1e-12, "twenty-five kelvin short is short")
near(amount(cold, "ammonia"), PRESS, 1e-6, "and every mole of ammonia is still ammonia")

-- ---------------------------------------------------------------
-- TWO: INSIDE IT, IT GOES.
--
-- Fifty kelvin up the dial and the same beaker converts. tg's ratio is
-- 2 ammonia + 1 nitrogen + 2 oxygen -> 5 N2O, so the quarter mole of
-- oxygen is the limit and an eighth of an extent is all there is.
-- ---------------------------------------------------------------
dial(550)
t.run_seconds(120)
near(t.holder_k(cold), 550.0, 25.0, "the chamber took it up to the window")
near(room("n2o"), 0.625, 1e-3, "five of gas for two of ammonia, and gas leaves an open beaker")
near(amount(cold, "o2"), 0.0, 1e-6, "the oxygen was the limit")
near(amount(cold, "ammonia"), PRESS - 0.25, 1e-6, "and the ammonia is down by two extents")

t.ui_act(p, "toggle", '{"field":"power"}')
eject()
t.drop(p)
t.tick()

-- ---------------------------------------------------------------
-- THREE: ABOVE IT, NOTHING AGAIN.
--
-- The second beaker is brought to 650 K holding only two of the three,
-- and the oxygen is pressed in hot. Adding a quarter mole at the
-- nozzle's 300 K pulls the mixture down to about 625 -- still well over
-- the window's 600, and the rule stays shut.
-- ---------------------------------------------------------------
take(hot, 3, 2)
brew_ammonia(hot)
eject()
dock(heater, 3, 1)
panel(heater, 3, 1)
dial(650)
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_seconds(150)
assert(t.holder_k(hot) > 640.0, "the chamber overshot the window on purpose: " .. t.holder_k(hot))

eject()
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
press("o2")
near(amount(hot, "o2"), 0.25, 1e-9, "the third reactant arrives late and cold")
assert(t.holder_k(hot) > 600.0, "and the mixture is still over the window: " .. t.holder_k(hot))

t.run_seconds(120)
near(amount(hot, "n2o"), 0.0, 1e-12, "over the window is as shut as under it")
near(amount(hot, "o2"), 0.25, 1e-6, "nothing was spent")

-- ...and the proof that it was the TEMPERATURE and not the mixture:
-- put the same beaker back on the dial at 550 and it converts, coming
-- down into the window from above.
eject()
dock(heater, 3, 1)
panel(heater, 3, 1)
dial(550)
t.run_seconds(150)
assert(room("n2o") > 0.625, "coming down into the window works as well as up")
near(amount(hot, "o2"), 0.0, 1e-6, "and it spends the oxygen it would not touch at 650")
