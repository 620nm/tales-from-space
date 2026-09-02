-- IDENTITY: what a fire leaves behind, and where it goes when the room
-- cools.
--
-- A plasma fire makes carbon dioxide and water (reactions/
-- plasma_fire.luau, tg's `gasmixtures/reactions.dm` parity trace), and
-- the water it makes is `water` -- the same substance a beaker holds
-- and a dispenser presses, not a `water_vapor` gas twinned with it.
-- This spec is the regression that says so in the one place the two
-- would have had to be different: the moment the room cools past the
-- dew point and the fire's own exhaust RAINS.
--
-- The claim composes with humidity_test.luau rather than repeating it.
-- That file proves the other half -- a beaker boiled dry in a warm room
-- leaves the room DAMP instead of raining instantly, because vapour
-- condenses only past its own dew point. This one proves the rain
-- still happens when it should, out of a source no vessel was
-- involved in, and that the two gases the same fire made behave
-- differently because their DIAGRAMS differ: water has a condensation
-- line at these temperatures and carbon dioxide does not.
--
-- `t.room_gas` reports the GAS phase only (sim/vents.rs), which is
-- what makes the assertions sharp: a puddle reads as zero there. What
-- says the water did not simply VANISH is `t.matter_totals`, the whole
-- station's matter in one reading (sim/holder_kinds.rs) -- so "the gas
-- went and the substance stayed" is two readings of one fact.

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

t.world([==[(
    name: "the burn chamber",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "####",
        "#..#",
        "#..#",
        "####",
    ],
    spawns: [(1, 1)],
    blends: {
        // fire_watch_test.luau's own mixture: fuelled, oxidised, and
        // already over the ignition window, so the chamber catches on
        // its own within a pass or two. Nothing in this file lights it.
        "burning_mix": (
            rows: [("plasma", 10.0), ("o2", 14.0)],
            temperature_k: 700.0,
            amount: per_tile,
        ),
    },
    painted: [(1, 1, "burning_mix"), (2, 1, "burning_mix"), (1, 2, "burning_mix"), (2, 2, "burning_mix")],
)]==], 0)

-- A sky at absolute zero with no star in it: the hull radiates and
-- nothing comes back, which is how a chamber that has just been on
-- fire cools down in a spec instead of in an hour. A PRECONDITION
-- setter, never an assertion (queries.rs, `set_environment`).
t.set_environment({ sink_k = 2.7, insolation = 0.0 })

local ROOM = { { 1, 1 }, { 2, 1 }, { 1, 2 }, { 2, 2 } }

local function room(key)
    local n = 0.0
    for _, tile in ipairs(ROOM) do
        local gases = t.room_gas(tile[1], tile[2])
        n = n + ((gases and gases[key]) or 0.0)
    end
    return n
end

local function warmth()
    local sum = 0.0
    for _, tile in ipairs(ROOM) do
        sum = sum + t.room_temperature(tile[1], tile[2])
    end
    return sum / #ROOM
end

-- ---------------------------------------------------------------
-- ONE: IT BURNS, AND WHAT IT MAKES IS STEAM.
-- ---------------------------------------------------------------
near(room("water"), 0.0, 1e-12, "nothing in the chamber is wet to start with")
t.run_seconds(30)
assert(#t.ledger_rows("IgnitionAt") > 0, "the chamber caught fire")

local steam = room("water")
assert(steam > 1.0, "and the fire made water: " .. steam .. " mol")
assert(room("co2") > 1.0, "and carbon dioxide with it: " .. room("co2") .. " mol")
assert(warmth() > 400.0, "in a chamber far too hot to rain in: " .. warmth() .. " K")

-- ...and while it is that hot the water STAYS a gas. This is the half
-- humidity_test.luau owns, asserted here for the other source: a room
-- over the dew point holds its vapour, and the old one-way ratchet
-- would have rained it onto the deck within a pass whatever the
-- temperature was.
t.run_seconds(30)
assert(room("water") > 1.0, "the hot chamber is still holding it: " .. room("water") .. " mol")

-- ---------------------------------------------------------------
-- TWO: IT COOLS, AND IT RAINS.
--
-- The fire is out of fuel and the hull is radiating into an empty sky.
-- Water's vapour line at 290 K puts its dew point at under two
-- kilopascals, and there are moles of it in four cubic metres, so the
-- chamber is far past saturation before it is anywhere near cold.
-- ---------------------------------------------------------------
local booked = t.matter_totals()
local made = booked.substances.water
assert(made > 1.0, "the books know how much water the fire made: " .. made .. " mol")

t.run_seconds(1800)
assert(warmth() < 310.0, "the chamber cooled: " .. warmth() .. " K")

local left_in_the_air = room("water")
assert(left_in_the_air < 0.25 * steam,
    "and most of the water came out of the air: "
        .. steam .. " -> " .. left_in_the_air .. " mol")

-- ...and what is LEFT in it is exactly what a chamber that warm is
-- entitled to hold: the dew-point load, `P_vap(T)*V/(R*T)` over four
-- cubic metres, off water's own line (substances/water.luau: boil
-- 373.15 K, l_vap 40 660 J/mol). That is the whole claim in one
-- number -- it did not rain until it was saturated and it did not
-- stop until it was, which is what a dew point IS. A quarter of
-- slack, because the chamber is still cooling while the reading is
-- taken and the deck under it is a pass behind the air.
local R = 8.314462618
local warm = warmth()
local dew_kpa = 101.325 * math.exp((-40660.0 / R) * (1.0 / warm - 1.0 / 373.15))
local dew_mol = dew_kpa * 1000.0 * 4.0 / (R * warm)
assert(math.abs(left_in_the_air - dew_mol) < 0.25 * dew_mol,
    "the air is holding its dew point and no more: "
        .. left_in_the_air .. " vs " .. dew_mol .. " mol at " .. warm .. " K")

-- ...ONTO THE DECK, not out of existence. Cells hold condensed matter
-- exactly as vessels do, so a puddle is a liquid row in the tile's own
-- mixture and the station's water total never moved.
local closed = t.matter_totals()
near(closed.substances.water, made, 1e-9,
    "every mole of it is still in the chamber, as a puddle: "
        .. closed.substances.water .. " vs " .. made)

-- ...and the OTHER gas the same fire made, in the same air, at the
-- same temperature, did not rain -- because carbon dioxide's diagram
-- has no liquid at one atmosphere at all and its sublimation line is a
-- hundred kelvin below this room (substances/co2.luau). One phase
-- step, two substances, two different answers, and the difference is
-- entirely in what the two files authored.
assert(room("co2") > 1.0,
    "the carbon dioxide is still in the air: " .. room("co2") .. " mol")
near(closed.substances.co2, booked.substances.co2, 1e-9,
    "and its book closes too")
