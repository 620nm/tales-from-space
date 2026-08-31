-- IDENTITY: one carbon dioxide, in all three phases, out of one
-- canister.
--
-- CO2 is the substance the old split could not hold. tg has a
-- `/datum/gas/carbon_dioxide` in the air and a
-- `/datum/reagent/carbondioxide` in a beaker and nothing at all in
-- between, because tg's phase model is a boiling point and CO2 has no
-- boiling point: its solid's vapour pressure clears one atmosphere at
-- 194.7 K, thirty kelvin BELOW the 216.55 K triple point, so a block of
-- it on a warm deck goes straight to gas and never puddles. A `boil`
-- spelling is refused for that reason (substances/co2.luau) and the
-- file authors the triple point instead.
--
-- What that buys is this spec. One canister of the gas the station's
-- air is made of, and out of it: a bottle of LIQUID carbon dioxide
-- under five and a half megapascals, a bottle of DRY ICE at thirty
-- kilopascals, and two spills that behave completely differently on
-- the same 293 K deck. Same id, same registry row, same `co2` a
-- scrubber filters and a crewman's waste column counts.
--
-- Every number below is the substance file's own diagram evaluated in
-- Luau and compared against what the gauge reads, so nothing here is a
-- magic constant: if the file's latent heats change, this spec moves
-- with them.

-- The two Clausius-Clapeyron lines the registry builds out of
-- substances/co2.luau: triple point 216.55 K at 517 kPa, l_fus 9020,
-- l_vap 16200 J/mol. The sublimation line is Hess's law -- L_sub =
-- L_fus + L_vap -- and is never authored (docs/MATTER.md).
-- P(T) = p_a * exp(k * (1/T - 1/T_a)), k = -L/R.
local R = 8.314462618
local TRIPLE_K, TRIPLE_PA = 216.55, 517000.0
local CRITICAL_K = 304.1

local function line_kpa(latent, temp_k)
    return TRIPLE_PA * math.exp((-latent / R) * (1.0 / temp_k - 1.0 / TRIPLE_K)) / 1000.0
end

local function vapour_kpa(temp_k)
    return line_kpa(16200.0, temp_k)
end

local function sublimation_kpa(temp_k)
    return line_kpa(9020.0 + 16200.0, temp_k)
end

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

t.world([==[(
    name: "the cold bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
    },
    rows: [
        "#######",
        "#o.a..#",
        "#.....#",
        "#.....#",
        "#######",
    ],
    spawns: [(2, 2)],
    items: [(2, 3, "bottle")],
    machines: [(3, 2, "chem_heater")],
    structures: [(2, 1, "canister")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3),
    ],
)]==], 0)

-- An INERT SKY. The roster's default parks this station under a star
-- pouring 2.7 kW/m2 into the hull, which warms a sealed room by seven
-- kelvin every five minutes -- and every claim below is about a tile
-- that got COLDER. A sky at the station's own temperature radiates
-- exactly what it absorbs, which is what makes "colder than the tile
-- next to it" a statement about the dry ice rather than about the
-- clock (queries.rs, `set_environment`).
t.set_environment({ sink_k = 293.15, insolation = 0.0 })

local p = t.join()
t.tick()

local heater = t.target_at(3, 2)
local can = t.target_at(2, 1)
local jar = t.target_at(2, 3, "bottle")

local function phases(handle)
    local reading = t.vessel(handle)
    assert(reading ~= nil, "that is a vessel")
    return reading.contents.co2 or {}
end

local function solid(handle)
    return phases(handle).solid or 0.0
end

local function liquid(handle)
    return phases(handle).liquid or 0.0
end

local function gas(handle)
    return phases(handle).gas or 0.0
end

local function tile_co2(x, y)
    local gases = t.room_gas(x, y)
    return (gases and gases.co2) or 0.0
end

-- Every mole of carbon in the room's air, plus whatever the settling
-- sweep booked off a tile that went quiet holding a trace of it
-- (lunatic docs/MATTER-WORLD.md §3 step 8). Sublimated gas does not
-- stay over the ice that made it -- it crosses a link as soon as the
-- raw imbalance is worth chasing -- so what a spill weighs is the
-- ROOM's carbon and never one tile's.
local function room_co2()
    local n = t.nullified().co2 or 0.0
    for x = 1, 5 do
        for y = 1, 3 do
            n = n + tile_co2(x, y)
        end
    end
    return n
end

-- Dock the bottle, dial the chamber, and let it get there. The
-- thermostat works both ways -- it closes a fixed share of the gap to
-- the setpoint every pass, from whichever side it is on
-- (sim/holder/heat.rs) -- so the reaction chamber is the station's
-- refrigerator as well as its hotplate, and no second machine has to
-- exist for this spec to be reachable.
local function condition(target_k, secs)
    t.click(p, 3, 2, heater)
    t.tick()
    t.click(p, 3, 2, heater)
    t.tick()
    t.ui_act(p, "set", '{"field":"temperature","value":' .. target_k .. '}')
    t.run_ticks(2)
    if t.ui(p).toggles[1].on ~= true then
        t.ui_act(p, "toggle", '{"field":"power"}')
    end
    t.run_ticks(2)
    t.run_seconds(secs)
