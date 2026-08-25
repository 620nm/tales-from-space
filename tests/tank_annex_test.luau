-- Chillstation's tank annex: seven stationary reservoirs off the west
-- side of Atmospherics, one per substance atmospherics runs on.
-- (The whole department moved south-west when the station was redrawn
-- around a central Commons; the annex came with it as one block, so
-- every coordinate here is (x - 1, y + 9) of the one it replaced and
-- nothing inside the room changed.)
--
-- The point of the room is that each tank holds ITS OWN substance, and
-- the point of the map format change is that it says so per placement --
-- no `oxygen_tank` prototype beside a `nitrogen_tank` beside a
-- `plasma_tank`, which is the ladder tg's twenty /tank/<gas> subtypes
-- climb and the one this pack refuses. So the assertion that matters
-- is the boring one: seven vessels, seven contents, no cross-talk.
--
-- Five of them gauge at the charge the map wrote. Two do not, and both
-- for the same reason: they hold something with a phase diagram on it,
-- and 23 000 kPa is a pressure no real gas stands at without giving
-- some of itself up.
--
-- WATER is the plainest case. At annex temperature most of that fill
-- belongs in the bottom of the tank, and the gauge falls to the dew
-- point the first time the vessel takes a phase step. `t.tank_gas`
-- sums a substance over every phase it is in, so the moles it reports
-- are the same before and after -- which is why the water tank is
-- specced in moles and never in kPa.
--
-- CARBON DIOXIDE is the interesting one, and it is new: co2 carries a
-- real triple point and a real critical temperature now (216.55 K at
-- 517 kPa; 304.1 K), so a bottle charged to 23 MPa at room temperature
-- is a bottle well over its own saturation line -- CO2 liquefies at
-- 6.3 MPa at 300 K. Part of the charge condenses, the latent heat it
-- gives up has nowhere to go (a stationary tank is not deck-coupled,
-- so the sweep is adiabatic), and the mixture warms until it reaches
-- the CRITICAL temperature, where there is no longer any distinction
-- to condense across and the sweep stops. That is where this tank
-- sits: 304.1 K, a few hundred litres of liquid under 23.5 MPa of
-- supercritical gas. It is what a real 2 500 L bottle of CO2 does, and
-- it is the one reading in this room that is not the number the mapper
-- typed.
--
-- They are deliberately unplumbed. A tank shares with every net its
-- four mouths reach, so a main run through the row would settle all
-- seven into one mixture inside a pass -- which is exactly what this
-- spec proves does NOT happen.

t.world_file("chillstation.ron", 7)
t.join()
t.run_seconds(5)

-- The store, as the map authored it: (x, y) -> the one substance in it,
-- and, for the tank whose reading is moles, how many the fill comes to.
local store = {
    { 4, 28, "o2" },
    { 6, 28, "n2" },
    { 8, 28, "co2", nil, "condenses" },
    { 10, 28, "plasma" },
    { 12, 28, "water", 69000.0 },
    { 5, 33, "tritium" },
    { 7, 33, "n2o" },
}

-- CO2's own critical temperature, out of substances/co2.luau.
local CO2_CRITICAL_K = 304.1

for _, row in ipairs(store) do
    local x, y = row[1], row[2]
    local where = "(" .. x .. ", " .. y .. ")"
    local standing = t.structure_at(x, y)
    assert(standing and standing.id == "stationary_tank",
        "a tank stands at " .. where .. ": " .. tostring(standing and standing.id))

    -- tg's `starting_pressure_percent = 0.5` of the 46 000 kPa rating,
    -- and it has not drifted: nothing is plumbed into these, so five
    -- seconds of atmos has had nowhere to move a mole to. Skipped for
    -- the water tank, whose gauge is a phase reading rather than a
    -- charge (see the header).
    if row[4] == nil and row[5] == nil then
        local kpa = t.tank_pressure(x, y)
        assert(math.abs(kpa - 23000.0) < 50.0,
            where .. " opens at half its rating: " .. kpa)
    end
end

-- The carbon dioxide tank, by the reading a phase diagram leaves. The
-- charge is the mapper's; where it SETTLED is physics, and the two
-- halves of the answer are one statement: there is liquid in the
-- bottom, and the mixture is exactly at the temperature above which
-- there could not be.
do
    local co2 = t.vessel(t.target_at(8, 28, "stationary_tank"))
    assert(co2 ~= nil, "the carbon dioxide tank reads")
    local entry = co2.contents.co2
    assert(entry ~= nil, "and it is carbon dioxide")
    assert((entry.liquid or 0) > 0.0,
        "part of a 23 MPa charge condensed: " .. tostring(entry.liquid))
    assert((entry.gas or 0) > (entry.liquid or 0),
        "most of it is still gas over the top")
    assert(math.abs(co2.temp_k - CO2_CRITICAL_K) < 0.5,
        "and the latent heat drove it to the critical temperature, where "
            .. "condensing stops: " .. co2.temp_k)
    assert(co2.pressure_kpa > 23000.0,
        "the gauge reads over the charge, not under it: " .. co2.pressure_kpa)
    assert(co2.headspace_l < co2.volume_l,
        "because the liquid took room out of the shell: "
            .. co2.headspace_l .. " of " .. co2.volume_l .. " L")
end

-- ...and each holds a DIFFERENT substance, which is the assertion the
-- whole room exists for. A pressure cannot say which gas it is, and
-- "seven tanks of oxygen" would pass every reading above.
for _, row in ipairs(store) do
    local x, y, held_key, want_moles = row[1], row[2], row[3], row[4]
    local where = "(" .. x .. ", " .. y .. ")"
    local held = t.tank_gas(x, y)
    assert(held, where .. " is a vessel with contents")
    local kinds = 0
    for key, moles in pairs(held) do
        kinds = kinds + 1
        assert(key == held_key,
            where .. " holds " .. held_key .. ", not " .. key .. " (" .. moles .. " mol)")
    end
    assert(kinds == 1, where .. " holds ONE substance, not " .. kinds)

    -- The water tank, by the reading that survives condensing: the map
    -- authored 67 268 kPa of water at T20C, which is 69 000 mol, which
    -- is 1 243 L of liquid in a 2 500 L shell -- a bit under half full,
    -- with damp air over it.
    if want_moles then
        local n = held[held_key]
        assert(math.abs(n - want_moles) < want_moles * 0.01,
            where .. " is half full of water: " .. n .. " mol")
    end
end

-- The room itself: sealed, breathable, named, and reachable from the
-- department through its own door. A store nobody can walk into is a
-- wall with tanks behind it.
assert(t.room_pressure(8, 30) > 90.0,
    "the annex holds its air: " .. t.room_pressure(8, 30) .. " kPa")
assert(t.turf(10, 31) == "plating", "bare plating, like the rest of the station")
assert(t.door_at(13, 31), "and a door into the machine hall's corridor")

-- The machine tile the annex was laid out around, and the machine now
-- standing on it: the temperature control unit, shipped running at its
-- T20C default like the rest of the commissioned department, with
-- room circuit power under it and the bench run stopping either side.
local unit = t.structure_at(10, 31)
assert(unit ~= nil and unit.id == "thermomachine",
    "the temperature control unit stands on the machine tile")
assert(unit.state == "running", "and ships running: " .. tostring(unit.state))
assert(t.pipe(9, 31) ~= 0 and t.pipe(11, 31) ~= 0,
    "with the bench run stopping either side of it")
