-- The bench, end to end: press two buttons into a BOTTLE, watch salt
-- appear, pour it into a beaker, add water and watch brine be exactly
-- what brine is -- salt in water, in one glass, with no third name.
--
-- Nothing here is set up. Every mole in this spec came out of the
-- dispenser through a button a crewman pressed, and every reaction ran
-- because the substances were in the same vessel at the same
-- temperature. That is the whole claim of docs/CHEMISTRY.md: there is
-- no chemistry system, there is the one matter system reached from
-- more places.
--
-- WHY A BOTTLE AND NOT A BEAKER, which is the lesson this spec now
-- teaches first. Salt is 2 Na + Cl2 -> 2 NaCl, and there is one id per
-- molecule: `chlorine` IS Cl2, which boils at 239 K and is therefore a
-- gas at every temperature this station has. A gas pressed over an
-- open beaker is refused, because what landed would leave through the
-- same mouth before the chemist looked up (D19). Pressed into a vessel
-- with a stopper in it, the identical press lands and condenses under
-- its own vapour pressure -- and LIQUID chlorine is the reactant the
-- recipe names.
--
-- So the order of gestures is the physics: chlorine into the bottle,
-- the bottle onto the deck to let the condensation heat out, and only
-- then the sodium. Pressing them the other way round works too and is
-- less instructive, because the exotherm and the latent heat arrive
-- together and nothing can be read off either.
local NOZZLE_K = 300.0
-- What fits, and what the recipe wants. Chlorine is the limit at 0.1
-- mol -- half a press -- and the sodium goes in at two and a half
-- times that so there is some left at the end for the clamp to be
-- visible in. Geometry is not the constraint here for once: two moles
-- of salt at 2.17 g/mL are 54 mL against the 96 that two moles of
-- sodium and one of liquid chlorine occupied, so an extent SHRINKS
-- the contents -- and only a swelling reaction is ever capped by the
-- free shell volume (docs/MATTER.md 5, D16).
local CHLORINE = 0.1
local SODIUM = 0.25

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
    items: [(1, 2, "bottle"), (3, 2, "beaker")],
    machines: [(2, 2, "chem_dispenser")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3),
    ],
)]==], 0)

local p = t.join()
t.tick()

local machine = t.target_at(2, 2)
local jar = t.target_at(1, 2, "bottle")
local b = t.target_at(3, 2, "beaker")

local function press(key)
    t.ui_act(p, "toggle", '{"field":"dispense","option":"' .. key .. '"}')
    t.run_ticks(2)
end

-- Turn the dial before a press: capacity is geometry now
-- (docs/MATTER.md 5), so a 50 mL vessel takes far more of these than
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

local function eject()
    t.ui_act(p, "toggle", '{"field":"eject"}')
    t.run_ticks(2)
end

-- The crewman stands on (2, 1) and everything they put down lands
-- there, so picking a vessel back up off the deck is a click on their
-- own feet.
local function pick_up(handle)
    t.click(p, 2, 1, handle)
    t.tick()
end

-- ---------------------------------------------------------------
-- ONE: HALF A PRESS OF CHLORINE, INTO SOMETHING WITH A LID.
--
-- The press lands as gas -- 0.1 mol in fifty millilitres is fifty
-- atmospheres -- and the bottle's own sweep condenses it back down to
-- the eight its saturation line allows at this temperature. Condensing
-- is ADIABATIC (`change_phase` moves moles and leaves `energy_j`
-- alone), so the 20.4 kJ/mol of latent heat lands in a mixture whose
-- whole capacity is a few joules per kelvin and the bottle gets HOT.
-- ---------------------------------------------------------------
t.click(p, 1, 2, jar)
t.tick()
assert(t.hands(p).held == "bottle", "the bottle is in hand")
t.click(p, 2, 2, machine)
t.tick()
assert(t.hands(p).held == nil, "and it goes into the dock")

open()
dial_to(CHLORINE)
press("chlorine")
t.run_seconds(20)
near(amount(jar, "chlorine"), CHLORINE, 1e-9, "the whole press landed, because there is a lid")
local charged = t.vessel(jar)
assert((charged.contents.chlorine.liquid or 0) > 0.0, "most of it standing as liquid")
assert(charged.temp_k > NOZZLE_K + 80.0,
    "and the latent heat is where the temperature went: " .. charged.temp_k)

-- ...so put it on the deck and let the room have it back. A container
-- LYING ON THE FLOOR trades heat with its tile every atmos pass
-- (sim/holder/heat.rs); a docked or carried one does not, which is
-- exactly why the next step needs this one.
eject()
t.drop(p)
t.run_seconds(600)
local cooled = t.vessel(jar)
near(cooled.temp_k, 303.0, 5.0, "the deck took the heat back: " .. cooled.temp_k)
assert((cooled.contents.chlorine.liquid or 0) > 0.8 * CHLORINE,
    "and most of it is liquid now: " .. tostring(cooled.contents.chlorine.liquid))
-- The gauge and the temperature are ONE statement: 892 kPa is
-- chlorine's own vapour pressure at 303 K, off the Clausius-Clapeyron
-- line anchored at its 239.1 K boiling point (docs/MATTER.md 5).
near(cooled.pressure_kpa,
    101.325 * math.exp((-20410.0 / 8.314) * (1.0 / cooled.temp_k - 1.0 / 239.1)),
    60.0, "and the gauge is that temperature's own vapour pressure")

