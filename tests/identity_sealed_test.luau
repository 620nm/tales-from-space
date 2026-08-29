-- IDENTITY: a sealed bottle of water, heated, and the gauge that only
-- ever goes up.
--
-- The claim is about CHATTER. The old phase step boiled at the 1 atm
-- boiling point whatever the vessel read, and condensed everything
-- under it: put a corked bottle of water on an element and the two
-- branches fought each other, boiling a slug of steam one pass and
-- raining it back the next, forever. The gauge a crewman watched
-- sawed. There is no fight now -- the boil branch reads the pressure
-- the liquid actually bears (its own, under a lid: `BoilAgainst::Own`,
-- docs/MATTER.md) and the saturation branch reads the same line -- so
-- a bottle warming under a lid climbs its own vapour curve and stays
-- on it.
--
-- Twenty sweeps, sampled on the sweep's own cadence, and the assertion
-- is MONOTONE: not "ends
-- higher", which one boil and one rain would also satisfy, but "never
-- once went down".
--
-- ...and the books. `t.matter_totals` is the whole station's matter in
-- one reading -- every cell, the vented register, every vessel and
-- every bloodstream (sim/holder_kinds.rs). Nothing in this file
-- reacts, so its moles are a constant; the element mints joules by
-- design (the virtual bath, sim/virtual_bath.rs), so the energy book
-- is asserted with the power OFF.

-- ONE PHASE SWEEP, in ticks. Every holder on the station settles its
-- phases on the metabolism cadence (METABOLISM_EVERY = 40 ticks,
-- lunatic-core/src/lib.rs; sim/tick.rs runs `resolve_metabolism`
-- there), which is the clock a gauge over a vessel actually moves on
-- -- the element under it works four times as often, at the atmos
-- cadence, so a sample taken between sweeps catches a bottle that has
-- been warmed but not yet relaxed.
local SWEEP = 40

-- Clausius-Clapeyron for water, off the substance file's own numbers
-- (substances/water.luau: boil 373.15 K, l_vap 40 660 J/mol), so the
-- assertion is against the curve the registry built and not a number
-- typed twice. P(T) = p_a * exp(k * (1/T - 1/T_a)), k = -L/R.
local ONE_ATM_PA = 101325.0
local WATER_TB = 373.15
local WATER_K = -40660.0 / 8.314462618

local function vapour_kpa(temp_k)
    return ONE_ATM_PA * math.exp(WATER_K * (1.0 / temp_k - 1.0 / WATER_TB)) / 1000.0
end

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

t.world([==[(
    name: "the pressure bench",
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
        "#oag#",
        "#...#",
        "#####",
    ],
    spawns: [(2, 1)],
    items: [(1, 1, "bottle")],
    machines: [(1, 2, "chem_dispenser"), (3, 2, "chem_heater")],
    cables: [
        (1, 1, 1, 0, 2), (1, 1, 1, 0, 4), (1, 1, 2, 0, 2), (1, 1, 2, 0, 4),
        (2, 1, 1, 0, 2), (2, 1, 1, 0, 4), (2, 1, 1, 0, 8), (2, 1, 2, 0, 2),
        (2, 1, 2, 0, 4), (2, 1, 2, 0, 8), (3, 1, 1, 0, 2), (3, 1, 1, 0, 8),
        (3, 1, 2, 0, 2), (3, 1, 2, 0, 8),
        (1, 2, 1, 0, 1), (1, 2, 1, 0, 4), (1, 2, 2, 0, 1), (1, 2, 2, 0, 4),
        (2, 2, 1, 0, 1), (2, 2, 1, 0, 4), (2, 2, 1, 0, 8), (2, 2, 2, 0, 1),
        (2, 2, 2, 0, 4), (2, 2, 2, 0, 8), (3, 2, 1, 0, 1), (3, 2, 1, 0, 8),
        (3, 2, 2, 0, 1), (3, 2, 2, 0, 8),
    ],
)]==], 0)

local p = t.join()
t.tick()

local dispenser = t.target_at(1, 2)
local heater = t.target_at(3, 2)
local jar = t.target_at(1, 1, "bottle")

local function gas_in(handle, key)
    local entry = t.vessel(handle).contents[key]
    return entry and (entry.gas or 0.0) or 0.0
end

local function liquid_in(handle, key)
    local entry = t.vessel(handle).contents[key]
    return entry and (entry.liquid or 0.0) or 0.0
end

