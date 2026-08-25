-- How a permanent gas gets into a bottle, and what it is for.
--
-- Oxygen, nitrogen, hydrogen and fluorine left the dispenser shelf when
-- the twins were folded: they rest as gas at every temperature a nozzle
-- reaches, so a press of one over an open glass is a press into the
-- room (docs/CHEMISTRY.md 11). What is left is the canister, and the
-- gesture that reaches it is a corked vessel held against the valve
-- (items/bottle.luau) -- a `sim.matter.transfer` with `phases =
-- { "gas" }` and the ends pointed the other way, which is all a charge
-- ever was.
--
-- Two recipes stand behind this and cannot be reached without it:
-- carbon dioxide wants fifty kilopascals of oxygen over solid carbon,
-- nitrous oxide a hundred over liquid ammonia. Both gates are
-- ATMOSPHERES rather than quantities, which is the thing a mole count
-- cannot say and the reason the milestone folded the shelf at all.

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function said(p, want)
    for _, m in ipairs(t.messages(p)) do
        if m == want then
            return true
        end
    end
    return false
end

-- Every reading here comes off `t.vessel`, which answers the same shape
-- for a bottle and for a canister because both ARE one Mixture in a
-- known volume (docs/CHEMISTRY.md 1). `t.holder_kpa` would only reach
-- half of them.
local function vessel(handle)
    local reading = t.vessel(handle)
    assert(reading ~= nil, "that is a vessel")
    return reading
end

local function gas(handle, key)
    local entry = vessel(handle).contents[key]
    return entry and (entry.gas or 0.0) or 0.0
end

-- ---------------------------------------------------------------
-- ONE: THE GESTURE.
--
-- A canister charged to twenty atmospheres, a bottle with a stopper in
-- it, and one click. What lands is what the ideal gas law says lands:
-- the bottle's own headspace standing at the line's pressure, and not
-- one mole more.
-- ---------------------------------------------------------------
t.world([==[(
    name: "supply bay",
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#...#",
        "#####",
    ],
    spawns: [(2, 1)],
    items: [(1, 1, "bottle"), (3, 1, "beaker")],
    structures: [
        (2, 2, "canister"),
    ],
)]==], 0)

local p = t.join()
t.tick()

local can = t.target_at(2, 2)
assert(can ~= nil, "a canister stands on the deck")
assert(t.charge_vessel(2, 2, "o2", 2000.0), "and it takes a charge")
t.tick()
near(t.canister_pressure(2, 2), 2000.0, 1.0, "twenty atmospheres of oxygen")

local jar = t.target_at(1, 1, "bottle")
t.click(p, 1, 1, jar)
t.tick()
assert(t.hands(p).held == "bottle", "the bottle is in hand")
near(vessel(jar).pressure_kpa, 0.0, 1e-9, "and it is empty, so its gauge reads nothing")

local can_before = gas(can, "o2")
local _ = t.messages(p)
t.click(p, 2, 2, can)
t.run_ticks(2)

-- The gauge is the assertion, because the gauge is what a crewman
-- reads. Two atmospheres of slack out of twenty: the parcel arrives at
-- the canister's own temperature and the projection floor
-- (MIN_HEADSPACE_FRACTION) is not in play at this fill.
near(vessel(jar).pressure_kpa, 2000.0, 20.0, "the bottle came up to the line")
assert(gas(jar, "o2") > 0.0, "and what is in it is the line's oxygen")

-- Nothing was made and nothing was lost: one transfer, two owners.
near(gas(can, "o2") + gas(jar, "o2"), can_before, 1e-9,
    "every mole that left the canister is in the bottle")
assert(said(p, "You hold the bottle to the valve until it stops hissing."),
    "and the gesture says what it did")

-- A second click moves nothing: the two are level, and the file says so
-- rather than transferring a silent zero.
_ = t.messages(p)
local charged = gas(jar, "o2")
t.click(p, 2, 2, can)
t.run_ticks(2)
near(gas(jar, "o2"), charged, 1e-9, "a bottle at the line's pressure takes no more")
assert(said(p, "The bottle is already at the line's pressure."), "and it says why")

-- ...AND THE OPEN GLASS, WHICH IS THE POINT OF THE LID.
t.drop(p)
t.tick()
local glass = t.target_at(3, 1, "beaker")
t.click(p, 3, 1, glass)
t.tick()
assert(t.hands(p).held == "beaker", "the beaker is in hand")
_ = t.messages(p)
t.click(p, 2, 2, can)
t.run_ticks(2)
near(gas(glass, "o2"), 0.0, 1e-12, "an open beaker takes none of it")
assert(said(p, "That would only escape: seal a vessel first."),
    "and it is refused in the dispenser's own words")

