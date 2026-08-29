-- IDENTITY: a still, built out of a hotplate and a closet.
--
-- Distillation is the oldest thing anybody does with two liquids, and
-- it is not a mechanism this engine has: nothing in `crates/` knows
-- what a still is. What it has instead is one line per substance and
-- Raoult's law on the evaporating side of the phase step
-- (docs/MATTER.md), and a still is what those two ARE when a boiler
-- and a vapour space stand next to each other.
--
-- Two claims, and the second is the one that matters.
--
--   ONE, THE ONSET. An open vessel boils against the pressure it
--   actually bears -- its tile's, not one atmosphere by assumption
--   (D5, `BoilAgainst::Ambient`). So a beaker of ethanol on an element
--   dialled well over it does not climb to the dial: it stalls at
--   ethanol's own boiling point, 351.5 K, which is the number
--   substances/ethanol.luau authors and the temperature a still starts
--   working at. Everything below that is a warm beaker.
--
--   TWO, THE SEPARATION. The vapour over a half-and-half wash is NOT
--   half and half. Raoult puts each component's partial pressure at
--   its own vapour pressure times its liquid mole fraction, and
--   ethanol's line is far over water's at these temperatures -- so the
--   vapour that leaves is ethanol-rich and what stays behind gets
--   watery. That is the whole of what a still is, and this spec
--   asserts it as two mole fractions moving apart.
--
-- WHAT THE RECEIVER IS, stated plainly. The milestone spec asked for a
-- second sealed bottle with a gas-phase transfer into it every tick.
-- Nothing a PLAYER can do moves gas out of a sealed vessel -- the
-- bottle's own valve gesture (items/bottle.luau) pulls gas OUT of a
-- fixture and INTO the bottle, never the other way -- and a spec may
-- only assert what a player could cause (tfs/AGENTS.md). So the
-- receiver here is the vapour space itself: the closet the boiler
-- stands in, read through `t.room_gas`, which reports the GAS phase
-- and nothing else and is therefore exactly the take-off. A condenser
-- to catch it is plumbing this station has not been given yet, and it
-- would not change either number below.

local R = 8.314462618

-- The two lines, off the substance files' own numbers
-- (ethanol: boil 351.5, l_vap 38 560; water: boil 373.15, l_vap
-- 40 660), inverted with Raoult exactly as `Line::t` does
-- (lunatic-matter/src/registry.rs): 1/T = 1/T_a + ln(P/(x*p_a))/k.
local function bubble_k(boil_k, l_vap, p_kpa, x)
    return 1.0 / (1.0 / boil_k + math.log(p_kpa * 1000.0 / (x * 101325.0)) / (-l_vap / R))
end

local function ethanol_boil_k(p_kpa, x)
    return bubble_k(351.5, 38560.0, p_kpa, x)
end

local function water_boil_k(p_kpa, x)
    return bubble_k(373.15, 40660.0, p_kpa, x)
end

local BENCH = [==[(
    name: "the still room",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "#########",
        "#o.o....#",
        "#.......#",
        "#.ag....#",
        "#########",
    ],
    spawns: [(2, 2)],
    items: [(3, 3, "beaker")],
    machines: [(1, 2, "chem_dispenser"), (3, 2, "chem_heater")],
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
        (1, 3, 1, 1, 4), (1, 3, 2, 1, 4), (2, 3, 1, 0, 1), (2, 3, 1, 0, 4),
        (2, 3, 1, 0, 8), (2, 3, 2, 0, 1), (2, 3, 2, 0, 4), (2, 3, 2, 0, 8),
        (3, 3, 1, 0, 1), (3, 3, 1, 0, 8), (3, 3, 2, 0, 1), (3, 3, 2, 0, 8),
    ],
)]==]