end

local function undock()
    if t.ui(p).toggles[1].on == true then
        t.ui_act(p, "toggle", '{"field":"power"}')
        t.run_ticks(2)
    end
    t.ui_act(p, "toggle", '{"field":"eject"}')
    t.run_ticks(2)
    assert(t.hands(p).held == "bottle", "the bottle comes back out")
end

-- ---------------------------------------------------------------
-- ONE: NINETY ATMOSPHERES, AND THE CRITICAL ISOTHERM.
--
-- A canister charged past CO2's own vapour pressure condenses, and
-- condensing at fixed energy pays the latent heat straight back into
-- the vessel -- so it warms itself until it reaches the one
-- temperature above which no pressure whatsoever will condense it, and
-- stops there. That temperature is authored (304.1 K, `critical` in
-- substances/co2.luau) and never derived (D8). A canister sitting
-- exactly on its own critical isotherm with a liquid row under a gas
-- row is not a coincidence: it is the only place the arithmetic can
-- come to rest.
-- ---------------------------------------------------------------
assert(t.charge_vessel(2, 1, "co2", 9000.0), "ninety atmospheres of carbon dioxide")
t.run_seconds(5)
local bottle_line = t.vessel(can)
near(bottle_line.temp_k, CRITICAL_K, 0.01,
    "the canister settled on the critical isotherm: " .. bottle_line.temp_k .. " K")
assert(liquid(can) > 100.0, "with liquid carbon dioxide in it: " .. liquid(can) .. " mol")

local booked = t.matter_totals()
local charged_co2 = booked.substances.co2
assert(charged_co2 > 7000.0, "and the books know about all of it: " .. charged_co2 .. " mol")

-- ---------------------------------------------------------------
-- TWO: A BOTTLE OF LIQUID CARBON DIOXIDE.
--
-- The bottle comes off the valve at the line's own temperature, which
-- is the critical isotherm, so what it is carrying is a gas -- there
-- is no condensation above 304.1 K however hard the valve pressed.
-- Put it in the chamber at station temperature and the same moles
-- become a liquid under their own vapour pressure, which is 5.4 MPa
-- and is why nobody carries this in a beaker.
-- ---------------------------------------------------------------
t.click(p, 2, 3, jar)
t.run_ticks(2)
assert(t.hands(p).held == "bottle", "the bottle is in hand")
t.click(p, 2, 1, can)
t.run_ticks(4)
local drawn = t.vessel(jar).moles
assert(drawn > 0.15, "it came away with carbon dioxide: " .. drawn .. " mol")
near(liquid(jar), 0.0, 1e-12, "and none of it is liquid, because it is over the critical point")
near(gas(jar), drawn, 1e-12, "all of it is gas")

condition(293.15, 300)
assert(liquid(jar) > 0.05, "at station temperature it is a LIQUID: " .. liquid(jar) .. " mol")
near(t.holder_kpa(jar), vapour_kpa(t.holder_k(jar)), 0.01 * vapour_kpa(t.holder_k(jar)),
    "standing at its own vapour pressure")
near(solid(jar), 0.0, 1e-12, "and no solid, because 293 K is well over the triple point")
undock()

-- ---------------------------------------------------------------
-- THREE: TIP IT OUT, AND IT FLASHES.
--
-- A tip takes the CONDENSED phases and leaves the vapour behind
-- (items/bottle.luau), so what lands on the deck is liquid carbon
-- dioxide at one atmosphere -- a hundred and ten kelvin over the
-- temperature its own vapour line puts it at, and a hundred and
-- fifteen kilopascals under the pressure it needs to stay a liquid at
-- all. It does not puddle. It is gas before anybody looks down, and
-- the tile it landed on paid the latent heat.
-- ---------------------------------------------------------------
local floor_k = t.room_temperature(1, 2)
local gauge = t.holder_kpa(jar)
local flashed = liquid(jar)
t.click(p, 1, 2)
t.run_ticks(4)
near(liquid(jar), 0.0, 1e-12, "the liquid all went")
near(tile_co2(1, 2), flashed, 1e-9, "and it is standing on the tile as GAS: " .. tile_co2(1, 2))
assert(t.room_temperature(1, 2) < floor_k - 0.5,
    "which cost the deck it landed on: " .. floor_k .. " -> " .. t.room_temperature(1, 2))
-- The bottle's gauge falls, and the reason is geometry rather than
-- cold: the same vapour now has the whole shell to be spread through
-- instead of the sliver over the liquid. Its TEMPERATURE does not
-- move at all -- a parcel leaves carrying its own energy, always
-- (`Mixture::draw`, lunatic-matter/src/mixture.rs) -- which is why the
-- kelvin that went missing turned up in the room and not in the glass.
assert(t.holder_kpa(jar) < gauge, "the bottle's gauge fell: " .. gauge .. " -> " .. t.holder_kpa(jar))

