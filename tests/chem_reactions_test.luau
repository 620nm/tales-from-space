-- The roster's gates: what a recipe will not do without, and what it
-- will not do cold.
--
-- Three of tg's recipes, chosen because each one refuses for a
-- different reason. Thermite refuses because a reactant is MISSING --
-- and nothing in its file says so, because the engine's conservation
-- clamp takes the extent as the minimum of what every reactant can
-- supply and a missing one supplies nothing. Ash refuses because the
-- beaker is COLD, which is the reaction chamber's whole reason to
-- exist. Chlorine refuses at neither end, and that is its point.
--
-- Everything is pressed out of the dispenser and poured with the hands.
--
-- C1: thermite's third leg is oxygen and carbon dioxide is made of it,
-- and oxygen is a permanent gas -- a source deposits it as gas, and a
-- gas pressed over an open beaker is refused rather than obeyed (D19).
-- The completion half of the thermite case and the carbon dioxide case
-- come back when those recipes take an oxidiser they can hold: thermite
-- from iron oxide, carbon dioxide from a gas share in a sealed vessel.
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
-- (sim/holder/vent.rs), so a recipe whose product is a gas is
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
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "#####",
        "#.g.#",
        "#o..#",
        "#a..#",
        "#####",
    ],
    spawns: [(2, 2)],
    items: [
        (1, 2, "beaker"),
        (3, 2, "beaker"),
        (1, 3, "beaker"),
        (3, 3, "beaker"),
        (2, 3, "beaker"),
    ],
    machines: [(1, 1, "chem_dispenser"), (3, 1, "chem_heater")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3),
        (1, 3, 3), (2, 3, 3), (3, 3, 3),
    ],
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
local e = t.target_at(2, 3, "beaker")

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

-- Turn the dial before a press: capacity is geometry now
-- (docs/MATTER.md 5), so a 50 mL beaker takes far more of these than
-- the recipe wants, and the amount that goes in is the chemist's to
-- choose rather than the glass's to impose.
local function dial_to(moles)
    t.ui_act(p, "set", '{"field":"amount","value":' .. moles .. '}')
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
dial_to(BRIM - PRESS)
press("iron")
dial_to(PRESS)
near(amount(a, "aluminium"), PRESS, 1e-9, "a press of aluminium")
near(amount(a, "iron"), BRIM - PRESS, 1e-9, "and half a press of iron")

t.run_seconds(60)
near(amount(a, "thermite"), 0.0, 1e-12, "two thirds of a recipe is not a recipe")

-- Pour a fifth off into the slop beaker to make room for the third
-- leg. The pour is proportional, so what leaves is a fifth of each.
eject()
take(slop, 3, 2)
near(amount(slop, "aluminium"), 0.25 * (PRESS / BRIM), 1e-9, "some aluminium poured off")
near(amount(slop, "iron"), 0.25 * (0.5 / BRIM), 1e-9, "and some iron with it")

-- ...and time does not help. A pair sits there for as long as you like:
-- what is missing is a reactant, and no amount of standing about is one.
t.run_seconds(120)
near(amount(a, "thermite"), 0.0, 1e-12, "still two thirds of a recipe, still nothing")
-- ...and so does the beaker that got the pour. The gate is about what
-- is in the VESSEL, not about what the shift has been doing.
near(amount(slop, "thermite"), 0.0, 1e-12, "a pair is inert wherever it is standing")

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
-- A twentieth of a press each, and the amount is GEOMETRY talking
-- (docs/CHEMISTRY.md 5, D16). Oil is 170 g/mol on the shelf's default
-- 1 g/mL and THREE come out for one of each leg, so a whole extent
-- swells the contents by 471 mL against the 39 the three legs
-- occupied. A 50 mL beaker has room for about a tenth of an extent,
-- and the engine caps a reaction by the free shell volume rather than
-- growing the glass. A twentieth of a press of each is what this
-- beaker can actually make, and it fits with two thirds to spare.
local LEG = 0.05
take(d, 3, 3)
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
dial_to(LEG)
press("welding_fuel")
press("carbon")
t.run_seconds(30)
near(amount(d, "oil"), 0.0, 1e-12, "fuel and carbon without hydrogen is fuel and carbon")

press("hydrogen")
dial_to(PRESS)
-- Ten seconds, not sixty: neat legs in 2 mL of liquid are a 25-molar
-- solution, so the rate the activity law asks for is far more extent
-- than the beaker holds reactants to supply and the conservation
-- clamp is what answers. This one goes in a pass. The DECAY tail is
-- the ash step below, where the product dilutes what is left.
t.run_seconds(10)
near(amount(d, "oil"), 3.0 * LEG, 1e-6, "three of oil for one of each")
near(amount(d, "welding_fuel"), 0.0, 1e-6, "and every leg of it was spent")
near(amount(d, "ash"), 0.0, 1e-12, "and no ash at all, because the beaker is cold")

eject()
dock(heater, 3, 1)
panel(heater, 3, 1)
t.ui_act(p, "set", '{"field":"temperature","value":500}')
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_seconds(120)
assert(t.holder_k(d) > 480.0, "the chamber crossed the threshold: " .. t.holder_k(d))
near(amount(d, "ash"), 3.0 * LEG, 1e-6, "every mole of oil became a mole of ash")
near(amount(d, "oil"), 0.0, 1e-6, "and there is none of it left")

-- ---------------------------------------------------------------
-- FOUR: CHLORINE GAS, ALL THE WAY UP.
--
-- The three windows above are tg's own, ported number for number: ash
-- and carbon dioxide have an overheat band because tg's recipes do.
-- A DECOMPOSITION does not. Chlorine's gate at 420 K is a floor with
-- nothing over it (reactions/chlorine_gas.luau), so the most obvious
-- gesture on the bench -- turn the dial to its stop -- has to make MORE
-- gas rather than none.
--
-- It used to make none. The bell was authored 420/435/500/520, and the
-- engine reads a bell as exactly zero above `temp_max`, so a chemist at
-- 1000 K got a hot beaker and nothing else.
-- ---------------------------------------------------------------
t.ui_act(p, "toggle", '{"field":"power"}')
eject()
t.drop(p)
t.tick()

take(e, 2, 3)
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
press("chlorine")
near(amount(e, "chlorine"), PRESS, 1e-9, "a press of chlorine")

eject()
dock(heater, 3, 1)
panel(heater, 3, 1)
t.ui_act(p, "set", '{"field":"temperature","value":1000}')
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_seconds(90)

-- THE ASSERTION: the beaker runs DRY. A bench held at 1000 K races
-- through 420-520 in a few passes, so a rule that shut at 520 would
-- convert a sliver on the way up and then sit there with most of the
-- press still in the glass forever. Nothing is left.
near(amount(e, "chlorine"), 0.0, 1e-6, "the dial at its stop ran the whole press off")
near(room("cl2"), PRESS / 2.0, 1e-3, "two of the reagent for one of the molecule")
