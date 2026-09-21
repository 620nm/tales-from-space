local composition = require("@helpers/composition")

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

t.world(
    [==[(
    name: "fixture row",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'l': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Light)),
    },
    rows: [
        "#######",
        "#.a..l#",
        "#.....#",
        "#######",
    ],
    items: [(1, 2, "crowbar")],
    structures: [(1, 2, "player_spawn"), (4, 1, "vent"), (2, 1, "apc")],
)]==],
    7
)

local p = t.join()
t.tick()
t.click(p, 1, 2, t.target_at(p, 1, 2, "crowbar")) -- the crowbar is underfoot
t.tick()
t.sounds(p) -- clear the pickup traffic
t.messages(p)

-- The APC's tile, from the walkway below it.
assert(composition.matches(2, 1, { "station_base", "floor_tiles" }), "the APC stands on a tiled floor")
t.click(p, 2, 1, nil, -14, 14)
t.tick()
assert(composition.matches(2, 1, { "station_base" }), "the tile under the APC comes up")
assert(has(t.items_at(2, 1), "floor_tile"), "and is refunded where it lay")
assert(has(t.messages(p), "You pry up the floor tile."), "the narration was not a lie")

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
t.click(p, 4, 1, nil, -14, 14)
t.tick()
assert(composition.matches(4, 1, { "station_base" }), "the tile under the vent comes up")
t.click(p, 5, 1, nil, -14, 14)
t.tick()
assert(composition.matches(5, 1, { "station_base" }), "and the one under the light")

-- Back the other way: a tile goes down on plating a fixture stands on.
walk("west", 3)
t.drop(p) -- put the crowbar down; the hand is for the tile
t.tick()
t.click(p, 2, 1, t.target_at(p, 2, 1, "floor_tile")) -- pick the pried tile back up
t.tick()
t.messages(p)
t.click(p, 2, 1, nil, -14, 14) -- and lay it
-- Half a second, pinned from both sides: plating already did the
-- structural work, so the finish on top is the quick half
-- (content/structures/construction/plating.luau:28).
t.run_seconds(0.3)
assert(composition.matches(2, 1, { "station_base" }), "half a second of tiling is half a second")
t.run_seconds(0.7)
assert(composition.matches(2, 1, { "station_base", "floor_tiles" }), "the tile goes back down under the APC")
assert(has(t.messages(p), "The floor is tiled."), "and says so")

-- Scenario 2: forcing a dead airlock is the OTHER crowbar sound.
t.world(
    [==[(
    name: "dead airlock",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '+': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Door)),
    },
    rows: [
        "#####",
        "#..+#",
        "#####",
    ],
    structures: [(1, 1, "player_spawn")],
    items: [(1, 1, "crowbar")],
    // One length of backbone with no generator behind it, which is a
    // station with the lights off: the airlock's motors never wake.
    networks: [
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
    ],
)]==],
    7
)

p = t.join()
t.run_ticks(30) -- let a power pass settle the dead motors
t.click(p, 1, 1, t.target_at(p, 1, 1, "crowbar")) -- the crowbar
t.tick()
t.move(p, "east")
t.run_ticks(6)
t.sounds(p)
t.click(p, 3, 1, t.target_at(p, 3, 1)) -- heave the unpowered airlock open
t.run_seconds(3.0)
local door_sounds = t.sounds(p)
assert(
    has(door_sounds, "crowbar_pry"),
    "forcing a door plays tg's operating_sound, the sustained heave"
)
assert(not has(door_sounds, "crowbar"), "and not the quick tile pop")
assert(has(t.messages(p), "The door gives way."), "the airlock opens")

-- Scenario 3: the same sheet, the other job. Laid on plating a tile is
-- the half-second finish above; laid on VACUUM it is a second and a
-- half of deck-laying, and what it leaves is bare plating, not a
-- finished floor (content/structures/construction/space.luau:12-21 --
-- the floor-tile row, the one that also says `anchored`).
--
-- This number is this pack's own and is cited to the file that chose
-- it. tg has no analogue to copy: getting a floor over vacuum there is
-- rods into a lattice and then a sheet on top (space.dm:212, :312),
-- and neither step is timed at all.
t.world(
    [==[(
    name: "breach",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "############",
        "#..........#",
        "#..........#",
        "#..........#",
        "############",
    ],
    structures: [(2, 1, "player_spawn")],
    items: [(2, 1, "floor_tile")],
)]==],
    7
)

p = t.join()
t.tick()
t.click(p, 2, 1, t.target_at(p, 2, 1, "floor_tile")) -- the tiles are underfoot
t.run_ticks(2)
assert(t.hands(p).held == "floor_tile", "a stack of tiles in hand")
t.fault(1, 1, t.now() + 1) -- the hull fails next door
t.run_ticks(40) -- a couple of atmos ticks of venting
assert(t.is_breached(1, 1), "the fault breached the corner")

t.messages(p)
t.click(p, 1, 1, nil, -14, 14) -- start laying deck over the vacuum
t.run_seconds(1.3)
assert(t.is_breached(1, 1), "a second and a half is not a second and a bit")
t.run_seconds(0.4)
assert(not t.is_breached(1, 1), "the plating closes the breach")
assert(
    composition.matches(1, 1, { "station_base" }),
    "and what a tile lays over vacuum is plating: " .. composition.describe(1, 1)
)
assert(has(t.messages(p), "The plating settles into place."), "and says so")
