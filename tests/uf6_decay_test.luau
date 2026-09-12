-- DECAY HEAT: a room of UF6 warms itself, in whatever phase the stuff
-- is resting in.
--
-- The substance file (content/substances/uf6.luau) declares
-- `decay_heat = 25` watts per mole, emitted wherever the moles sit, in
-- every phase. This spec is that number made flesh, twice:
--
--   ONE, a sealed room holding UF6 GAS must gain energy at exactly
--   decay_heat x moles -- the room's whole book is readable
--   (`t.room_energy` for the air, `t.deck` for the deck under it), so
--   the assertion is on JOULES, with the hull's radiation the only
--   leak. The fill is THIN on purpose: UF6's vapour pressure over its
--     own solid is ~11.5 kPa at deck temperature, so anything past
--   ~4.7 mol in a cubic metre frosts out the moment the deck drinks
--   the paint's heat -- and the frost case is room two's job.
--
--   TWO, a room painted with the same substance at deck temperature
--   rests as a SOLID (a few moles a tile stand in the air as its
--   vapour pressure; nothing melts at one atmosphere) and still gains
--   energy at the same rate, because decay emits in every phase.
--
-- The temperature half of each claim is the same joules spread over
-- the room's whole heat capacity, air and deck: dT = E / C_total with
-- C_total read live (the deck's capacity is `t.deck`'s, the mixture's
-- is summed over the phase split as it stands). The air stands a small
-- constant lag over the deck once the settle has run, so both warm
-- together at that rate; the slack on temperature is wide because the
-- lag and the radiation are only bounded, not modelled.

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

-- The substance file's numbers, restated so the spec fails when the
-- file drifts, not when it is read.
local DECAY_W_PER_MOL = 25.0
local CV_GAS = 130.0
local CV_SOLID = 166.0
local GAS_FILL = 3.0 -- mol/tile: 7.3 kPa at deck temperature, under the 11.5 kPa vapour pressure
local SOLID_FILL = 30.0

t.world([==[(
    name: "the cylinder cell",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#######",
        "#..#..#",
        "#..#..#",
        "#######",
    ],
    spawns: [(1, 1)],
    blends: {
        // Hot UF6 gas, thin enough to STAY gas: at 350 K the fill is
        // far under the sublimation line, and once the deck has drunk
        // the paint's heat the room rests at deck temperature with
        // p = 7.3 kPa against a vapour pressure of ~11.5 kPa
        // (substances/uf6.luau: triple 337.2 K at 151.7 kPa).
        "hot_hex": (
            rows: [("uf6", 3.0)],
            temperature_k: 350.0,
            amount: per_tile,
        ),
        // The same substance at the deck's own temperature: under the
        // triple point, so it rests as a SOLID and only its vapour
        // pressure's worth stands in the air. Painting at deck
        // temperature keeps the deck from being a second heat source
        // in the reading.
        "cold_hex": (
            rows: [("uf6", 30.0)],
            temperature_k: 293.15,
            amount: per_tile,
        ),
    },
    painted: [
        (1, 1, "hot_hex"), (2, 1, "hot_hex"), (1, 2, "hot_hex"), (2, 2, "hot_hex"),
        (4, 1, "cold_hex"), (5, 1, "cold_hex"), (4, 2, "cold_hex"), (5, 2, "cold_hex"),
    ],
)]==], 0, "free_build")

-- A sky at the deck's own temperature with no star in it: the hull
-- starts radiating nothing, and what it picks up as the rooms warm past
-- it is the leak the slack is for (queries.rs, `set_environment`).
t.set_environment({ sink_k = 293.15, insolation = 0.0 })

local ROOM_A = { { 1, 1 }, { 2, 1 }, { 1, 2 }, { 2, 2 } }
local ROOM_B = { { 4, 1 }, { 5, 1 }, { 4, 2 }, { 5, 2 } }

local function room_sum(room, f)
    local sum = 0.0
    for _, tile in ipairs(room) do
        sum = sum + f(tile[1], tile[2])
    end
    return sum
end

local function gas_moles(room)
    return room_sum(room, function(x, y)
        local gases = t.room_gas(x, y)
        return (gases and gases.uf6) or 0.0
    end)
end

local function liquid_litres(room)
    return room_sum(room, function(x, y)
        local litres = t.room_liquid(x, y)
        return (litres and litres.uf6) or 0.0
    end)
end

-- The room's whole energy book: what stands in the air plus what the
-- deck under it holds.
local function room_book(room)
    return room_sum(room, function(x, y)
        return t.room_energy(x, y) + t.deck(x, y).energy
    end)