-- ---------------------------------------------------------------
-- TWO: WHAT IT IS FOR -- THE TWO GAS-SHARE RECIPES.
--
-- Both of them stand on a gas the dispenser no longer offers, and
-- both state their requirement as a PARTIAL PRESSURE rather than a
-- quantity, which is the thing a mole count cannot say:
--
--   carbon_dioxide   C + O2 -> CO2        777/782/900/920, o2 >= 50 kPa
--   nitrous_oxide    2 NH3 + 2 O2         525/550/575/600, o2 >= 100 kPa
--                      -> N2O + 3 H2O
--
-- One bench, four bottles, and one variable: what the line was holding
-- when the bottle was charged. Every bottle goes to the same dial as
-- its twin, so the window is open in all four; only the two charged
-- off the full canister make anything.
--
-- The order of the bench run is CHARGE FIRST. A bottle that has just
-- taken a mole of ammonia is standing at hundreds of atmospheres of
-- its own vapour under its own condensation heat, and no canister on
-- this deck can push gas into that -- so the oxygen goes in while the
-- glass is empty and cold, which is also the order a chemist would
-- work out in about ten seconds.
-- ---------------------------------------------------------------
t.world([==[(
    name: "chem bench and its supply",
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "#########",
        "#o.....g#",
        "#.......#",
        "#..a....#",
        "#########",
    ],
    spawns: [(3, 2)],
    items: [
        (1, 3, "bottle"), (2, 3, "bottle"),
        (4, 3, "bottle"), (5, 3, "bottle"),
    ],
    machines: [(1, 2, "chem_dispenser"), (6, 2, "chem_heater")],
    structures: [(2, 1, "canister"), (4, 1, "canister")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3), (7, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3), (7, 2, 3),
        (1, 3, 3), (2, 3, 3), (3, 3, 3), (4, 3, 3), (5, 3, 3), (6, 3, 3), (7, 3, 3),
    ],
)]==], 0)

p = t.join()
t.tick()

local dispenser = t.target_at(1, 2)
local heater = t.target_at(6, 2)
assert(dispenser ~= nil and heater ~= nil, "the bench is set")
-- The full line, and the one that is nearly empty. Twenty atmospheres
-- is a quarter of what a supply bottle ships holding (docs/ATMOS.md 9),
-- so neither of these is a pressure a crewman could not meet.
assert(t.charge_vessel(2, 1, "o2", 2000.0), "one canister is charged")
assert(t.charge_vessel(4, 1, "o2", 10.0), "and one is all but empty")
t.tick()

-- A crewman walks. Nothing below is a teleport: every click is made
-- from a tile the player actually stood on.
-- Greedy, and it tries the other axis when a machine is in the way --
-- the dispenser stands in the corridor, so a walker that only ever
-- closed x first would put its nose against it and stay there.
local function walk_to(tx, ty)
    for _ = 1, 40 do
        local x, y = t.pos(p)
        if x == tx and y == ty then
            return
        end
        local tries = {}
        if x < tx then
            table.insert(tries, "east")
        elseif x > tx then
            table.insert(tries, "west")
        end
        if y < ty then
            table.insert(tries, "south")
        elseif y > ty then
            table.insert(tries, "north")
        end
        for _, dir in ipairs(tries) do
            t.move(p, dir)
            t.run_ticks(6)
            local nx, ny = t.pos(p)
            if nx ~= x or ny ~= y then
                break
            end
        end
    end
    local x, y = t.pos(p)
    if x ~= tx or y ~= ty then
        error("could not walk to " .. tx .. ", " .. ty)
    end
end

local function panel(mx, my, machine)
    t.click(p, mx, my, machine)
    t.tick()
end

local function condensed(handle, key)
    local entry = vessel(handle).contents[key]
    if entry == nil then
        return 0.0
    end
    return (entry.solid or 0.0) + (entry.liquid or 0.0)
end

-- The bench run: charge off the line, press the reagent in, put it on
-- the element. Answers the bottle, still docked and still hot.
local function bake(bx, by, cx, key, mol, target_k, seconds)
    walk_to(bx, by)
    local jar = t.target_at(bx, by, "bottle")
    assert(jar ~= nil, "there is a bottle at " .. bx .. ", " .. by)
    t.click(p, bx, by, jar)
    t.tick()
    assert(t.hands(p).held == "bottle", "and it is in hand")

    -- The oxygen, which no button on that shelf can give it.
    walk_to(cx, 2)
    t.click(p, cx, 1, t.target_at(cx, 1))
    t.run_ticks(2)
    local charge = gas(jar, "o2")
    assert(charge > 0.0, "the bottle came away with oxygen in it")

    -- The reagent, through the dock, at the dial.
    walk_to(2, 2)
    panel(1, 2, dispenser)
    panel(1, 2, dispenser)
    t.ui_act(p, "set", '{"field":"amount","value":' .. mol .. '}')
    t.run_ticks(2)
    t.ui_act(p, "toggle", '{"field":"dispense","option":"' .. key .. '"}')
    t.run_ticks(4)
    t.ui_act(p, "toggle", '{"field":"eject"}')
    t.run_ticks(2)
    assert(t.hands(p).held == "bottle", "the bottle comes back out")
    near(condensed(jar, key) + gas(jar, key), mol, 1e-9,
        "carrying the " .. key .. " the dial asked for")

    -- Onto the element, and up to the window.
    walk_to(5, 2)
    panel(6, 2, heater)
    panel(6, 2, heater)
    t.ui_act(p, "set", '{"field":"temperature","value":' .. target_k .. '}')
    if t.ui(p).toggles[1].on ~= true then
        t.ui_act(p, "toggle", '{"field":"power"}')
    end
    t.run_ticks(2)
    assert(t.ui(p).toggles[1].on == true, "the element is on")
    t.run_seconds(seconds)
    return jar, charge
