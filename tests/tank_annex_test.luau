-- Chillstation's tank annex: seven stationary reservoirs off the west
-- side of Atmospherics, one per gas this shift's chemistry defines.
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
    { 5, 19, "o2" },
    { 7, 19, "n2" },
    { 9, 19, "co2" },
    { 11, 19, "plasma" },
    { 13, 19, "water_vapor" },
    { 6, 24, "tritium" },
    { 8, 24, "n2o" },
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
assert(t.room_pressure(9, 21) > 90.0,
    "the annex holds its air: " .. t.room_pressure(9, 21) .. " kPa")
assert(t.turf(11, 22) == "plating", "bare plating, like the rest of the department")
assert(t.door_at(14, 22), "and a door into the machine hall's corridor")

-- The free machine tile the annex was laid out around: no structure on
-- it, branch power under it, and a length of the bench run reaching it
-- from either side.
assert(t.structure_at(11, 22) == nil, "(11, 22) is free for a machine")
assert(t.pipe(10, 22) ~= 0 and t.pipe(12, 22) ~= 0,
    "with the bench run stopping either side of it")
