-- Floor tiles come up and go back down under fixtures.
--
-- tg puts exactly one condition on prying a tile: the turf has to be a
-- tiled floor (`/turf/open/floor/crowbar_act` -> `pry_tile` ->
-- `remove_tile`, code/game/turfs/open/floor.dm:144-176). Nothing
-- standing on the turf is consulted, so lifting the tile out from under
-- a vent, an APC or a light is ordinary engineering work -- and so is
-- laying one back down over them. The engine used to refuse any tile a
-- machine stood on, and refuse it in silence.

local function has(list, want)
    for _, v in ipairs(list) do
        if v == want then
            return true
        end
    end
    return false
end

t.world([==[(
    name: "fixture row",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'a': (turf: Floor, fixture: Some(Apc)),
        'l': (turf: Floor, fixture: Some(Light)),
    },
    rows: [
        "#######",
        "#.a..l#",
        "#.....#",
        "#######",
    ],
    spawns: [(1, 2)],
    items: [(1, 2, "crowbar")],
    structures: [(4, 1, "vent")],
)]==], 7)

local p = t.join()
t.tick()
t.click(p, 1, 2, t.target_at(1, 2, "crowbar")) -- the crowbar is underfoot
t.tick()
t.sounds(p)      -- clear the pickup traffic
t.messages(p)

-- The APC's tile, from the walkway below it.
assert(t.turf(2, 1) == "floor", "the APC stands on a tiled floor")
t.click(p, 2, 1)
t.tick()
assert(t.turf(2, 1) == "plating", "the tile under the APC comes up")
assert(has(t.items_at(2, 1), "floor_tile"), "and is refunded where it lay")
assert(has(t.messages(p), "You pry up the floor tile."),
    "the narration was not a lie")

-- The quick pop, not the sustained heave: tg's pry_tile plays
-- `usesound` (crowbar.ogg) via play_tool_sound, never `operating_sound`.
local heard = t.sounds(p)
assert(has(heard, "crowbar"), "the crowbar's usesound plays")
assert(not has(heard, "crowbar_pry"), "the prying-open heave does not")

-- A vent and a light are no different.
local function walk(dir, steps)
    for _ = 1, steps do
        t.move(p, dir)
        t.run_ticks(5) -- MOVE_COOLDOWN_TICKS, one step per press
    end
end

walk("east", 3)
assert(t.pos(p) == 4, "walked under the vent row")
t.click(p, 4, 1)
t.tick()
assert(t.turf(4, 1) == "plating", "the tile under the vent comes up")
t.click(p, 5, 1)
t.tick()
assert(t.turf(5, 1) == "plating", "and the one under the light")

-- Back the other way: a tile goes down on plating a fixture stands on.
walk("west", 3)
t.drop(p)      -- put the crowbar down; the hand is for the tile
t.tick()
t.click(p, 2, 1, t.target_at(2, 1, "floor_tile")) -- pick the pried tile back up
t.tick()
t.messages(p)
t.click(p, 2, 1) -- and lay it
t.run_seconds(1.0)
assert(t.turf(2, 1) == "floor", "the tile goes back down under the APC")
assert(has(t.messages(p), "The floor is tiled."), "and says so")

-- Scenario 2: forcing a dead airlock is the OTHER crowbar sound.
t.world([==[(
    name: "dead airlock",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        '+': (turf: Floor, fixture: Some(Door)),
    },
    rows: [
        "#####",
        "#..+#",
        "#####",
    ],
    spawns: [(1, 1)],
    items: [(1, 1, "crowbar")],
    // One length of backbone with no generator behind it, which is a
    // station with the lights off: the airlock's motors never wake.
    cables: [(1, 1, 2)],
)]==], 7)

p = t.join()
t.run_ticks(30) -- let a power pass settle the dead motors
t.click(p, 1, 1, t.target_at(1, 1, "crowbar")) -- the crowbar
t.tick()
t.move(p, "east")
t.run_ticks(6)
t.sounds(p)
t.click(p, 3, 1, t.target_at(3, 1)) -- heave the unpowered airlock open
t.run_seconds(3.0)
local door_sounds = t.sounds(p)
assert(has(door_sounds, "crowbar_pry"),
    "forcing a door plays tg's operating_sound, the sustained heave")
assert(not has(door_sounds, "crowbar"),
    "and not the quick tile pop")
assert(has(t.messages(p), "The door gives way."), "the airlock opens")
