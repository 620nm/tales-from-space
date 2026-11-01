-- A rock basement in orbit (the asteroid look): the same map as
-- rock_basement_test.luau, but the rock lies on rock floor, so digging the rock
-- reveals rock floor, tg's asteroid sand (minerals.dm:29). The map pins standard
-- gravity, which a space environment applies to receiving surfaces (the
-- engine's docs/mapping/environment.md), and rock floor receives it, so the
-- carved room holds the body without any station base.
local composition = require("@helpers/composition")

-- Rock wears `rock-<junction>`; the arithmetic is in rock_basement_test.luau (the
-- carved room is no rock, so it counts like the open room there).
local SPACE_SPRITE = "space"
local ROCK_FLOOR_SPRITE = "rock_floor"
local BASEMENT = -1

t.world(
    [==[(
    name: "rock asteroid",
    tags: ["space"],
    levels_below_ground: 1,
    environment: (kind: Exact(space), gravity_m_s2: Exact(9.80665)),
    legend: {
        '#': (composition: (substrate: Named("rock_floor"), components: [(component: "rock")])),
        '.': (composition: (substrate: Named("rock_floor"))),
    },
    levels: [
        (
            rows: [
                "#######",
                "#######",
                "#....##",
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
    "space_station"
)

local p = t.join()
t.run_ticks(4)

-- 1. The body stands in the carved room on the basement.
local x, y = t.pos(p)
assert(x == 1 and y == 2, "the body spawns in the carved room, got (" .. x .. ", " .. y .. ")")
local room = composition.seen_sprites(p, 2, 2, BASEMENT)
assert(room.substrates[1] == ROCK_FLOOR_SPRITE, "the room beside the body is rock floor, got " .. tostring(room.substrates[1]))

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

-- 5. The rock floor preset digs to rock floor, which holds the body; the bare
-- preset writes the inherited substrate, so it reveals space instead.
assert(t.set_composition(1, 1, "rock_floor", BASEMENT), "the rock floor preset removes the rock")
t.run_ticks(2)
local dug = composition.seen_sprites(p, 1, 1, BASEMENT)
assert(dug.substrates[1] == ROCK_FLOOR_SPRITE, "the dug tile shows rock floor, got " .. tostring(dug.substrates[1]))
assert(#dug.components == 0, "the dug tile has no rock row")
east = composition.seen_sprites(p, 2, 1, BASEMENT)
assert(east.components[1] == "rock-21", "the rock east of the dug tile loses its W and NW bits, got " .. tostring(east.components[1]))
t.move(p, "north")
t.run_seconds(1)
x, y = t.pos(p)
assert(x == 1 and y == 1, "the body steps onto the dug rock floor, got (" .. x .. ", " .. y .. ")")
assert(t.set_composition(1, 3, "bare", BASEMENT), "the bare preset removes the rock")
t.run_ticks(2)
local bare = composition.seen_sprites(p, 1, 3, BASEMENT)
assert(bare.substrates[1] == SPACE_SPRITE, "the bare tile shows space, got " .. tostring(bare.substrates[1]))

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
    "space_station"
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

-- 7. Rock floor receives the station field in orbit. A patch of it in open
-- space, out of reach of any wall or lattice for a handhold, lets the body step
-- (gravity_movement_test.luau: bare space refuses the same step).
t.world(
    [==[(
    name: "rock floor patch",
    tags: ["space"],
    environment: (kind: Exact(space), gravity_m_s2: Exact(9.80665)),
    legend: {
        's': (composition: (substrate: Named("space"))),
        'r': (composition: (substrate: Named("rock_floor"))),
    },
    levels: [
        (
            rows: [
                "sssssss",
                "sssssss",
                "ssrrrss",
                "ssrrrss",
                "ssrrrss",
                "sssssss",
                "sssssss",
            ],
            structures: [(3, 3, "player_spawn")],
        ),
    ],
)]==],
    0,
    "space_station"
)
local walker = t.join()
t.run_ticks(2)
t.move(walker, "east")
t.tick()
x, y = t.pos(walker)
assert(x == 4 and y == 3, "the body steps along rock floor in orbit, got (" .. x .. ", " .. y .. ")")

-- 8. Rock floor is no vacuum boundary: a tracer in a sealed rock-floor pocket in
-- orbit stays, where an unsealed vacuum substrate would vent it (the 1e-6
-- exact-sum slack of rock_basement_test.luau, step 6). The body waits in the
-- next pocket, so its lungs do not touch the tracer.
t.world(
    [==[(
    name: "rock floor room",
    tags: ["space"],
    environment: (kind: Exact(space), gravity_m_s2: Exact(9.80665)),
    legend: {
        '#': (composition: (components: [(component: "rock")])),
        '.': (composition: (substrate: Named("rock_floor"))),
    },
    levels: [
        (
            rows: [
                "#####",
                "#.#.#",
                "#####",
            ],
            structures: [(3, 1, "player_spawn")],
        ),
    ],
)]==],
    0,
    "space_station"
)
t.join()
t.run_ticks(2)
local TRACER_MOLES = 12.0
assert(t.foul_room(1, 1, "co2", TRACER_MOLES), "the tracer reaches the rock-floor room")
t.run_seconds(8)
local held = t.room_gas(1, 1)
assert(
    held ~= nil and math.abs((held["co2"] or 0.0) - TRACER_MOLES) < 1e-6,
    "a rock-floor room in orbit keeps its air: " .. TRACER_MOLES .. " -> " .. tostring(held and held["co2"])
)
