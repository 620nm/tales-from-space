-- A window has a CEILING as well as a floor, and that is the reason the
-- reaction chamber has a dial rather than a switch.
--
-- Ash is the rule with both ends on this shelf: tg's `required_temp` of
-- 480 through the documented bell mapping is 480 / 500 / 900 / 920
-- (reactions/ash.luau), so a chamber dialled to 400 does nothing at
-- all, one dialled to 700 runs it dry, and one dialled past 920 stops
-- again. Three answers from one knob, and the third is the one a
-- chemist never guesses.
--
-- THE SECOND REFUSAL IS HARD TO STAGE, and the staging is the
-- interesting part. A heater ramps, so a beaker of oil cannot get from
-- room temperature to 960 K without crossing the window on the way up
-- and turning into ash in the middle of it. The second beaker
-- therefore gets the LAST of oil's three reactants pressed in while the
-- vessel is already too hot: the oil is made ABOVE the ash window's
-- ceiling and stays oil, which is a thing a chemist can actually do,
-- and the only honest way to ask "what happens at 960 K" of a rule that
-- would otherwise have fired at 500.
--
-- C1: this spec used to stage the same three answers on nitrous oxide,
-- whose recipe wants a mole of nitrogen and two of oxygen. Those are
-- permanent gases: a source deposits them as gas, and a gas pressed
-- over an open beaker is refused rather than obeyed (D19). They come
-- back to chemistry from a canister into a sealed vessel, and the N2O
-- recipe is rewritten around that share.
local PRESS = 0.75
-- One press of each of oil's three reactants, which is a quarter of an
-- extent and three quarters of a mole of oil.
local LEG = 0.25

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function amount(handle, key)
    local contents = t.contents(handle)
    assert(contents ~= nil, "that is a vessel")
    return contents[key] or 0
end

-- What the SEALED ROOM holds of a gas, over every tile of it. An open
-- vessel breathes its gas phase into the air (sim/holder/vent.rs),
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
        'o': (turf: Floor, fixture: Some(Outlet)),
        'g': (turf: Floor, fixture: Some(Generator)),
        'a': (turf: Floor, fixture: Some(Apc)),
    },
    rows: [
        "#####",
        "#.g.#",
        "#o.a#",
        "#####",
    ],
    spawns: [(2, 2)],
    items: [(1, 2, "beaker"), (3, 2, "beaker")],
    machines: [(1, 1, "chem_dispenser"), (3, 1, "chem_heater")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3),
    ],
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

-- Turn the dial before a press: capacity is geometry now
-- (docs/MATTER.md 5), so a 50 mL beaker takes far more of these than
-- the recipe wants, and the amount that goes in is the chemist's to
-- choose rather than the glass's to impose.
local function dial_to(moles)
    t.ui_act(p, "set", '{"field":"amount","value":' .. moles .. '}')
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

-- Oil first: one of welding fuel, one of carbon and one of hydrogen
-- for three of oil (recipes/others.dm:578-581), which the shelf makes
-- in one cold vessel with three presses and no help at all. The carbon
-- arrives as a POWDER, because that is what carbon is at the nozzle's
-- 300 K and a source names no phase (D11).
local function brew_oil(beaker)
    dock(dispenser, 1, 1)
    panel(dispenser, 1, 1)
    dial_to(LEG)
    press("welding_fuel")
    press("carbon")
    press("hydrogen")
    dial_to(PRESS)
    t.run_seconds(30)
    near(amount(beaker, "oil"), PRESS, 1e-6, "one of each made three of oil")
    near(amount(beaker, "carbon"), 0.0, 1e-6, "and nothing is left over")
end

-- ---------------------------------------------------------------
-- ONE: BELOW THE WINDOW, NOTHING.
-- ---------------------------------------------------------------
take(cold, 1, 2)
brew_oil(cold)

eject()
dock(heater, 3, 1)
panel(heater, 3, 1)
dial(400)
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_seconds(120)
near(t.holder_k(cold), 400.0, 1.0, "the chamber holds it at 400 K")
near(amount(cold, "ash"), 0.0, 1e-12, "eighty kelvin short is short")
near(amount(cold, "oil"), PRESS, 1e-6, "and every mole of oil is still oil")

-- ---------------------------------------------------------------
-- TWO: INSIDE IT, IT GOES.
--
-- Three hundred kelvin up the dial and the same beaker runs dry: one
-- of ash for one of oil (recipes/others.dm:589-593), and the ash is a
-- POWDER standing in the glass rather than a second liquid.
-- ---------------------------------------------------------------
dial(700)
t.run_seconds(120)
near(t.holder_k(cold), 700.0, 25.0, "the chamber took it up into the window")
near(amount(cold, "ash"), PRESS, 1e-6, "every mole of oil became a mole of ash")
near(amount(cold, "oil"), 0.0, 1e-6, "and there is none of it left")

t.ui_act(p, "toggle", '{"field":"power"}')
eject()
t.drop(p)
t.tick()

-- ---------------------------------------------------------------
-- THREE: ABOVE IT, NOTHING AGAIN.
--
-- The second beaker is brought to 960 K holding only two of oil's
-- three, and the hydrogen is pressed in hot. A tenth of a leg at the
-- nozzle's 300 K barely moves a mixture of that heat capacity, so the
-- oil is MADE at over 950 K -- forty kelvin over the ash window's
-- ceiling, and the rule stays shut.
-- ---------------------------------------------------------------
take(hot, 3, 2)
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
dial_to(LEG)
press("welding_fuel")
press("carbon")
dial_to(PRESS)

eject()
dock(heater, 3, 1)
panel(heater, 3, 1)
dial(960)
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_seconds(150)
assert(t.holder_k(hot) > 940.0, "the chamber overshot the window on purpose: " .. t.holder_k(hot))

eject()
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
dial_to(LEG / 10.0)
press("hydrogen")
dial_to(PRESS)
assert(t.holder_k(hot) > 920.0, "and the mixture is still over the window: " .. t.holder_k(hot))

t.run_seconds(120)
assert(amount(hot, "oil") > 0.0, "the oil was made up there: " .. amount(hot, "oil"))
near(amount(hot, "ash"), 0.0, 1e-12, "over the window is as shut as under it")

-- ...and the proof that it was the TEMPERATURE and not the mixture:
-- put the same beaker back on the dial at 700 and it converts, coming
-- down into the window from above.
local made = amount(hot, "oil")
eject()
dock(heater, 3, 1)
panel(heater, 3, 1)
dial(700)
t.run_seconds(150)
near(amount(hot, "ash"), made, 1e-6, "coming down into the window works as well as up")
near(amount(hot, "oil"), 0.0, 1e-6, "and it spends the oil it would not touch at 960")
