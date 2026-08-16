-- Chillstation's tank annex: seven stationary reservoirs off the west
-- side of Atmospherics, one per gas this shift's chemistry defines.
-- (The whole department moved south-west when the station was redrawn
-- around a central Commons; the annex came with it as one block, so
-- every coordinate here is (x - 1, y + 9) of the one it replaced and
-- nothing inside the room changed.)
--
-- The point of the room is that each tank holds ITS OWN gas, and the
-- point of the map format change is that it says so per placement --
-- no `oxygen_tank` prototype beside a `nitrogen_tank` beside a
-- `plasma_tank`, which is the ladder tg's twenty /tank/<gas> subtypes
-- climb and the one this pack refuses. So the assertion that matters
-- is the boring one: seven vessels, seven gases, no cross-talk.
--
-- They are deliberately unplumbed. A tank shares with every net its
-- four mouths reach, so a main run through the row would settle all
-- seven into one mixture inside a pass -- which is exactly what this
-- spec proves does NOT happen.

t.world_file("chillstation.ron", 7)
t.join()
t.run_seconds(5)

-- The store, as the map authored it: (x, y) -> the one gas in it.
local store = {
    { 4, 28, "o2" },
    { 6, 28, "n2" },
    { 8, 28, "co2" },
    { 10, 28, "plasma" },
    { 12, 28, "water_vapor" },
    { 5, 33, "tritium" },
    { 7, 33, "n2o" },
}

for _, row in ipairs(store) do
    local x, y, gas = row[1], row[2], row[3]
    local where = "(" .. x .. ", " .. y .. ")"
    local standing = t.structure_at(x, y)
    assert(standing and standing.id == "stationary_tank",
        "a tank stands at " .. where .. ": " .. tostring(standing and standing.id))

    -- tg's `starting_pressure_percent = 0.5` of the 46 000 kPa rating,
    -- and it has not drifted: nothing is plumbed into these, so five
    -- seconds of atmos has had nowhere to move a mole to.
    local kpa = t.tank_pressure(x, y)
    assert(math.abs(kpa - 23000.0) < 50.0,
        where .. " opens at half its rating: " .. kpa)
end

-- ...and each holds a DIFFERENT gas, which is the assertion the whole
-- room exists for. A pressure cannot say which gas it is, and "seven
-- tanks of oxygen" would pass every reading above.
for _, row in ipairs(store) do
    local x, y, gas = row[1], row[2], row[3]
    local where = "(" .. x .. ", " .. y .. ")"
    local held = t.tank_gas(x, y)
    assert(held, where .. " is a vessel with contents")
    local kinds = 0
    for key, moles in pairs(held) do
        kinds = kinds + 1
        assert(key == gas,
            where .. " holds " .. gas .. ", not " .. key .. " (" .. moles .. " mol)")
    end
    assert(kinds == 1, where .. " holds ONE gas, not " .. kinds)
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
-- branch power under it and the bench run stopping either side.
local unit = t.structure_at(10, 31)
assert(unit ~= nil and unit.id == "thermomachine",
    "the temperature control unit stands on the machine tile")
assert(unit.state == "running", "and ships running: " .. tostring(unit.state))
assert(t.pipe(9, 31) ~= 0 and t.pipe(11, 31) ~= 0,
    "with the bench run stopping either side of it")