-- ---------------------------------------------------------------
-- ONE: A MOLE OF WATER, WITH THE STOPPER IN.
-- ---------------------------------------------------------------
t.click(p, 1, 1, jar)
t.tick()
assert(t.hands(p).held == "bottle", "the bottle is in hand")
t.click(p, 1, 2, dispenser)
t.tick()
t.click(p, 1, 2, dispenser)
t.tick()
t.ui_act(p, "set", '{"field":"amount","value":1.0}')
t.run_ticks(2)
t.ui_act(p, "toggle", '{"field":"dispense","option":"water"}')
t.run_ticks(2)
near(t.contents(jar).water, 1.0, 1e-9, "a mole of water, and the dial's whole press landed")
-- All but a whisker of it is LIQUID: a source chooses no phase (D11)
-- and water at 300 K and one atmosphere rests as a liquid, so what a
-- press of water into a bottle puts there is water rather than steam.
-- The whisker is the vessel's own headspace coming to saturation, and
-- it is the thing the next section watches grow.
assert(liquid_in(jar, "water") > 0.999, "and it is liquid: " .. liquid_in(jar, "water"))
t.ui_act(p, "toggle", '{"field":"eject"}')
t.run_ticks(2)

-- A mole is 18 mL of the bottle's fifty, so there is headspace over it
-- and the gauge below is reading a real one.
assert(t.vessel(jar).headspace_l > 0.02, "and there is room over it: "
    .. t.vessel(jar).headspace_l .. " L")

-- ---------------------------------------------------------------
-- TWO: ON THE ELEMENT, AND TWENTY SWEEPS OF THE GAUGE.
--
-- 450 K rather than something dramatic: the bottle is unrated glass,
-- and water's own vapour pressure at 450 K is about nine and a half
-- atmospheres -- a pressure vessel rather than a bomb, and the whole
-- of what a lid buys.
-- ---------------------------------------------------------------
t.click(p, 3, 2, heater)
t.tick()
t.click(p, 3, 2, heater)
t.tick()
t.ui_act(p, "set", '{"field":"temperature","value":450}')
t.run_ticks(2)
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.ui(p).toggles[1].on == true, "the element is on")

local before = t.matter_totals()

local kpa = t.holder_kpa(jar)
local steam = gas_in(jar, "water")
local climbed = 0
for sweep = 1, 20 do
    t.run_ticks(SWEEP)
    local now_kpa = t.holder_kpa(jar)
    local now_steam = gas_in(jar, "water")
    -- A kilopascal in ten thousand is under the resolution of any
    -- gauge; a CHATTERING bottle fell by whole atmospheres a pass.
    assert(now_kpa >= kpa - 1e-6,
        "sweep " .. sweep .. ": the gauge went DOWN, " .. kpa .. " -> " .. now_kpa)
    assert(now_steam >= steam - 1e-12,
        "sweep " .. sweep .. ": the steam RAINED, " .. steam .. " -> " .. now_steam)
    if now_kpa > kpa then
        climbed = climbed + 1
    end
    kpa, steam = now_kpa, now_steam
end
assert(climbed >= 15, "and it was climbing, not flat: " .. climbed .. " sweeps of 20")

-- Both phases are still in there, which is what makes the reading a
-- SATURATION pressure rather than an ideal-gas one.
assert(liquid_in(jar, "water") > 0.5, "most of it is still liquid")
assert(gas_in(jar, "water") > 0.0, "with its own vapour over it")

-- ...and the gauge is ON the curve the substance file authored. Two
-- per cent of slack, and what it is for is the last of the approach:
-- the element closes a fixed share of the gap every pass, so the
-- bottle is always a shade under the dial and the vapour a shade
-- behind the bottle.
local warmth = t.holder_k(jar)
local want = vapour_kpa(warmth)
assert(math.abs(t.holder_kpa(jar) - want) < 0.02 * want,
    "the gauge is water's own vapour pressure at " .. warmth .. " K: "
        .. t.holder_kpa(jar) .. " vs " .. want)

-- ---------------------------------------------------------------
-- THREE: THE BOOKS.
--
-- MOLES first, and they hold across the whole heating run: nothing in
-- this bottle reacts, nothing was pressed after the baseline, and a
-- mole that boils is the same mole in a different phase.
-- ---------------------------------------------------------------
local after = t.matter_totals()
near(after.moles, before.moles, 1e-9, "not one mole was made or lost while it heated")
near(after.substances.water, before.substances.water, 1e-9, "the water is all still water")

-- ENERGY with the element OFF. The bath mints joules while it is on
-- (that is what a heater IS, and sim/virtual_bath.rs owns the
-- non-conservation); switched off, the only things left moving energy
-- are conserving ones -- the deck conducting with the glass standing
-- on it, the air conducting with the deck, and the hull radiating,
-- which `t.matter_totals().energy_j` books back in through
-- `space_radiated`. So the whole station's energy is a constant, and
-- one joule of slack out of the tens of millions this room holds.
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
t.ui_act(p, "toggle", '{"field":"eject"}')
t.run_ticks(2)
t.drop(p)
t.tick()

local cold_start = t.matter_totals()
t.run_seconds(60)
local cold_end = t.matter_totals()
near(cold_end.moles, cold_start.moles, 1e-9, "still not one mole made or lost")
near(cold_end.energy_j, cold_start.energy_j, 1.0, "and not one joule either")
