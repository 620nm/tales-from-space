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
-- Half the batch the bench used to run, and GEOMETRY is why. tg's salt
-- recipe makes two moles of a 58 g/mol solid out of one mole each of a
-- 23 and a 35 — mass the ratios do not conserve, because a ported
-- ratio is tg's units read as moles (docs/CHEMISTRY.md 4) — so an
-- extent swells the contents by 58 mL. A reaction is capped by the
-- free shell volume and no vessel is ever grown to take the rest
-- (docs/MATTER.md 5), so a full press of each would fill 50 mL of
-- glass half way through the recipe and stop. These are the numbers
-- that fit, in the same 3:2 proportion.
local PRESS = 0.375
local BRIM = 0.625

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
-- The dial comes up at the machine's own default; this bench works in
-- smaller amounts than that (see the geometry note at the top).
dial_to(PRESS)
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
--
-- One step of the rule leaves the beaker at T + extent*Q/C_after, and
-- the capacity climbs by 47.8 J/K per extent as salt (50.5) replaces
-- its halves (28.2 + 25.0). Summed over a run that ends at X = 0.25 of
-- extent, that is the integral
--
--   dT = (Q / 47.8) * ln(1 + 47.8 * X / C_start),  C_start = 16.825
--      = 157.5 * ln(1.7103) = 84.5 K
--
-- The rate reads concentration now (docs/CHEMISTRY.md 5), so the steps
-- are large at the start and vanish at the end; a right-endpoint sum
-- of a falling integrand undershoots it, so 84.5 K is a CEILING the
-- run approaches from below and the beaker lands at 79.6. Both are
-- asserted: the bound is the arithmetic, the number is the engine's.
-- What is PINNED is the convention — a rule's `energy` is joules per
-- extent, not a temperature delta and not a per-mole figure, either of
-- which would miss by a factor of tens.
-- Five minutes, because the last thousandth of a decay is slower than
-- the first nine tenths; the claim is still that it RAN OUT.
t.run_seconds(300)
near(amount(a, "salt"), 0.5, 1e-6, "a quarter mole of chlorine made half a mole of salt")
near(amount(a, "chlorine"), 0.0, 1e-6, "and spent itself doing it")
near(amount(a, "sodium"), 0.125, 1e-6, "the sodium that had no partner is still there")
near(total(a), BRIM, 1e-6, "five eighths of a mole in, five eighths out")
assert(
    t.holder_k(a) < NOZZLE_K + 84.5,
    "the continuum limit is a CEILING: " .. t.holder_k(a)
)
near(t.holder_k(a), NOZZLE_K + 79.59, 0.05, "the exotherm is the energy rule, in kelvin")

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
-- 1e-6 rather than 1e-9: a rate that reads concentration approaches
-- the end of a recipe exponentially, so what poured is a proportion of
-- a batch that is 0.5 salt to within a millionth, not to within a
-- billionth (docs/CHEMISTRY.md 5).
near(amount(b, "salt"), 0.25 * (0.5 / BRIM), 1e-6, "salt went in proportion")
near(amount(b, "sodium"), 0.25 * (0.125 / BRIM), 1e-6, "and so did the leftover sodium")
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
