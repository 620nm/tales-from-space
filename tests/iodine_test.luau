-- Iodine sublimes. A solid with a real phase diagram
-- (substances/iodine.luau) sits under its own SUBLIMATION line at room
-- temperature, so a sealed bottle of crystals carries a violet gas row
-- at a few pascals, and a crystal tipped out onto the deck loses its
-- whole mass to `iodine:gas` without ever being a liquid, cooling the
-- tile it lay on by the latent heat it took to leave (docs/MATTER.md 5).
--
-- Every number here is the registry's own arithmetic, spelled out from
-- the file's four constants so the assertion is against the line and
-- not against a snapshot: vapour line anchored at (457.4 K, 1 atm),
-- P_t = vap(386.75 K), sublimation line anchored at (386.75 K, P_t)
-- with L_sub = L_fus + L_vap by Hess.
local R = 8.314462618
local MELT_K, BOIL_K = 386.75, 457.4
local L_FUS, L_VAP = 15520.0, 41570.0
local ONE_ATM_PA = 101325.0

local function vapour_pa(temp_k)
    return ONE_ATM_PA * math.exp((-L_VAP / R) * (1.0 / temp_k - 1.0 / BOIL_K))
end

local TRIPLE_PA = vapour_pa(MELT_K)

local function sublimation_pa(temp_k)
    return TRIPLE_PA * math.exp((-(L_FUS + L_VAP) / R) * (1.0 / temp_k - 1.0 / MELT_K))
end

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

t.world([==[(
    name: "the iodine bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "######",
        "#....#",
        "######",
    ],
    spawns: [(1, 1)],
    items: [(1, 1, "bottle.iodine")],
)]==], 0)

t.set_environment({ sink_k = 293.15, insolation = 0.0 })

local p = t.join()
t.tick()

local bottle = t.target_at(1, 1, "bottle.iodine")

local function phases(handle)
    local reading = t.vessel(handle)
    assert(reading ~= nil, "that is a vessel")
    return reading.contents.iodine or {}
end

local function tile_iodine(x, y)
    local gases = t.room_gas(x, y)
    return (gases and gases.iodine) or 0.0
end

-- ---------------------------------------------------------------
-- ONE: THE BOTTLE ON THE SHELF.
--
-- A `contents` fill lands at the substance's rest phase at the fill's
-- temperature (docs/CONTENT-SCHEMA.md 1.1): under the line, so solid.
-- The bottle's own sweep then puts exactly the line's worth of vapour
-- over the crystals: n = P_sub(T) * V_headspace / (R * T), which at
-- 293 K is a few micromoles -- and the gauge reads that line and
-- nothing else, because there is no air in the bottle to add to it.
-- ---------------------------------------------------------------
t.run_seconds(5)
local reading = t.vessel(bottle)
local before = phases(bottle)
assert((before.solid or 0) > 0.12, "crystals in the bottle: " .. tostring(before.solid))
assert((before.liquid or 0) < 1e-9, "and not a drop of liquid: it never melts down here")
assert((before.gas or 0) > 0, "and a violet haze over them: " .. tostring(before.gas))

local line_kpa = sublimation_pa(reading.temp_k) / 1000.0
near(reading.pressure_kpa, line_kpa, line_kpa * 0.05,
    "the gauge reads the sublimation line at " .. reading.temp_k .. " K")
local headspace_m3 = reading.headspace_l / 1000.0
local n_line = sublimation_pa(reading.temp_k) * headspace_m3 / (R * reading.temp_k)
near(before.gas, n_line, n_line * 0.05, "the haze is the line's worth of vapour, no more")

local booked = t.matter_totals()

-- ---------------------------------------------------------------
-- TWO: A CRYSTAL ON THE DECK.
--
-- Tip it out. What lands is SOLID -- the deck's air is at a pressure
-- the sublimation line cannot reach -- but the partial pressure of
-- iodine over a fresh tile is zero, so the crystal starts losing mass
-- to the room at once, and it pays for every mole with L_sub of the
-- tile's heat. The control tile at the far end never moves.
-- ---------------------------------------------------------------
local charge = (before.solid or 0) + (before.gas or 0)
t.click(p, 1, 1, bottle) -- pick it up
t.tick()
local deck_k = t.room_temperature(2, 1)
t.click(p, 2, 1) -- the deck beside you, with the bottle in hand
t.run_ticks(4)

assert(t.vessel(bottle).moles < 1e-6, "the bottle is empty now: " .. t.vessel(bottle).moles)
local rows = t.ledger_rows("spilled")
assert(#rows == 1, "one spill on the record, got " .. #rows)
local landed = tile_iodine(2, 1)
assert(landed < charge * 0.05,
    "what landed is a crystal, not a cloud -- the tile holds only a trace of gas yet: " .. landed)

t.run_seconds(120)
local plume = tile_iodine(2, 1) + tile_iodine(1, 1) + tile_iodine(3, 1) + tile_iodine(4, 1)
assert(plume > landed + 1e-4,
    "two minutes later the crystal is going up as vapour: " .. landed .. " -> " .. plume)
local control = t.room_temperature(4, 1)
assert(t.room_temperature(2, 1) < deck_k - 0.05,
    "and the tile it lay on paid the latent heat: " .. deck_k .. " -> " .. t.room_temperature(2, 1))
assert(t.room_temperature(2, 1) < control,
    "colder than the far end of the room: " .. t.room_temperature(2, 1) .. " vs " .. control)

-- ---------------------------------------------------------------
-- THREE: THE BOOKS CLOSE.
-- ---------------------------------------------------------------
local closed = t.matter_totals()
near(closed.substances.iodine, booked.substances.iodine, 1e-9,
    "not one mole of iodine was made or lost")
near(closed.moles, booked.moles, 1e-9, "nor of anything else in the room")