-- ---------------------------------------------------------------
-- TWO: AND THEN THE SODIUM -- AND THE RUN STOPS WHERE THE LIQUID DOES.
--
-- Two of sodium for one of chlorine (reactions/salt.luau, tg's
-- others.dm:46-50 read as molecules), so the chlorine is the clamp and
-- the spare sodium is there to be visible at the end.
--
-- WHAT ACTUALLY ENDS THE RUN is the better lesson, and it is one no
-- reagent economy could have taught. The recipe names
-- `chlorine:liquid`. The reaction is exothermic -- 7530 J per extent,
-- against a mixture whose whole heat capacity is about ten joules per
-- kelvin -- so the bottle warms itself as it works, and a warmer bottle
-- holds more of its chlorine as VAPOUR. The run therefore does not
-- stop when the chlorine is gone; it stops when the LIQUID is gone,
-- with a saturated headspace of chlorine still in the bottle that no
-- rule naming the liquid can reach. A tenth of a mole goes in and
-- about a sixth of it is still there at the end, standing over the
-- salt as gas at exactly its own vapour pressure.
--
-- The bottle stays on the DECK for this, so the heat has somewhere to
-- go -- and the deck is not a heat sink either: this room has a
-- generator in it, so what the exotherm gives up does not come back.
-- ---------------------------------------------------------------
pick_up(jar)
t.click(p, 2, 2, machine)
t.tick()
open()
dial_to(SODIUM)
press("sodium")
eject()
t.drop(p)
t.tick()
near(amount(jar, "sodium"), SODIUM, 1e-9, "a press of sodium")

-- Five minutes, because the last thousandth of a decay is slower than
-- the first nine tenths (docs/CHEMISTRY.md 5); the claim is that it
-- reached its own END, not that it converted everything.
t.run_seconds(300)
local spent = CHLORINE - amount(jar, "chlorine")
local done = t.vessel(jar)

-- The stoichiometry, exact and whatever the residue turns out to be:
-- two of salt for every one of chlorine that was actually spent.
near(amount(jar, "salt"), 2.0 * spent, 1e-9, "two of salt for one of chlorine")
near(amount(jar, "sodium"), SODIUM - 2.0 * spent, 1e-9, "two of sodium go with it")
assert(spent > 0.8 * CHLORINE, "most of the press was spent: " .. spent)
-- Moles are not conserved and never were: 2 Na + Cl2 -> 2 NaCl is
-- three in for two out, so every extent takes one mole out of the
-- bottle. Mass is what conserves, and the ledger is what audits.
near(total(jar), SODIUM + CHLORINE - spent, 1e-9,
    "three moles in make two out, exactly and no more")

-- ...and what is LEFT is the whole explanation: not a mole of it is
-- liquid any more, so there is nothing for the rule to read.
assert(done.contents.chlorine.liquid == nil,
    "the run ended because the liquid did, not because the chlorine did")
assert((done.contents.chlorine.gas or 0) > 0.0, "there is chlorine in the bottle still")
assert(done.temp_k > 300.0, "which is standing over a bottle the exotherm warmed: " .. done.temp_k)
-- The gauge and the temperature are ONE statement again: a saturated
-- headspace reads its own vapour pressure and nothing else.
near(done.pressure_kpa,
    101.325 * math.exp((-20410.0 / 8.314) * (1.0 / done.temp_k - 1.0 / 239.1)),
    60.0, "and the gauge is that temperature's own vapour pressure")

-- ...and then it stays there, because nothing in the bottle can move.
local settled = amount(jar, "salt")
t.run_seconds(30)
near(amount(jar, "salt"), settled, 1e-9, "a stalled reaction makes nothing more")

-- ---------------------------------------------------------------
-- THREE: A POUR MOVES THE HEAT WITH THE MATTER.
--
-- The bottle's gesture is tg's cup default of 10 u
-- (items/bottle.luau), which is more than it is holding, so the whole
-- of the condensed phases goes across. The mix that arrives is the mix
-- that left, and both vessels read the same temperature afterwards --
-- which is what "moles and their energy travel together" means when
-- you can measure it.
-- ---------------------------------------------------------------
pick_up(jar)
local warmth = t.holder_k(jar)
t.click(p, 3, 2, b)
t.tick()
near(amount(b, "salt"), settled, 1e-9, "the salt went across")
near(amount(b, "sodium"), SODIUM - settled, 1e-9, "and so did the leftover sodium")
near(t.holder_k(b), warmth, 1.0, "the heat travelled with the matter")

-- ---------------------------------------------------------------
-- FOUR: AND SALT IN WATER IS SALT IN WATER.
--
-- tg carries brine as its own reagent -- `/datum/reagent/water/salt`,
-- made by a recipe that turns one of water and one of salt into two of
-- it (others.dm:909-912) -- and that recipe is gone, along with the
-- substance it made. One id per molecule: dissolving is not a
-- reaction, a solution is not a compound, and there is nothing here for
-- a third id to name. What a chemist gets is a glass holding both, in
-- the amounts they put in, which is what brine IS.
--
-- The assertion is the negative one, and it is the D1 dividend said
-- out loud: press water onto salt and NOTHING converts.
-- ---------------------------------------------------------------
t.drop(p)
t.tick()
t.click(p, 3, 2, b)
t.tick()
t.click(p, 2, 2, machine)
t.tick()
open()
dial_to(0.75)
press("water")
eject()
t.drop(p)
t.tick()

local salt_before = amount(b, "salt")
assert(salt_before > 0.0, "there is salt to dissolve")
t.run_seconds(60)
near(amount(b, "salt"), salt_before, 1e-9, "the salt is still salt")
-- Slacker than the salt, because water is the one thing in the glass
-- with a phase curve: an open beaker in a dry room loses a trace of it
-- to the air every pass, and over a minute that is a few thousandths
-- of a mole.
near(amount(b, "water"), 0.75, 5e-3, "and the water is still water")
local kinds = 0
for _ in pairs(t.contents(b)) do
    kinds = kinds + 1
end
assert(kinds == 3, "salt, the spare sodium and water -- and no fourth id for the brine: " .. kinds)
