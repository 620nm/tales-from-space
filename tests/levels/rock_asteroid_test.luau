-- A rock basement in orbit (the asteroid look): the same map as
-- rock_basement_test.luau, but digging the rock reveals space. The map pins
-- standard gravity, which a space environment applies to receiving surfaces
-- (the engine's docs/mapping/environment.md), so the spawn tile's station base
-- holds the body and rock still blocks it. Only that tile carries station base,
-- because a body cannot join on bare space.
local composition = require("@helpers/composition")

-- Rock wears `rock-<junction>`; the arithmetic is in rock_basement_test.luau (the
-- station-base tile at (1,2) is no rock, so it counts like the open room there).
local SPACE_SPRITE = "space"
local BASEMENT = -1

t.world(
    [==[(
    name: "rock asteroid",
    tags: ["space"],
    levels_below_ground: 1,
    environment: (kind: Exact(space), gravity_m_s2: Exact(9.80665)),
    legend: {
        '#': (composition: (components: [(component: "rock")])),
        '.': (composition: ()),
        '_': (composition: (components: [(component: "station_base")])),
    },
    levels: [
        (
            rows: [
                "#######",
                "#######",
                "#_...##",
                "#######",
                "#######",
            ],
            structures: [(1, 2, "player_spawn")],
        ),
        (
            rows: [
                ".......",
                ".......",
                ".......",
                ".......",
                ".......",
            ],
            structures: [],
        ),
    ],
)]==],
    0,
    "free_build"
)

local p = t.join()
t.run_ticks(4)

-- 1. The body stands in the carved room on the basement.
local x, y = t.pos(p)
assert(x == 1 and y == 2, "the body spawns in the carved room, got (" .. x .. ", " .. y .. ")")
local room = composition.seen_sprites(p, 2, 2, BASEMENT)
assert(room.substrates[1] == SPACE_SPRITE, "the room beside the body is space in orbit, got " .. tostring(room.substrates[1]))

-- 2. Rock blocks movement.
t.move(p, "west")
t.run_seconds(1)
x, y = t.pos(p)
assert(x == 1 and y == 2, "rock blocks a step west, got (" .. x .. ", " .. y .. ")")

-- 3. Rock is seen, hides what is under it, and hides what is behind it.
local near = composition.seen_sprites(p, 1, 1, BASEMENT)
assert(#near.components == 1 and near.components[1] == "rock-157", "the adjacent rock shows its rock row, got " .. tostring(near.components[1]))
assert(#near.substrates == 0, "rock hides the substrate under it, got " .. tostring(near.substrates[1]))
assert(#t.seen_composition(p, 1, 0, BASEMENT) == 0, "the rock behind the near rock is not disclosed")
local edge = composition.seen_sprites(p, 0, 2, BASEMENT)
assert(edge.components[1] == "rock-3", "rock at the map edge joins only N and S, got " .. tostring(edge.components[1]))

-- 3b. A rock's picture follows its neighbours; digging changes them (step 5).
local east = composition.seen_sprites(p, 2, 1, BASEMENT)
assert(east.components[1] == "rock-157", "the rock east of the future dig joins W, N, E and both upper corners")

-- 5. Digging reveals space.
assert(t.set_composition(1, 1, "bare", BASEMENT), "the bare preset removes the rock")
t.run_ticks(2)
local dug = composition.seen_sprites(p, 1, 1, BASEMENT)
assert(dug.substrates[1] == SPACE_SPRITE, "the dug tile shows space, got " .. tostring(dug.substrates[1]))
assert(#dug.components == 0, "the dug tile has no rock row")
east = composition.seen_sprites(p, 2, 1, BASEMENT)
assert(east.components[1] == "rock-21", "the rock east of the dug tile loses its W and NW bits, got " .. tostring(east.components[1]))

-- 6. Rock roofs what is under it: on a level above ground a rock over the
-- inherited sky leaves no opening to the room below, which keeps its air where
-- blank sky would vent it (open_sky_space_test.luau). Either of rock's
-- `gas_blocking` (no air cell to open) and `substrate_seal` closes the roof on
-- its own; dropping both vents the room. Same space environment, 8 s span and
-- 0.05 kPa read tolerance as that spec. Rock's `support` holds up what lies on
-- it: a crowbar on a roof tile turned to rock stays put. Dug bare, the tile is
-- an opening to open space, which pulls nothing: the crowbar floats over it
-- and is never asked to fall (tg zFall needs gravity, code/game/turfs/turf.dm:
-- 352 `can_z_move`; the engine's docs/sim/level-movement.md §Support loss).
t.world(
    [==[(
    name: "rock roof",
    tags: ["space"],
    environment: (kind: Exact(space), gravity_m_s2: Exact(9.80665)),
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'r': (composition: (components: [(component: "rock")])),
        '_': (composition: (components: [(component: "station_base")])),
    },
    levels: [
        (
            rows: [
                "#####",
                "#...#",
                "#####",
            ],
            structures: [],
        ),
        (
            rows: [
                "#####",
                "#r_r#",
                "#####",
            ],
            structures: [],
            items: [(2, 1, "crowbar")],
        ),
    ],
)]==],
    0,
    "free_build"
)
local ROOF = 1
assert(t.set_composition(2, 1, "rock", ROOF), "the rock preset replaces the station base under the crowbar")
t.run_ticks(2)
assert(#t.ledger_rows("level_changed") == 0, "rock holds up the crowbar lying on it")
assert(#t.items_at(2, 1, ROOF) == 1, "the crowbar stays on the rock roof")
local roofed_start = assert(t.room_pressure(2, 1))
assert(math.abs(roofed_start - 101.325) < 0.05, "the roofed room starts at one atmosphere, got " .. roofed_start)
t.run_seconds(8)
for rx = 1, 3 do
    local pressure = assert(t.room_pressure(rx, 1))
    assert(
        math.abs(pressure - roofed_start) < 0.05,
        "a rock roof keeps the room's air at (" .. rx .. ", 1): " .. roofed_start .. " -> " .. pressure
    )
end
assert(t.set_composition(2, 1, "bare", ROOF), "the bare preset digs the roof tile")
t.run_ticks(4)
assert(#t.ledger_rows("level_changed") == 0, "a weightless opening drops nothing")
assert(#t.ledger_rows("item_fall_stayed") == 0, "nor asks: open space pulls nothing")
assert(#t.items_at(2, 1, ROOF) == 1, "the crowbar floats over the dug roof tile")
