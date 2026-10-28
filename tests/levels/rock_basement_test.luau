-- A rock basement on a planet: rock blocks a body, shows itself but hides
-- what is under and behind it, can be painted into a room, and digging it
-- out (the `bare` preset) reveals the planet's ground; on ground level one rock
-- between two pockets keeps a gas apart. tg /turf/closed/mineral
-- (minerals.dm:6-51). Level -1 lists first: `levels_below_ground: 1`.
local composition = require("@helpers/composition")

-- Rock wears `rock-<junction>` (tg `smoothrocks-<junction>`, minerals.dm:10-12,21). The
-- junction packs the rock cardinal neighbours (N=1 S=2 E=4 W=8; the map edge is none),
-- plus a corner bit (NE=16 SE=32 SW=64 NW=128) only when both cardinals beside it are
-- set and the diagonal is rock too (the engine's
-- crates/lunatic-server/src/structures/junction_bits.rs). On the map below
-- (x across, y down):
--   (1,1): N+E+W = 13, NE (2,0) 16, NW (0,0) 128          = 157
--   (2,1): N+E+W = 13, NE (3,0) 16, NW (1,0) 128          = 157
--   (0,2): N+S = 3 (west is the map edge)                  = 3
--   (0,1): N+S+E = 7, NE (1,0) 16 (SE (1,2) is open)       = 23
--   (1,3): S+E+W = 14, SE (2,4) 32, SW (0,4) 64            = 110
-- Digging (1,1) drops that bit from its neighbours: (2,1) keeps N+E and NE = 21;
-- (0,1) keeps N+S = 3. Painting (4,2) adds one: (4,1) gains S and SE = 191
-- (15+16+32+128); (4,3) gains N and NE = 127 (15+16+32+64); (4,2) itself has
-- N+S+E = 7, NE 16, SE 32 = 55.
local GROUND_SPRITE = "ground"
local BASEMENT = -1

local function rock_at(player: number, x: number, y: number): string
    local seen = composition.seen_sprites(player, x, y, BASEMENT)
    assert(#seen.components == 1, "tile (" .. x .. ", " .. y .. ") shows one rock row, got " .. #seen.components)
    return seen.components[1]
end

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
assert(#near.components == 1 and near.components[1] == "rock-157", "the adjacent rock shows its rock row, got " .. tostring(near.components[1]))
assert(#near.substrates == 0, "rock hides the substrate under it, got " .. tostring(near.substrates[1]))
assert(#t.seen_composition(p, 1, 0, BASEMENT) == 0, "the rock behind the near rock is not disclosed")

-- 3b. Each rock joins the rock around it: different neighbours, different junction.
assert(rock_at(p, 2, 1) == "rock-157", "rock above-right joins N, E, W and both upper corners")
assert(rock_at(p, 0, 2) == "rock-3", "rock at the map edge joins only N and S")
assert(rock_at(p, 0, 1) == "rock-23", "rock above the edge joins N, S, E and the NE corner only")
assert(rock_at(p, 1, 3) == "rock-110", "rock below the room joins S, E, W and both lower corners")
assert(rock_at(p, 4, 1) == "rock-157", "rock above the painted tile's spot has an open south")
assert(rock_at(p, 4, 3) == "rock-110", "rock below the painted tile's spot has an open north")

-- 4. Painting rock into the room.
assert(t.set_composition(4, 2, "rock", BASEMENT), "an empty room tile accepts the rock preset")
t.run_ticks(2)
local painted = composition.seen_sprites(p, 4, 2, BASEMENT)
assert(painted.components[1] == "rock-55", "the painted tile shows the rock row joined N, S, E and the upper and lower east corners, got " .. tostring(painted.components[1]))
assert(#painted.substrates == 0, "the painted rock hides the ground under it")
assert(rock_at(p, 4, 1) == "rock-191", "the rock above the painted tile gains its south and SE bits")
assert(rock_at(p, 4, 3) == "rock-127", "the rock below the painted tile gains its north and NE bits")

-- 5. Digging reveals the substrate and opens the way.
assert(t.set_composition(1, 1, "bare", BASEMENT), "the bare preset removes the rock")
t.run_ticks(2)
local dug = composition.seen_sprites(p, 1, 1, BASEMENT)
assert(dug.substrates[1] == GROUND_SPRITE, "the dug tile shows the planet's ground, got " .. tostring(dug.substrates[1]))
assert(#dug.components == 0, "the dug tile has no rock row")
assert(rock_at(p, 2, 1) == "rock-21", "the rock east of the dug tile loses its west and NW bits")
assert(rock_at(p, 0, 1) == "rock-3", "the rock west of the dug tile loses its east and NE bits")
t.move(p, "north")
t.run_seconds(1)
x, y = t.pos(p)
assert(x == 1 and y == 1, "the body steps into the dug tile, got (" .. x .. ", " .. y .. ")")

-- 5b. The rock floor preset paints the planet's natural rock floor over the dug
-- ground; it holds the body like ground does.
assert(t.set_composition(1, 1, "rock_floor", BASEMENT), "the rock floor preset replaces the ground")
t.run_ticks(2)
local floor = composition.seen_sprites(p, 1, 1, BASEMENT)
assert(floor.substrates[1] == "rock_floor", "the painted tile shows rock floor, got " .. tostring(floor.substrates[1]))
t.move(p, "south")
t.run_seconds(1)
x, y = t.pos(p)
assert(x == 1 and y == 2, "the body leaves the rock floor, got (" .. x .. ", " .. y .. ")")
t.move(p, "north")
t.run_seconds(1)
x, y = t.pos(p)
assert(x == 1 and y == 1, "the body walks back onto the rock floor, got (" .. x .. ", " .. y .. ")")

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

-- 7. A hole cut in the ground closes under the natural fill. The `open` preset
-- opens ground-level terrain; rock and bare (the `inherit` substrate word) close
-- it. The lowest level refuses an Open tile, so the editor's stuck-validation
-- case (a hole painted over with rock) is checked here on level 0.
assert(not t.set_composition(1, 1, "open", BASEMENT), "the lowest level refuses the open preset")
assert(t.set_composition(1, 1, "open", 0), "the open preset cuts a hole in ground-level terrain")
assert(t.composition(1, 1).substrate == "open", "the cut tile's substrate is open")
assert(t.set_composition(1, 1, "rock", 0), "rock fills the hole")
assert(t.composition(1, 1).substrate == nil, "rock over a hole clears the opening")
assert(t.set_composition(1, 1, "open", 0), "the hole is cut again")
assert(t.set_composition(1, 1, "bare", 0), "bare fills the hole")
assert(t.composition(1, 1).substrate == nil, "bare over a hole clears the opening")
