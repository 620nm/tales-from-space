-- The bench, end to end: press two buttons, watch salt appear and the
-- beaker get hot, pour half of it into another beaker, add water and
-- watch the salt dissolve.
--
-- Nothing here is set up. Every mole in this spec came out of the
-- dispenser through a button a crewman pressed, and every reaction ran
-- because the substances were in the same vessel at the same
-- temperature. That is the whole claim of docs/CHEMISTRY.md: there is no
-- chemistry system, there is the one matter system reached from more
-- places.
--
-- THE EXOTHERM IS WATCHED IN THE DOCK, and deliberately. A beaker
-- standing on the deck trades heat with the room every atmos pass
-- (sim/holder/heat.rs, Effort B's deck coupling), so the closed form
-- below is only closed for a vessel nobody is letting cool. In a
-- machine it is exact; in your hand it would be exact too; on the floor
-- it is a race with the room. That is a feature, and it is why the
-- number is asserted where it is.
local NOZZLE_K = 300.0
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

local function total(handle)
    local n = 0
    for _, moles in pairs(t.contents(handle)) do
        n = n + moles
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
        "#..g#",
        "#o.a#",
        "#####",
    ],
    spawns: [(2, 1)],
    items: [(1, 2, "beaker"), (3, 2, "beaker")],
    machines: [(2, 2, "chem_dispenser")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3),
    ],
)]==], 0)

local p = t.join()
t.tick()

local machine = t.target_at(2, 2)
local a = t.target_at(1, 2, "beaker")
local b = t.target_at(3, 2, "beaker")

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

local function open()
    t.click(p, 2, 2, machine)
    t.tick()
end

-- ---------------------------------------------------------------
-- ONE: TWO BUTTONS AND A BEAKER.
--
-- Sodium fills it three fifths of the way; chlorine trims against what
-- is left. tg's salt recipe is 1 sodium + 1 chlorine -> 2 salt
-- (others.dm:44-48), so the chlorine is the limit and a quarter of a
-- mole of sodium is still there at the end.
-- ---------------------------------------------------------------
t.click(p, 1, 2, a)
t.tick()
t.click(p, 2, 2, machine)
t.tick()
assert(t.hands(p).held == nil, "the beaker is in the machine")

open()
press("sodium")
near(amount(a, "sodium"), PRESS, 1e-9, "one press of sodium")
dial_to(BRIM - PRESS)
press("chlorine")
near(amount(a, "chlorine"), BRIM - PRESS, 1e-9, "and half a press of chlorine")
dial_to(PRESS)
near(t.holder_k(a), NOZZLE_K, 0.01, "both at the nozzle's 300 K")

-- The exotherm, closed form. `energy` on a rule is real joules per
-- extent (docs/CHEMISTRY.md, "the energy rule"): tg's thermic_constant
-- 50 times two moles of product times water's 75.3 J/mol/K = 7530.
-- The rule runs 0.05 of an extent per two-second holder step and the
-- heat capacity climbs as salt replaces its halves, so the climb slows
-- as it goes and lands where the arithmetic says it does:
--
--   start   0.75 sodium (28.2) + 0.5 chlorine (25.0) = 33.65 J/K
--   step    -0.05 Na, -0.05 Cl, +0.10 salt (50.5)    = +2.39 J/K
--   dT      sum over ten steps of 376.5 / (33.65 + 2.39k)
--
-- which is +82.3 K, and there is nothing else in the beaker for it to
-- be.
t.run_seconds(60)
near(amount(a, "salt"), 1.0, 1e-6, "half a mole of chlorine made a mole of salt")
near(amount(a, "chlorine"), 0.0, 1e-6, "and spent itself doing it")
near(amount(a, "sodium"), 0.25, 1e-6, "the sodium that had no partner is still there")
near(total(a), BRIM, 1e-6, "one and a quarter moles in, one and a quarter out")
near(t.holder_k(a), NOZZLE_K + 82.26, 0.02, "the exotherm is the energy rule, in kelvin")

-- ...and then it stops, because there is nothing left to react.
local settled = t.holder_k(a)
t.run_seconds(30)
near(t.holder_k(a), settled, 1e-6, "a finished reaction releases nothing more")

-- ---------------------------------------------------------------
-- TWO: A POUR MOVES THE HEAT WITH THE MATTER.
--
-- A fifth of the beaker into the empty one. The mix that arrives is
-- the mix that left, in the same ratio (tg's `trans_to`), and both
-- vessels read the same temperature afterwards -- which is what
-- "moles and their energy travel together" means when you can measure
-- it.
-- ---------------------------------------------------------------
t.ui_act(p, "toggle", '{"field":"eject"}')
t.run_ticks(2)
assert(t.hands(p).held == "beaker", "it comes back out")

t.click(p, 3, 2, b)
t.tick()
near(total(b), 0.25, 1e-9, "one gesture pours a quarter of a mole")
near(amount(b, "salt"), 0.25 * (1.0 / BRIM), 1e-9, "salt went in proportion")
near(amount(b, "sodium"), 0.25 * (0.25 / BRIM), 1e-9, "and so did the leftover sodium")
near(t.holder_k(b), settled, 0.01, "the heat travelled with the matter")

-- ---------------------------------------------------------------
-- THREE: AND SALT IN WATER IS SALT WATER.
--
-- tg carries brine as its own reagent (others.dm:909-912), so the
-- second recipe on this bench needs no heat and no equipment at all --
-- just the water button and the beaker that already has salt in it.
-- ---------------------------------------------------------------
t.drop(p)
t.tick()
t.click(p, 3, 2, b)
t.tick()
t.click(p, 2, 2, machine)
t.tick()
open()
press("water")

local salt_before = amount(b, "salt")
assert(salt_before > 0.0, "there is salt to dissolve")
t.run_seconds(60)
near(amount(b, "salt"), 0.0, 1e-6, "the salt went into solution")
near(amount(b, "saltwater"), salt_before * 2.0, 1e-6, "two of brine for each of salt")
-- Slacker than the two above, because water is the one reagent here
-- with a phase curve: an open beaker in a dry room loses a trace of it
-- to the air every pass (Effort G's headspace), and over a minute that
-- is a few thousandths of a mole. Salt and brine are Inert and cannot
-- evaporate, so they stay pinned to 1e-6.
near(amount(b, "water"), PRESS - salt_before, 5e-3, "and it cost a mole of water each")
