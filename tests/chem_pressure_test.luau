-- What a LID buys, and what only a canister can.
--
-- Three of this pack's recipes name a phase no open beaker can hold.
-- Ammonia is made out of two permanent gases at a pressure and a
-- temperature; space cleaner is made out of LIQUID ammonia, which
-- exists only under a lid. Neither is bench work in the sense the rest
-- of the chemistry specs are, and both are the point of one id per
-- molecule: a substance is what it is, and a recipe says which phase it
-- means (docs/CHEMISTRY.md 3).
--
-- The old shelf hid all of this. `hydrogen` was a single atom you could
-- keep in a beaker, `ammonia` was a room-temperature liquid because
-- tg's is, and the Haber process was three presses and a stir. What is
-- here instead is a pressure vessel.

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

-- ---------------------------------------------------------------
-- ONE: THE HABER PROCESS, IN A BOTTLE OF GAS.
--
-- tg: 3 hydrogen + 1 nitrogen -> 3 ammonia, untemperatured
-- (recipes/others.dm:433-441). Read as molecules that is
-- N2 + 3 H2 -> 2 NH3, and the file states it per mole of product
-- (reactions/ammonia.luau). The window is 600/650/800/850, and the
-- gates are partial PRESSURES rather than quantities -- a hundred
-- kilopascals of nitrogen and three hundred of hydrogen, which is the
-- 1:3 stoichiometry read off a gauge and which no room on the station
-- is anywhere near.
--
-- Three bays behind three walls, three bottles, and one variable each:
--
--   A (1, 1) -- hot and charged: it runs.
--   B (3, 1) -- the same charge at room temperature: the window is shut.
--   C (5, 1) -- hot, but thin on hydrogen: the gate is shut.
--
-- The canister shell is 2 m3 and a recipe is moles PER TILE, so 40 in
-- the file is 80 mol in the bottle: 80 x 8.314 x 700 / 2 = 233 kPa of
-- nitrogen, and 240 mol of hydrogen is 698 kPa. Bay C gets a sixth of
-- the hydrogen, 116 kPa, which is under the gate and over nothing.
-- ---------------------------------------------------------------
t.world([==[(
    name: "three pressure bays",
    legend: {
        '.': (turf: Plating),
        '#': (turf: Wall),
    },
    rows: [
        "########",
        "#.#.#.##",
        "########",
    ],
    spawns: [(1, 1)],
    air_presets: {
        "haber": (gases: [("n2", 40.0), ("hydrogen", 120.0)], temperature_k: 700.0),
        "cold_haber": (gases: [("n2", 40.0), ("hydrogen", 120.0)], temperature_k: 293.15),
        "thin_haber": (gases: [("n2", 40.0), ("hydrogen", 20.0)], temperature_k: 700.0),
    },
    structures: [
        (1, 1, "canister", { "air": "haber" }),
        (3, 1, "canister", { "air": "cold_haber" }),
        (5, 1, "canister", { "air": "thin_haber" }),
    ],
)]==], 7)

t.tick()

local function bottle(x)
    local reading = t.vessel(t.target_at(x, 1, "canister"))
    assert(reading ~= nil, "a canister stands at " .. x)
    return reading
end

local function held(x, key)
    local entry = bottle(x).contents[key]
    return entry and (entry.gas or 0.0) or 0.0
end

-- Nothing has had time to happen yet, and the charges are what the map
-- said. A canister is a rigid shell that takes the same step a beaker
-- takes (docs/CHEMISTRY.md 1), so the only reason A is different from
-- B is the number beside `temperature_k`.
near(held(1, "n2"), 80.0, 1e-6, "eighty moles of nitrogen in bay A")
near(held(1, "hydrogen"), 240.0, 1e-6, "and two hundred and forty of hydrogen")
near(held(1, "ammonia"), 0.0, 1e-12, "and none of the product yet")

t.run_seconds(120)

-- ---- A: it runs ----
local made = held(1, "ammonia")
assert(made > 0.05, "the hot charged bottle made ammonia: " .. made .. " mol")

-- Stoichiometry, off the bottle's own numbers: half a mole of nitrogen
-- and one and a half of hydrogen for every mole of ammonia.
near(80.0 - held(1, "n2"), 0.5 * made, 1e-6, "half a nitrogen per ammonia")
near(240.0 - held(1, "hydrogen"), 1.5 * made, 1e-6, "and three halves of hydrogen")

-- The synthesis is exothermic -- 46 kJ per mole of ammonia, the real
-- enthalpy of formation with this engine's sign on it
-- (docs/CHEMISTRY.md 6) -- so the bottle it happens in gets warmer than
-- the bottle it started in.
assert(bottle(1).temp_k > 700.0, "and it warmed the bottle: " .. bottle(1).temp_k)

-- ---- B: the window is shut ----
--
-- The identical charge at room temperature. The bell is exactly zero
-- below `temp_min`, so this is not "slower", it is NOTHING.
near(held(3, "ammonia"), 0.0, 1e-12, "cold makes no ammonia at all")
near(held(3, "n2"), 80.0, 1e-6, "and spends none of its nitrogen doing it")

