-- A rock basement on a planet: rock blocks a body, shows itself but hides
-- what is under and behind it, can be painted into a room, and digging it
-- out (the `bare` preset) reveals the planet's ground; on ground level one rock
-- between two pockets keeps a gas apart. tg /turf/closed/mineral
-- (minerals.dm:6-51). Level -1 lists first: `levels_below_ground: 1`.
local composition = require("@helpers/composition")

local ROCK_SPRITE = "rock"
local GROUND_SPRITE = "ground"
local BASEMENT = -1

t.world(
    [==[(
    name: "rock basement",
    tags: ["terrestrial"],
    levels_below_ground: 1,
    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665)),
    legend: {
        '#': (composition: (components: [(component: "rock")])),
        '.': (composition: ()),
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
                "#######",
                "#.#.###",
                "#######",
                "#######",
                "#######",
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
local own = composition.seen_sprites(p, 1, 2, BASEMENT)
assert(own.substrates[1] == GROUND_SPRITE, "the room floor is the planet's ground, got " .. tostring(own.substrates[1]))
assert(#t.seen_composition(p, 1, 2) == #t.seen_composition(p, 1, 2, BASEMENT), "the unnamed read is the body's own basement")

-- 2. Rock blocks movement.
t.move(p, "west")
t.run_seconds(1)
x, y = t.pos(p)
assert(x == 1 and y == 2, "rock blocks a step west, got (" .. x .. ", " .. y .. ")")

-- 3. Rock is seen, hides what is under it, and hides what is behind it.
local near = composition.seen_sprites(p, 1, 1, BASEMENT)
assert(#near.components == 1 and near.components[1] == ROCK_SPRITE, "the adjacent rock shows its rock row")
assert(#near.substrates == 0, "rock hides the substrate under it, got " .. tostring(near.substrates[1]))
assert(#t.seen_composition(p, 1, 0, BASEMENT) == 0, "the rock behind the near rock is not disclosed")

-- 4. Painting rock into the room.
assert(t.set_composition(4, 2, "rock", BASEMENT), "an empty room tile accepts the rock preset")
t.run_ticks(2)
local painted = composition.seen_sprites(p, 4, 2, BASEMENT)
assert(painted.components[1] == ROCK_SPRITE, "the painted tile shows the rock row")
assert(#painted.substrates == 0, "the painted rock hides the ground under it")

-- 5. Digging reveals the substrate and opens the way.
assert(t.set_composition(1, 1, "bare", BASEMENT), "the bare preset removes the rock")
t.run_ticks(2)
local dug = composition.seen_sprites(p, 1, 1, BASEMENT)
assert(dug.substrates[1] == GROUND_SPRITE, "the dug tile shows the planet's ground, got " .. tostring(dug.substrates[1]))
assert(#dug.components == 0, "the dug tile has no rock row")
t.move(p, "north")
t.run_seconds(1)
x, y = t.pos(p)
assert(x == 1 and y == 1, "the body steps into the dug tile, got (" .. x .. ", " .. y .. ")")

-- 6. Rock blocks gas: ground-level pockets (1, 1) and (3, 1) are one rock
-- apart. A tracer put in the west pocket stays there, both pockets to the
-- mole (room_air_test.luau's 1e-6 exact-sum slack). One open cell between
-- them would mix the pockets well within the span (floor_window_test.luau
-- settles a 3+3-cell hole in 120 s).
local TRACER = "co2"
local TRACER_MOLES = 12.0
local function tracer_at(tx: number, ty: number): number
    local gas = t.room_gas(tx, ty)
    return gas and gas[TRACER] or 0.0
end
assert(t.foul_room(1, 1, TRACER, TRACER_MOLES), "the tracer reaches the west pocket")
local west_start, east_start = tracer_at(1, 1), tracer_at(3, 1)
t.run_seconds(60)
assert(
    math.abs(tracer_at(1, 1) - west_start) < 1e-6,
    "rock keeps the tracer in the west pocket: " .. west_start .. " -> " .. tracer_at(1, 1)
)
assert(
    math.abs(tracer_at(3, 1) - east_start) < 1e-6,
    "no tracer crosses the rock into the east pocket: " .. east_start .. " -> " .. tracer_at(3, 1)
)
