-- The roster's gates: what a recipe will not do without, and what it
-- will not do cold.
--
-- Three of tg's recipes, chosen because each one refuses for a
-- different reason. Thermite refuses because a reactant is MISSING --
-- and nothing in its file says so, because the engine's conservation
-- clamp takes the extent as the minimum of what every reactant can
-- supply and a missing one supplies nothing. Ash refuses because the
-- beaker is COLD, which is the reaction chamber's whole reason to
-- exist. Lube refuses at neither end, and that is its point: it is the
-- one on this page that a chemist makes standing at the bench with the
-- heater switched off.
--
-- Everything is pressed out of the dispenser and poured with the hands.
--
-- WHAT IS NOT HERE, and where it went. Two of these recipes used to
-- take a permanent gas -- thermite's third leg was oxygen and oil's was
-- hydrogen -- and a source deposits what a substance IS, so a gas over
-- an open beaker is refused rather than obeyed (D19). Thermite takes an
-- OXIDE now, which is what real thermite has always taken; oil dropped
-- its atomic hydrogen and its product count with it. The recipes that
-- genuinely need an atmosphere over a liquid -- carbon dioxide, nitrous
-- oxide, ammonia -- are not bench work at all and live in
-- chem_pressure_test.luau.
local PRESS = 0.75
-- Thermite: 2 aluminium + 1 iron oxide -> 3 thermite, and these are the
-- amounts that FIT. Thermite is 90 g/mol at 4.0 g/mL, so three of it
-- is 67 mL against the 50 its two legs occupied -- a whole extent
-- swells the contents by 17 mL and the engine caps a reaction by the
-- free shell volume rather than growing the glass (D16). A 50 mL
-- beaker has room for a couple of extents; this uses a twentieth of
-- one, so the assertion is about the CLAMP and never about the shell.
local ALU = 0.4
local RUST = 0.05
-- Lube: 1 water + 1 silicon -> 2 lube, at 120 g/mol and 0.97 g/mL, so
-- an extent swells the contents by 217 mL. A tenth of an extent is
-- 25 mL of lube in a 50 mL beaker: half full, and the water is in
-- excess so the run has an end rather than an asymptote.
local WET = 0.15
local SAND = 0.1

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function amount(handle, key)
    local contents = t.contents(handle)
    assert(contents ~= nil, "that is a vessel")
    return contents[key] or 0
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
        (3, 3, "beaker"),
        (2, 3, "beaker"),
    ],
    machines: [(1, 1, "chem_dispenser"), (3, 1, "chem_heater")],
    cables: [
        (1, 1, 1, 0, 2), (1, 1, 1, 0, 4), (1, 1, 2, 0, 2), (1, 1, 2, 0, 4),
        (2, 1, 1, 0, 2), (2, 1, 1, 0, 4), (2, 1, 1, 0, 8), (2, 1, 2, 0, 2),
        (2, 1, 2, 0, 4), (2, 1, 2, 0, 8), (3, 1, 1, 0, 2), (3, 1, 1, 0, 8),
        (3, 1, 2, 0, 2), (3, 1, 2, 0, 8),
        (1, 2, 1, 0, 1), (1, 2, 1, 0, 2), (1, 2, 1, 0, 4), (1, 2, 2, 0, 1),
        (1, 2, 2, 0, 2), (1, 2, 2, 0, 4), (2, 2, 1, 0, 1), (2, 2, 1, 0, 2),
        (2, 2, 1, 0, 4), (2, 2, 1, 0, 8), (2, 2, 2, 0, 1), (2, 2, 2, 0, 2),
        (2, 2, 2, 0, 4), (2, 2, 2, 0, 8), (3, 2, 1, 0, 1), (3, 2, 1, 0, 2),
        (3, 2, 1, 0, 8), (3, 2, 2, 0, 1), (3, 2, 2, 0, 2), (3, 2, 2, 0, 8),
        (1, 3, 1, 0, 1), (1, 3, 1, 0, 4), (1, 3, 2, 0, 1), (1, 3, 2, 0, 4),
        (2, 3, 1, 0, 1), (2, 3, 1, 0, 4), (2, 3, 1, 0, 8), (2, 3, 2, 0, 1),
        (2, 3, 2, 0, 4), (2, 3, 2, 0, 8), (3, 3, 1, 1, 8), (3, 3, 2, 1, 8),
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
-- ONE: THERMITE IS TWO THINGS OR IT IS NOTHING.
--
-- tg: 1 aluminium + 1 iron + 1 oxygen -> 3 thermite
-- (recipes/pyrotechnics.dm:214-217). The oxidiser here is iron OXIDE
-- rather than iron and loose oxygen, which is what real thermite has
-- always taken and what a beaker can actually hold, so the ratio is
-- the reaction everybody has seen: 2 Al + Fe2O3
-- (reactions/thermite.luau).
--
-- Aluminium on its own sits in a beaker for as long as you like and
-- does nothing whatever, and no rule in the file says it should: the
-- conservation clamp already does.
-- ---------------------------------------------------------------
take(a, 1, 2)
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
dial_to(ALU)
press("aluminium")
dial_to(PRESS)
near(amount(a, "aluminium"), ALU, 1e-9, "a press of aluminium")

t.run_seconds(60)
near(amount(a, "thermite"), 0.0, 1e-12, "half a recipe is not a recipe")

-- Pour a quarter of a mole off into the slop beaker. A beaker's pour
-- is 0.25 mol of whatever is in it (items/beaker.luau), which here is
-- aluminium and nothing else.
eject()
take(slop, 3, 2)
near(amount(slop, "aluminium"), 0.25, 1e-9, "some aluminium poured off")

-- ...and time does not help. A lone leg sits there for as long as you
-- like: what is missing is a reactant, and no amount of standing about
-- is one.
t.run_seconds(120)
near(amount(a, "thermite"), 0.0, 1e-12, "still half a recipe, still nothing")
-- ...and so does the beaker that got the pour. The gate is about what
-- is in the VESSEL, not about what the shift has been doing.
near(amount(slop, "thermite"), 0.0, 1e-12, "a lone leg is inert wherever it is standing")

-- ---------------------------------------------------------------
-- TWO: ...AND THE OXIDISER IS THE OTHER ONE.
--
-- The same beaker, with the leg it was missing pressed into it. The
-- clamp that refused above is the clamp that decides the extent here:
-- 0.15 mol of aluminium is 0.075 extents' worth and 0.05 of iron oxide
-- is 0.05, so the OXIDE is the limit and a third of the aluminium is
-- still standing in the glass at the end.
-- ---------------------------------------------------------------
take(a, 1, 2)
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
dial_to(RUST)
press("iron_oxide")
dial_to(PRESS)

-- Five minutes: a rate that reads concentration is a decay, and the
-- last thousandth of a recipe takes as long again as the first nine
-- tenths (docs/CHEMISTRY.md 5).
t.run_seconds(300)
near(amount(a, "thermite"), 3.0 * RUST, 1e-5, "three of thermite for one of the oxide")
near(amount(a, "iron_oxide"), 0.0, 1e-5, "which spent every mole of it")
near(amount(a, "aluminium"), ALU - 0.25 - 2.0 * RUST, 1e-5,
    "and the aluminium that had no partner is still there")

eject()
t.drop(p)
t.tick()

-- ---------------------------------------------------------------
-- THREE: OIL, AND THEN ASH AT 480 K.
--
-- The chain the reaction chamber exists for. tg: 1 welding fuel +
-- 1 carbon + 1 hydrogen -> 3 oil (recipes/others.dm:579-582) without
-- its hydrogen, which is H2 here and therefore not something a beaker
-- holds; then 1 oil -> 1 ash at `required_temp = 480`
-- (recipes/others.dm:592-596). Oil is the first thing on this bench
-- that is made out of something a welder carries; ash is the first
-- thing that cannot be made at all without a hotplate.
-- ---------------------------------------------------------------
-- A twentieth of a press each, and the amount is GEOMETRY talking
-- (docs/CHEMISTRY.md 5, D16). Oil is 170 g/mol at 0.9 g/mL and TWO
-- come out for one of each leg, so a whole extent swells the contents
-- by 347 mL against the 31 the two legs occupied. A 50 mL beaker has
-- room for about a seventh of an extent, and the engine caps a
-- reaction by the free shell volume rather than growing the glass. A
-- twentieth of a press of each is what this beaker can actually make,
-- and it fits with two thirds to spare.
local LEG = 0.05
take(d, 3, 3)
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
dial_to(LEG)
press("welding_fuel")
t.run_seconds(30)
near(amount(d, "oil"), 0.0, 1e-12, "fuel without carbon is fuel")

press("carbon")
dial_to(PRESS)
-- Ten seconds, not sixty: neat legs in 2 mL of liquid are a 25-molar
-- solution, so the rate the activity law asks for is far more extent
-- than the beaker holds reactants to supply and the conservation
-- clamp is what answers. This one goes in a pass. The DECAY tail is
-- the ash step below, where the product dilutes what is left.
t.run_seconds(10)
near(amount(d, "oil"), 2.0 * LEG, 1e-6, "two of oil for one of each")
near(amount(d, "welding_fuel"), 0.0, 1e-6, "and every leg of it was spent")
near(amount(d, "ash"), 0.0, 1e-12, "and no ash at all, because the beaker is cold")

eject()
dock(heater, 3, 1)
panel(heater, 3, 1)
t.ui_act(p, "set", '{"field":"temperature","value":500}')
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_seconds(120)
assert(t.holder_k(d) > 480.0, "the chamber crossed the threshold: " .. t.holder_k(d))
near(amount(d, "ash"), 2.0 * LEG, 1e-6, "every mole of oil became a mole of ash")
near(amount(d, "oil"), 0.0, 1e-6, "and there is none of it left")

-- ---------------------------------------------------------------
-- FOUR: AND ONE THAT REFUSES AT NEITHER END.
--
-- Lube: 1 water + 1 silicon -> 2 lube (recipes/others.dm:8-12 without
-- its oxygen leg). No gate, no heat, no machine -- two buttons and a
-- beaker standing on the deck, which is what the shared mixing bell is
-- FOR (docs/CHEMISTRY.md 5: tg's default window with the plateau
-- pulled down to room temperature, because tg's chemistry runs in a
-- machine that heats and ours runs in a beaker).
--
-- The water is in excess, so the SILICON is the clamp and the run has
-- an end rather than an asymptote.
-- ---------------------------------------------------------------
t.ui_act(p, "toggle", '{"field":"power"}')
eject()
t.drop(p)
t.tick()

take(e, 2, 3)
dock(dispenser, 1, 1)
panel(dispenser, 1, 1)
dial_to(WET)
press("water")
dial_to(SAND)
press("silicon")
dial_to(PRESS)
eject()

-- On the DECK, not in a machine: the whole claim is that this one needs
-- neither.
t.drop(p)
t.run_seconds(300)
near(amount(e, "lube"), 2.0 * SAND, 1e-5, "two of lube for one of silicon")
near(amount(e, "silicon"), 0.0, 1e-5, "and the silicon is gone")
near(amount(e, "water"), WET - SAND, 5e-3, "with the spare water still standing in it")