-- ---- C: the gate is shut ----
--
-- Hot enough, and stocked with both reactants -- 116 kPa of hydrogen is
-- forty moles, which is plenty of MOLES. What it is not is an
-- ATMOSPHERE of hydrogen, and that is what a partial-pressure gate
-- asks about: the same forty moles in a smaller bottle would pass it.
-- This is the gate a mole count cannot express (docs/CHEMISTRY.md 5).
near(held(5, "ammonia"), 0.0, 1e-12, "a thin hydrogen share makes none either")
near(held(5, "hydrogen"), 40.0, 1e-6, "and spends none of it")
near(held(5, "n2"), 80.0, 1e-6, "nor any of the nitrogen it has plenty of")

-- ---------------------------------------------------------------
-- TWO: AND THE LIQUID, WHICH IS THE SAME SUBSTANCE.
--
-- Space cleaner: 1 ammonia + 1 water -> 2 cleaner
-- (recipes/others.dm:448-452), and the ammonia it names is the LIQUID.
-- There is one ammonia, so the liquid is not a second reagent with the
-- same name -- it is this one, standing under enough of its own vapour
-- pressure to be a liquid, which is about 8.6 atm at room temperature.
--
-- Which means the janitor's supply chain is: press ammonia into a
-- bottle, let the condensation heat out, press water in after it. The
-- press over an open beaker is refused and says why (D19), so the
-- bottle is not a convenience.
-- ---------------------------------------------------------------
t.world([==[(
    name: "janitor's bench",
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
        (1, 1, 1, 2, 4), (1, 1, 2, 2, 4), (2, 1, 1, 0, 2), (2, 1, 1, 0, 4),
        (2, 1, 1, 0, 8), (2, 1, 2, 0, 2), (2, 1, 2, 0, 4), (2, 1, 2, 0, 8),
        (3, 1, 1, 0, 2), (3, 1, 1, 0, 8), (3, 1, 2, 0, 2), (3, 1, 2, 0, 8),
        (1, 2, 1, 0, 1), (1, 2, 1, 0, 4), (1, 2, 2, 0, 1), (1, 2, 2, 0, 4),
        (2, 2, 1, 0, 1), (2, 2, 1, 0, 4), (2, 2, 1, 0, 8), (2, 2, 2, 0, 1),
        (2, 2, 2, 0, 4), (2, 2, 2, 0, 8), (3, 2, 1, 0, 1), (3, 2, 1, 0, 8),
        (3, 2, 2, 0, 1), (3, 2, 2, 0, 8),
    ],
)]==], 0)

local p = t.join()
t.tick()

local machine = t.target_at(2, 2)
local jar = t.target_at(1, 2, "bottle")
local glass = t.target_at(3, 2, "beaker")

local function press(key)
    t.ui_act(p, "toggle", '{"field":"dispense","option":"' .. key .. '"}')
    t.run_ticks(2)
end

local function dial_to(moles)
    t.ui_act(p, "set", '{"field":"amount","value":' .. moles .. '}')
    t.run_ticks(2)
end

local function open_panel()
    t.click(p, 2, 2, machine)
    t.tick()
end

local function eject()
    t.ui_act(p, "toggle", '{"field":"eject"}')
    t.run_ticks(2)
end

local function amount(handle, key)
    local contents = t.contents(handle)
    assert(contents ~= nil, "that is a vessel")
    return contents[key] or 0
end

local function said(want)
    for _, m in ipairs(t.messages(p)) do
        if m == want then
            return true
        end
    end
    return false
end

-- The refusal first, because it is the reason for everything after it.
t.click(p, 3, 2, glass)
t.tick()
t.click(p, 2, 2, machine)
t.tick()
open_panel()
dial_to(0.1)
local _ = t.messages(p)
press("ammonia")
near(amount(glass, "ammonia"), 0.0, 1e-12, "an open glass takes none of it")
assert(said("That would only escape: seal a vessel first."),
    "and the machine says why rather than doing nothing in silence")
eject()
t.drop(p)
t.tick()

-- ...and the identical press into something with a stopper in it.
local LEG = 0.1
t.click(p, 1, 2, jar)
t.tick()
t.click(p, 2, 2, machine)
t.tick()
open_panel()
dial_to(LEG)
press("ammonia")
t.run_seconds(20)
near(amount(jar, "ammonia"), LEG, 1e-9, "the whole press landed, because there is a lid")
local charged = t.vessel(jar)
assert((charged.contents.ammonia.liquid or 0) > 0.0,
    "and most of it is standing as LIQUID ammonia")

-- The deck takes the condensation heat back (sim/holder/heat.rs); a
-- docked or carried vessel is insulated and this one has to cool
-- before the water goes in, or the bench is chasing its own exotherm.
eject()
t.drop(p)
t.run_seconds(600)
assert(t.holder_k(jar) < 340.0, "the deck cooled it: " .. t.holder_k(jar))

t.click(p, 2, 1, jar)
t.tick()
t.click(p, 2, 2, machine)
t.tick()
open_panel()
dial_to(LEG)
press("water")
eject()
t.drop(p)
t.run_seconds(300)

-- Two of cleaner for one of each, and the clamp is whichever ran out
-- first -- they went in equal, so both do.
local cleaner = amount(jar, "space_cleaner")
assert(cleaner > 0.1, "the janitor has cleaner: " .. cleaner .. " mol")
near(amount(jar, "water"), LEG - 0.5 * cleaner, 5e-3, "one of water for two of it")
near(LEG - amount(jar, "ammonia"), 0.5 * cleaner, 5e-3, "and one of ammonia with it")