end

-- Off the element and out of the way, so the next bottle gets its turn.
local function unload()
    if t.ui(p).toggles[1].on == true then
        t.ui_act(p, "toggle", '{"field":"power"}')
        t.run_ticks(2)
    end
    t.ui_act(p, "toggle", '{"field":"eject"}')
    t.run_ticks(2)
    t.drop(p)
    t.tick()
end

-- ---- CARBON DIOXIDE, CHARGED ----
local hot, hot_o2 = bake(1, 3, 2, "carbon", 0.1, 800, 240)
assert(t.holder_k(hot) > 770.0, "the chamber got there: " .. t.holder_k(hot))
local made = gas(hot, "co2")
assert(made > 0.03, "and the charged bottle made carbon dioxide: " .. made .. " mol")
-- One carbon and one oxygen per molecule: the atoms balance, so the
-- bookkeeping does too. The charge is the limiting side -- a tenth of a
-- mole of powder against four hundredths of a mole of gas -- so the run
-- ends when the oxygen does.
near(0.1 - condensed(hot, "carbon"), made, 1e-6, "one carbon spent per molecule made")
near(hot_o2 - gas(hot, "o2"), made, 1e-6, "and one oxygen with it")
unload()

-- ---- CARBON DIOXIDE, THIN ----
local thin = bake(2, 3, 4, "carbon", 0.1, 800, 240)
assert(t.holder_k(thin) > 770.0, "the same chamber, the same dial: " .. t.holder_k(thin))
near(gas(thin, "co2"), 0.0, 1e-12, "and a thin charge makes nothing at all")
near(condensed(thin, "carbon"), 0.1, 1e-9, "spending none of its carbon")
unload()

-- ---- NITROUS OXIDE, CHARGED ----
--
-- A mole of ammonia, which the dispenser hands over as gas at 300 K
-- (a source chooses no phase, D11) and the bottle condenses under its
-- own vapour pressure the moment the lid is on. That condensation
-- heat is why the glass arrives at the element hot rather than cold,
-- and why the dial below is a CEILING the chamber pulls it down to.
local sweet, sweet_o2 = bake(4, 3, 2, "ammonia", 1.0, 530, 600)
assert(t.holder_k(sweet) > 520.0 and t.holder_k(sweet) < 610.0,
    "the chamber holds it in tg's window: " .. t.holder_k(sweet))
assert(vessel(sweet).contents.ammonia.liquid ~= nil,
    "and there is still LIQUID ammonia in it, which is the phase the recipe names")
local sleepy = gas(sweet, "n2o")
assert(sleepy > 1e-6, "the charged bottle made nitrous oxide: " .. sleepy .. " mol")
-- Two oxygen per molecule of it, and nothing else in this bottle
-- spends oxygen: the charge is the limiting side again, so the run
-- ends when the last of it goes.
near((sweet_o2 - gas(sweet, "o2")) / 2.0, sleepy, 1e-6, "two oxygen per molecule made")

-- The three waters are real, and they do not stay water: the janitor's
-- own recipe is open across this whole window (reactions/
-- space_cleaner.luau, 100/280/900/1000) and there are half a mole of
-- liquid ammonia standing over them, so what a bottle of nitrous
-- actually ends up holding is cleaner. That is one id per molecule
-- doing what it was folded for -- nothing here is a second ammonia
-- that only some recipes can see.
assert(condensed(sweet, "space_cleaner") > 0.0,
    "and the water it made went straight on into cleaner")
unload()

-- ---- NITROUS OXIDE, THIN ----
--
-- Twenty-three kilopascals of oxygen at temperature, against a gate
-- that asks for a hundred. There are MOLES of it -- the same order of
-- magnitude the carbon dioxide bottle ran on -- and the same moles in
-- a smaller bottle would pass. That is the gate a mole count cannot
-- express (docs/CHEMISTRY.md 5).
local flat = bake(5, 3, 4, "ammonia", 1.0, 530, 600)
assert(t.holder_k(flat) > 520.0 and t.holder_k(flat) < 610.0,
    "the same chamber, the same dial: " .. t.holder_k(flat))
near(gas(flat, "n2o"), 0.0, 1e-12, "a thin oxygen share makes none of it")
assert(gas(flat, "o2") > 0.0, "and spends none of the oxygen it does have")