end

local SETTLE_S = 300
local MEASURE_S = 600

-- ---------------------------------------------------------------
-- ZERO: THE PAINT LANDED.
-- ---------------------------------------------------------------
local fill_a = GAS_FILL * 4.0
local fill_b = SOLID_FILL * 4.0
near(gas_moles(ROOM_A), fill_a, 0.05 * fill_a,
    "the thin fill is all gas: " .. gas_moles(ROOM_A) .. " mol")

local booked = t.matter_totals()
near(booked.substances.uf6, fill_a + fill_b, 1e-9,
    "both rooms' fill is on the books")

-- ---------------------------------------------------------------
-- SETTLE. The hot paint's excess drains into the deck, the cold
-- room's sublimation chill comes back out of it, and the air finds
-- its working lag over the deck. What happens after this point is
-- decay's alone.
-- ---------------------------------------------------------------
t.run_seconds(SETTLE_S)

-- ...and in the cold room the fill has had its chance to boil and did
-- not take it: below the triple point UF6 rests as a SOLID, with only
-- its vapour pressure's worth in the air and no liquid anywhere.
local gas_b = gas_moles(ROOM_B)
assert(gas_b < 0.25 * fill_b,
    "below the triple point the fill rests as a solid: "
        .. gas_b .. " of " .. fill_b .. " mol in the air")
near(liquid_litres(ROOM_B), 0.0, 1e-12,
    "and nothing melted: there is no liquid at one atmosphere")

local book_a0 = room_book(ROOM_A)
local book_b0 = room_book(ROOM_B)
local air_a0 = room_sum(ROOM_A, t.room_temperature) / 4.0
local air_b0 = room_sum(ROOM_B, t.room_temperature) / 4.0
local deck_a = room_sum(ROOM_A, function(x, y) return t.deck(x, y).capacity end)
local deck_b = room_sum(ROOM_B, function(x, y) return t.deck(x, y).capacity end)

-- ---------------------------------------------------------------
-- MEASURE. Each room's book must grow by exactly the decay joules;
-- the only leak is the hull radiating to a sky the room is barely
-- warmer than, which the quarter slack covers several times over.
-- ---------------------------------------------------------------
t.run_seconds(MEASURE_S)

local expected_a = DECAY_W_PER_MOL * fill_a * MEASURE_S
local expected_b = DECAY_W_PER_MOL * fill_b * MEASURE_S
near(room_book(ROOM_A) - book_a0, expected_a, 0.25 * expected_a,
    "the gas room's book grows by the decay joules: "
        .. (room_book(ROOM_A) - book_a0) .. " J vs " .. expected_a .. " J")
near(room_book(ROOM_B) - book_b0, expected_b, 0.25 * expected_b,
    "the solid room's book grows by the same joules per mole: "
        .. (room_book(ROOM_B) - book_b0) .. " J vs " .. expected_b .. " J")

-- ...and as TEMPERATURE the same joules read as dT = E / C_total over
-- air and deck together, the mixture's capacity summed over the phase
-- split as it stands. Wide slack: the air's lag over the deck is only
-- bounded, and the hull's leak grows as the room warms.
local air_a1 = room_sum(ROOM_A, t.room_temperature) / 4.0
local air_b1 = room_sum(ROOM_B, t.room_temperature) / 4.0
local c_mix_a = gas_moles(ROOM_A) * CV_GAS + (fill_a - gas_moles(ROOM_A)) * CV_SOLID
local c_mix_b = gas_moles(ROOM_B) * CV_GAS + (fill_b - gas_moles(ROOM_B)) * CV_SOLID
local predicted_a = expected_a / (c_mix_a + deck_a)
local predicted_b = expected_b / (c_mix_b + deck_b)
near(air_a1 - air_a0, predicted_a, 0.5 * predicted_a,
    "the gas room warms by the decay law: "
        .. (air_a1 - air_a0) .. " K vs " .. predicted_a .. " K predicted")
near(air_b1 - air_b0, predicted_b, 0.5 * predicted_b,
    "the solid-resting room warms by the same law: "
        .. (air_b1 - air_b0) .. " K vs " .. predicted_b .. " K predicted")

-- ---------------------------------------------------------------
-- CONSERVED. Decay ADDS joules; it does not spend moles.
-- ---------------------------------------------------------------
local closed = t.matter_totals()
near(closed.substances.uf6, booked.substances.uf6, 1e-9,
    "every mole of UF6 is still somewhere: "
        .. closed.substances.uf6 .. " vs " .. booked.substances.uf6)