-- ---------------------------------------------------------------
-- FOUR: THE SAME BOTTLE, THIRTY KELVIN UNDER THE TRIPLE POINT.
--
-- Below 216.55 K the liquid does not exist -- the melting line is
-- vertical and pressure-independent (D7), and the only two phases left
-- are solid and its own vapour. So the chamber at 180 K makes DRY ICE,
-- and the gauge falls from fifty-four atmospheres to a third of one,
-- because what a solid holds over itself is the SUBLIMATION line and
-- that line is much lower. Thirty kilopascals is the whole of the
-- pressure in a bottle of dry ice, and it is a number this file
-- computes out of two latent heats it never authored together.
-- ---------------------------------------------------------------
t.click(p, 2, 1, can)
t.run_ticks(4)
local recharged = t.vessel(jar).moles
assert(recharged > 0.15, "recharged off the same line: " .. recharged .. " mol")

condition(180.0, 300)
assert(solid(jar) > 0.15, "the bottle is holding DRY ICE: " .. solid(jar) .. " mol")
near(liquid(jar), 0.0, 1e-12, "and not one mole of liquid, under the triple point")
near(t.holder_kpa(jar), sublimation_kpa(t.holder_k(jar)), 0.02 * sublimation_kpa(180.0),
    "its gauge reads the sublimation line: " .. t.holder_kpa(jar) .. " kPa")
assert(t.holder_kpa(jar) < 50.0, "which is under half an atmosphere: " .. t.holder_kpa(jar))
undock()

-- ---------------------------------------------------------------
-- FIVE: DRY ICE ON A WARM DECK.
--
-- The other half of the same spill. A solid arrives, LINGERS -- long
-- enough that a tile reads it as matter that is not gas yet -- and
-- then loses its whole mass to `co2:gas` over the next half minute,
-- taking 25.2 kJ per mole out of the tile to do it. The control tile
-- two squares away is the assertion's other half: the room is under an
-- inert sky and nothing else in it is moving, so the gap between the
-- two tiles is the ice.
-- ---------------------------------------------------------------
local ice = solid(jar)
local deck_k = t.room_temperature(1, 3)
local carbon_0 = room_co2()
t.click(p, 1, 3)
t.run_ticks(4)
-- Four ticks in, what is on the deck is still ICE. Sublimation has
-- begun -- the tile's own vapour is carried off as soon as the raw
-- imbalance across a link is worth chasing (lunatic
-- docs/MATTER-WORLD.md §3 step 4), so the jar starts losing mass at
-- once instead of stalling under its own gas -- but a few per cent of
-- it has gone, not the whole, which is the claim: a jar of dry ice put
-- down is a solid on the floor and not a puff.
assert(
    tile_co2(1, 3) < ice * 0.15,
    "the moment it lands it is still ICE on the deck: "
        .. tile_co2(1, 3) .. " gas of " .. ice .. " mol"
)
assert(t.room_temperature(1, 3) < deck_k - 0.5,
    "and it is already cooling the tile: " .. deck_k .. " -> " .. t.room_temperature(1, 3))

t.run_seconds(30)
-- Weighed over the room. The ice's whole mass is gas half a minute
-- later, and by then it has spread off the tile it sublimated on --
-- which is why the tile itself is no longer the place to read it.
near(
    room_co2() - carbon_0,
    ice,
    1e-3,
    "half a minute later it is all gas: " .. (room_co2() - carbon_0) .. " mol"
)
-- The far side barely moved: a fifth of a kelvin, against the whole
-- room's worth of deck it is standing on. It moves at all because the
-- cold gas the ice made now SPREADS -- the share carries it as soon as
-- the raw imbalance across a link is worth chasing (lunatic
-- docs/MATTER-WORLD.md §3 step 4) -- and cold air arriving is the only
-- thing that could have cooled it, since the sky is inert and nothing
-- else in the room is running. The claim was never that the far tile is
-- untouched; it is that the GAP between the two tiles is the ice, which
-- is the assertion below.
local control = t.room_temperature(4, 3)
near(control, 293.15, 0.5, "the far side of the room hardly moved")
assert(t.room_temperature(1, 3) < control - 0.3,
    "and the tile the ice was on is still the cold one: "
        .. t.room_temperature(1, 3) .. " vs " .. control)

-- ---------------------------------------------------------------
-- SIX: THE BOOKS.
--
-- Every mole of carbon dioxide in this spec came out of one canister
-- and went where a transfer put it. Nothing was pressed, nothing was
-- reacted, nothing was metabolized, and the two spills were transfers
-- like any other -- so the station's carbon dioxide is the SAME NUMBER
-- it was before the bottle was ever picked up, across three phases,
-- two vessels, two tiles and a canister.
-- ---------------------------------------------------------------
local closed = t.matter_totals()
near(closed.substances.co2, charged_co2, 1e-9,
    "not one mole of it was made or lost: " .. closed.substances.co2 .. " vs " .. charged_co2)
near(closed.moles, booked.moles, 1e-9, "nor of anything else in the room")