-- Twenty-one tiles of closet, and every one of them is where the
-- vapour can be. A still's take-off is a volume, so it is counted over
-- the whole of one.
local ROOM = {}
for x = 1, 7 do
    for y = 1, 3 do
        ROOM[#ROOM + 1] = { x, y }
    end
end

local p, dispenser, boiler, pot

local function bench()
    t.world(BENCH, 0)
    -- An inert sky, for the same reason the dry-ice spec asks for one:
    -- the roster's default parks this station under a star, and a
    -- closet warming on its own would move every plateau below
    -- (queries.rs, `set_environment`).
    t.set_environment({ sink_k = 293.15, insolation = 0.0 })
    p = t.join()
    t.tick()
    dispenser = t.target_at(1, 2)
    boiler = t.target_at(3, 2)
    pot = t.target_at(3, 3, "beaker")
    assert(dispenser ~= nil and boiler ~= nil and pot ~= nil, "the bench is set")
end

local function press(key, mol)
    t.ui_act(p, "set", '{"field":"amount","value":' .. mol .. '}')
    t.run_ticks(2)
    t.ui_act(p, "toggle", '{"field":"dispense","option":"' .. key .. '"}')
    t.run_ticks(4)
end

local function charge(keys, mol)
    t.click(p, 3, 3, pot)
    t.run_ticks(2)
    assert(t.hands(p).held == "beaker", "the beaker is in hand")
    t.click(p, 1, 2, dispenser)
    t.tick()
    t.click(p, 1, 2, dispenser)
    t.tick()
    for _, key in ipairs(keys) do
        press(key, mol)
    end
    t.ui_act(p, "toggle", '{"field":"eject"}')
    t.run_ticks(2)
end

local function onto_the_element(target_k)
    t.click(p, 3, 2, boiler)
    t.tick()
    t.click(p, 3, 2, boiler)
    t.tick()
    t.ui_act(p, "set", '{"field":"temperature","value":' .. target_k .. '}')
    t.run_ticks(2)
    if t.ui(p).toggles[1].on ~= true then
        t.ui_act(p, "toggle", '{"field":"power"}')
        t.run_ticks(2)
    end
    assert(t.ui(p).toggles[1].on == true, "the element is on")
end

local function held(handle, key)
    return (t.contents(handle) or {})[key] or 0.0
end

local function vapour(key)
    local n = 0.0
    for _, tile in ipairs(ROOM) do
        local gases = t.room_gas(tile[1], tile[2])
        n = n + ((gases and gases[key]) or 0.0)
    end
    return n
end

-- The mole fraction of ethanol in a two-component mixture: what a
-- still is measured in, on both sides of it.
local function ethanol_share(spirit, wet)
    assert(spirit + wet > 0.0, "there is something to take a fraction of")
    return spirit / (spirit + wet)
end

-- ---------------------------------------------------------------
-- ONE: THE ONSET, AND WHY IT IS 351.5 K.
--
-- The element is dialled to 380 K, which is twenty-eight kelvin over
-- ethanol's boiling point and seven over water's, so nothing about
-- what follows is the DIAL running out of range. The beaker stalls
-- because it is boiling, and it stalls where its own vapour pressure
-- equals the pressure the closet is holding it under.
-- ---------------------------------------------------------------
bench()
charge({ "ethanol" }, 0.4)
onto_the_element(380)
t.run_seconds(40)

local plateau = t.holder_k(pot)
local ambient = t.room_pressure(3, 2)
local onset = ethanol_boil_k(ambient, 1.0)
assert(math.abs(onset - 351.5) < 0.5,
    "the closet is at one atmosphere, so the onset IS the authored boiling point: " .. onset)
-- Three kelvin of slack, and the arithmetic says where it comes from:
-- the element works four times for every once the phase sweep runs
-- (ATMOS_EVERY = 10 ticks against METABOLISM_EVERY = 40,
-- lunatic-core/src/lib.rs), so a reading taken between sweeps catches
-- a beaker that has been warmed but not yet boiled back down. It is a
-- plateau with a sawtooth on it, not a flat line.
assert(math.abs(plateau - onset) < 3.0,
    "and the beaker sits on it rather than climbing to the dial: "
        .. plateau .. " vs " .. onset)
assert(plateau < 360.0, "twenty kelvin under the dial: " .. plateau)

local boiled_off = 0.4 - held(pot, "ethanol")
assert(boiled_off > 0.02, "and it is really boiling: " .. boiled_off .. " mol gone")
assert(vapour("ethanol") > 0.02, "into the room, which is where a still's vapour goes")

-- Below the onset there is no still. The same beaker, the same
-- element, twenty kelvin lower: what leaves is evaporation off a
-- surface rather than a boil, and it is an order of magnitude slower.
bench()
charge({ "ethanol" }, 0.4)
onto_the_element(330)
t.run_seconds(40)
assert(t.holder_k(pot) < 335.0, "the cool bench never reaches the onset: " .. t.holder_k(pot))
local seeped = 0.4 - held(pot, "ethanol")
assert(seeped * 5.0 < boiled_off,
    "and it gives up a fraction of what the boiling one does: "
        .. seeped .. " vs " .. boiled_off)

-- ---------------------------------------------------------------
-- TWO: THE SEPARATION.
--
-- Half a mole each. Raoult on the evaporating side means the ethanol
-- and the water each push at their own vapour pressure times their own
-- share of the liquid, and at these temperatures ethanol's line is
-- three or four times water's -- so the closet fills with something
-- much stronger than what is in the beaker, and the beaker gets
-- weaker as it goes. Two numbers, moving apart.
-- ---------------------------------------------------------------
bench()
charge({ "ethanol", "water" }, 0.4)
local started = ethanol_share(held(pot, "ethanol"), held(pot, "water"))
assert(math.abs(started - 0.5) < 0.01, "the wash starts half and half: " .. started)

-- The bubble point of the MIXTURE is between the two pure ones, which
-- is Raoult said as a temperature: neither component can reach one
-- atmosphere on its own share of the liquid, so the pot has to go
-- hotter than pure ethanol would and cannot reach where pure water
-- would.
onto_the_element(380)
t.run_seconds(60)
local pot_k = t.room_pressure(3, 2)
assert(t.holder_k(pot) > ethanol_boil_k(pot_k, 1.0),
    "a wash boils hotter than the spirit in it: " .. t.holder_k(pot))
assert(t.holder_k(pot) < water_boil_k(pot_k, 1.0) + 3.0,
    "and no hotter than the water in it: " .. t.holder_k(pot))

local booked = t.matter_totals()

-- Sampled four times over ten minutes, because a still is a thing that
-- RUNS: the claim is not "the first breath was strong" but that the
-- take-off is stronger than the pot at every moment, and that the pot
-- is being left behind.
local first_take = 0.0
local weakest_take = 1.0
for sample = 1, 4 do
    t.run_seconds(150)
    local take = ethanol_share(vapour("ethanol"), vapour("water"))
    local left = ethanol_share(held(pot, "ethanol"), held(pot, "water"))
    assert(take > left + 0.05,
        "the take-off is stronger than the pot: " .. take .. " vs " .. left)
    if sample == 1 then
        first_take = take
    end
    weakest_take = math.min(weakest_take, take)
end
-- The FIRST cut is the strong one, and it weakens: a still with no
-- condenser on it fills its own vapour space, and a closet that is
-- already holding the spirit it took off has nowhere to put more of
-- it. That is a still without a receiver rather than a still that
-- stopped working -- the pot goes on getting weaker either way, which
-- is the assertion under this one.
assert(first_take > 0.65, "the first cut is nearly two thirds spirit: " .. first_take)
assert(weakest_take > 0.53, "and even the last of it is over half: " .. weakest_take)

local finished = ethanol_share(held(pot, "ethanol"), held(pot, "water"))
assert(finished < started - 0.03,
    "the pot was left weaker than it started: " .. started .. " -> " .. finished)
assert(held(pot, "ethanol") > 0.0, "with spirit still in it to take off")

-- ---------------------------------------------------------------
-- THREE: THE BOOKS.
--
-- Nothing was made and nothing was destroyed: ethanol and water have
-- no reaction between them in this pack, nothing was pressed after the
-- baseline, and a mole that boiled is the same mole in the room. The
-- ENERGY book is not asserted here and the reason is stated rather
-- than skipped: the element is a virtual bath and mints joules on
-- purpose (sim/virtual_bath.rs), which is what a heater IS.
-- ---------------------------------------------------------------
local closed = t.matter_totals()
local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end
near(closed.substances.ethanol, booked.substances.ethanol, 1e-9,
    "every mole of spirit is still in the room somewhere")
near(closed.substances.water, booked.substances.water, 1e-9, "and every mole of water")
near(closed.moles, booked.moles, 1e-9, "and the station's whole matter book closes")
