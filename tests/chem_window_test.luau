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
-- therefore gets the LAST of oil's two reactants pressed in while the
-- vessel is already too hot: the oil is made ABOVE the ash window's
-- ceiling and stays oil, which is a thing a chemist can actually do,
-- and the only honest way to ask "what happens at 960 K" of a rule that
-- would otherwise have fired at 500.
--
-- This spec used to stage the same three answers on nitrous oxide,
-- whose recipe wanted a mole of nitrogen and two of oxygen. Those are
-- permanent gases: a source deposits them as gas, and a gas pressed
-- over an open beaker is refused rather than obeyed (D19). They come
-- back to chemistry from a canister into a sealed vessel, and the N2O
-- recipe is written around that share.
local PRESS = 0.75
-- A twentieth of a press of each of oil's two reactants, and the
-- amount is GEOMETRY talking (docs/CHEMISTRY.md 5, D16). Oil is
-- 170 g/mol at 0.9 g/mL and TWO come out for one of each leg, so a
-- whole extent swells the contents by 347 mL against the 31 the legs
-- occupied: a 50 mL beaker has room for about a seventh of an extent,
-- and the engine caps a reaction by the free shell volume rather than
-- growing the glass. A twentieth of a press of each fits with two
-- thirds to spare.
local LEG = 0.05
-- ...and two of oil come out of it, which is what the ash window is
-- then asked about.
local MADE = 2.0 * LEG

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

-- Oil first: one of welding fuel and one of carbon for two of oil
-- (recipes/others.dm:579-582 without its hydrogen leg -- hydrogen is
-- H2 here and no source hands a permanent gas to an open beaker), which
-- the shelf makes in one cold vessel with two presses and no help at
-- all. The carbon arrives as a POWDER, because that is what carbon is
-- at the nozzle's 300 K and a source names no phase (D11).
local function brew_oil(beaker)
    dock(dispenser, 1, 1)
    panel(dispenser, 1, 1)
    dial_to(LEG)
    press("welding_fuel")
    press("carbon")
    dial_to(PRESS)
    t.run_seconds(30)
    near(amount(beaker, "oil"), MADE, 1e-6, "one of each made two of oil")
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
near(amount(cold, "oil"), MADE, 1e-6, "and every mole of oil is still oil")

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
near(amount(cold, "ash"), MADE, 1e-6, "every mole of oil became a mole of ash")
near(amount(cold, "oil"), 0.0, 1e-6, "and there is none of it left")

t.ui_act(p, "toggle", '{"field":"power"}')
eject()
t.drop(p)
t.tick()

-- ---------------------------------------------------------------
-- THREE: ABOVE IT, NOTHING AGAIN.
--
-- The second beaker is brought to 960 K holding one of oil's two and a
-- lump of ballast, and the welding fuel is pressed in hot. THE BALLAST
-- IS THE STAGING: the second leg arrives at the nozzle's 300 K and
-- something has to shrug it off. A notch of fuel against a full press
-- of iron and a full press of carbon is twenty kelvin; against the
-- carbon notch alone it would be hundreds, and the beaker would fall
-- back through the window it is supposed to be over.
--
-- WHICH LEG GOES IN LAST IS NOT ARBITRARY. Welding fuel is the second
-- leg here, and carbon is the ballast, because oil and welding fuel
-- standing together in one vessel are ACETONE
-- (reactions/acetone.luau, tg's others.dm:477 without its oxygen leg).
-- Fuel in excess would eat the oil this spec is about as fast as it
-- was made, and would still be there at 700 K to eat it again instead
-- of letting it become ash. Fuel as the LIMITING leg is spent by the
-- time the run ends, so what stands in the beaker at 960 K is oil, a
-- share of acetone, and nothing that can touch either.
--
-- The iron is there for its 25 J/(mol*K) and nothing else: no rule in
-- this pack's roster names it, so it is heat capacity with no opinions.
-- ---------------------------------------------------------------
-- The dial's smallest step, off machines/chem_dispenser.luau: one tg
-- unit at 1 u = 0.025 mol. A tenth of a leg is under the notch, so
-- this is the smallest press a chemist can actually make.
local NOTCH = 0.025
take(hot, 3, 2)
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
dial_to(PRESS)
press("iron")
press("carbon")

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
dial_to(NOTCH)
press("welding_fuel")
dial_to(PRESS)
assert(t.holder_k(hot) > 920.0, "and the mixture is still over the window: " .. t.holder_k(hot))

-- Five minutes, because the oil rule is running at a QUARTER of its
-- plateau up here -- 950 K is most of the way down the far shoulder of
-- 100/280/900/1000 (reactions/oil.luau) -- and a rate that reads
-- concentration is a decay besides (docs/CHEMISTRY.md 5).
t.run_seconds(320)
local made = amount(hot, "oil")
assert(made > 0.0, "the oil rule ran up here: " .. made .. " mol")
near(amount(hot, "welding_fuel"), 0.0, 1e-4, "and it spent the notch of fuel doing it")
near(amount(hot, "ash"), 0.0, 1e-12, "over the window is as shut as under it")

-- ...and the proof that it was the TEMPERATURE and not the mixture:
-- put the same beaker back on the dial at 700 and every mole of the oil
-- standing in it converts, coming down into the window from above.
-- Four minutes rather than two and a half: the oil here is a couple of
-- notches in a beaker of ballast rather than a neat batch, and a decay
-- in a dilute solution has the longer tail.
eject()
dock(heater, 3, 1)
panel(heater, 3, 1)
dial(700)
t.run_seconds(240)
near(amount(hot, "ash"), made, 1e-3, "coming down into the window works as well as up")
near(amount(hot, "oil"), 0.0, 1e-3, "and it spends the oil it would not touch at 960")
