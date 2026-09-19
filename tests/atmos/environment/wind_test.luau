-- Wind: the air over a tile has a DIRECTION and a speed, it comes from
-- a hole in the hull, and it dies on its own when the hole stops
-- pulling. `t.wind(x, y)` reads the sim's velocity field in m/s on the
-- map's axes (+east, +north), which is the same field the gas overlay
-- draws a streak from (docs/MATTER-WORLD.md §5).
--
-- Nothing here scripts the settling. There is no breach state to clear
-- and no timer that switches the wind off: the corridor vents, the
-- pressure that was driving it is gone, and the field decays on its own
-- time constant. That is the whole assertion.
t.world(
    [==[(
    name: "windward",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "#########",
        "#.......#",
        "#########",
    ],
    structures: [(6, 1, "player_spawn")],
)]==],
    7
)

t.join()
t.tick()

local function speed(x: number, y: number)
    local east, north = t.wind(x, y)
    return math.sqrt(east * east + north * north), east, north
end

-- A sealed corridor is still air, everywhere along it.
for x = 1, 7 do
    local s = speed(x, 1)
    assert(s == 0, "a sealed corridor is still at " .. x .. ", got " .. s)
end
-- And a wall has no air to move.
assert(speed(0, 0) == 0, "a wall answers nothing")

-- The hull fails at the west end. Nothing in this file says "breach":
-- the turf IS space now, and everything that follows is physics.
t.set_composition(1, 1, "bare")
-- Three seconds in: the corridor is still emptying (about 29 kPa at its
-- middle), and it is all but empty in ten. Read later, the field is a
-- remnant decaying over bare deck.
t.run_seconds(3)
assert(assert(t.room_pressure(4, 1)) > 5, "the corridor still has air to give")

local s2, east2 = speed(2, 1)
assert(s2 > 0.05, "the air by the hole is running, got " .. s2)
assert(east2 < 0, "and it is running WEST, toward the hole: " .. east2)

-- It reaches back along the corridor, never faster than the tile in
-- front of it: a jet loses itself as it spreads (momentum transport,
-- §9 5c). The two tiles nearest the hole both run at the field's cap,
-- 2 m/s (lunatic docs/matter-world/momentum.md, `V_CAP`); from the
-- third tile back the speed falls tile by tile, 1.9 to 0.5 m/s.
local s3 = speed(3, 1)
assert(s3 > 0, "the corridor behind it is moving too, got " .. s3)
assert(s3 <= s2, "and no faster than the tile at the hole: " .. s3 .. " vs " .. s2)
for x = 4, 7 do
    local nearer, here = speed(x - 1, 1), speed(x, 1)
    assert(here > 0 and here < nearer, "slower again at " .. x .. ": " .. here .. " vs " .. nearer)
end

-- The room has nothing left to give. No script ends this; the pressure
-- ran out, the forcing went with it, and the field fell under its own
-- floor.
t.run_seconds(240)
for x = 2, 7 do
    local s = speed(x, 1)
    assert(s < 0.05, "the wind settled at " .. x .. ", got " .. s)
end
assert(assert(t.room_pressure(4, 1)) < 5, "because the corridor is empty")
