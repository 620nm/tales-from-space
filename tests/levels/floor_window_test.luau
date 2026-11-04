-- A hole and a floor window over a rock basement. R1 (level 0) has an Open
-- hole over its basement B1; R2 has a strip of two glass floors over B2. Both
-- let a body see down; only the hole lets air out and drops a body. The glass
-- floors hold both, join as one smoothing group (tg glass.dm:9-11), and show
-- the pipe beneath them without tool access (glass.dm:8). In orbit they hold a
-- body with the station's gravity, as plating does (step 7). A stack of them
-- shows exactly the pack's `levels.view.depth` levels down (step 8).
local composition = require("@helpers/composition")

local BASEMENT = -1
local TRACER = "co2"
local TRACER_MOLES = 12.0

t.world(
    [==[(
    name: "floor window",
    needs: ["gravity"],
    levels_below_ground: 1,
    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665), surface_temperature_k: Exact(259.15)),
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (substrate: Open)),
        'g': (composition: (substrate: Open, components: [(component: "glass_floor")])),
        'r': (composition: (substrate: Open, components: [(component: "reinforced_glass_floor")])),
        'R': (composition: (components: [(component: "rock")])),
        'c': (composition: ()),
    },
    levels: [
        (
            rows: [
                "RRRRRRRRR",
                "RcccRcccR",
                "RRRRRRRRR",
            ],
            structures: [],
        ),
        (
            rows: [
                "#########",
                "#.o.#.gr#",
                "#########",
            ],
            structures: [
                (1, 1, "player_spawn", { "jobs": "medic" }),
                (5, 1, "player_spawn", { "jobs": "assistant" }),
            ],
            networks: [
                (x: 6, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
                (x: 7, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
            ],
        ),
    ],
)]==],
    0,
    "free_build"
)
-- Nobody breathes: lungs would be a source and a sink in the tracer books.
t.set_breathing(false)

type RoomTile = { x: number, y: number }

local function tracer_over(tiles: { RoomTile }): number
    local sum = 0.0
    for _, tile in ipairs(tiles) do
        local gas = t.room_gas(tile.x, tile.y)
        sum = sum + (gas and gas[TRACER] or 0.0)
    end
    return sum
end

local R1: { RoomTile } = { { x = 1, y = 1 }, { x = 2, y = 1 }, { x = 3, y = 1 } }
local R2: { RoomTile } = { { x = 5, y = 1 }, { x = 6, y = 1 }, { x = 7, y = 1 } }

local hole_body = t.join("medic")
local window_body = t.join("assistant")
t.run_ticks(4)
local hx, hy = t.pos(hole_body)
assert(hx == 1 and hy == 1, "the hole room's body spawns at (1, 1), got (" .. hx .. ", " .. hy .. ")")
local wx, wy = t.pos(window_body)
assert(wx == 5 and wy == 1, "the window room's body spawns at (5, 1), got (" .. wx .. ", " .. wy .. ")")

-- 1. Sight down: through the hole and each window, not through solid floor.
-- Each body checks the floor it stands on: the level below draws 0.965 smaller
-- about the eye (content/capabilities.luau), so a hole also shows a sliver of
-- the tile beyond it, never the one under the eye.
assert(#t.seen_composition(hole_body, 2, 1, BASEMENT) > 0, "the basement shows through the hole")
assert(#t.seen_composition(hole_body, 1, 1, BASEMENT) == 0, "but not under R1's solid floor")
assert(#t.seen_composition(hole_body, 3, 1, BASEMENT) > 0, "the smaller level below shows a sliver past the hole")
assert(#t.seen_composition(window_body, 6, 1, BASEMENT) > 0, "the basement shows through the glass floor")
assert(#t.seen_composition(window_body, 7, 1, BASEMENT) > 0, "and through the reinforced glass floor")
assert(#t.seen_composition(window_body, 5, 1, BASEMENT) == 0, "but not under R2's solid floor")

-- 2. Air: the windows keep a room's tracer; the hole shares it with the basement.
-- A room and its basement hold three cells each (equal-volume levels), so
-- mixing through the hole settles at 3 / (3 + 3) = half the tracer in R1.
t.foul_room(1, 1, TRACER, TRACER_MOLES)
t.foul_room(5, 1, TRACER, TRACER_MOLES)
t.run_seconds(120)
local hole_room = tracer_over(R1)
local window_room = tracer_over(R2)
-- The bound is the settled half plus 10% slack for mixing still under way
-- after 120 s; the glass room's 1e-6 is room_air_test.luau's exact-sum slack.
assert(
    math.abs(window_room - TRACER_MOLES) < 1e-6,
    "the glass-floored room keeps all its tracer: " .. window_room
)
assert(
    hole_room < 0.55 * TRACER_MOLES,
    "the holed room lost tracer to its basement, settled half is " .. 0.5 * TRACER_MOLES .. ": " .. hole_room
)

-- 3. Support: glass holds a body on level 0; the hole drops it one level.
t.move(window_body, "east")
t.run_seconds(1)
wx, wy = t.pos(window_body)
assert(wx == 6 and wy == 1, "the body stands on the glass floor, got (" .. wx .. ", " .. wy .. ")")
assert(#t.ledger_rows("level_changed") == 0, "nothing has changed level yet")
t.move(hole_body, "east")
t.run_seconds(3)
local falls = t.ledger_rows("level_changed")
assert(#falls == 1, "one body fell, got " .. #falls)
assert(falls[1].via == "fall" and falls[1].levels == 1, "it fell one level through the hole")
hx, hy = t.pos(hole_body)
assert(hx == 2 and hy == 1, "the faller landed under the hole, got (" .. hx .. ", " .. hy .. ")")

-- 4. Smoothing across the group. The west window has an east neighbour: bit
-- EAST = 1 << 2 = 4. The east window has a west neighbour: bit WEST = 1 << 3 = 8
-- (the engine's crates/lunatic-content/src/structures/junction_bits.rs). Walls to
-- the north and south are no glass, so no other bit is set.
local west = composition.seen_sprites(window_body, 6, 1)
assert(west.components[1] == "glass_floor-4", "the west window joins east, got " .. tostring(west.components[1]))
local east = composition.seen_sprites(window_body, 7, 1)
assert(
    east.components[1] == "reinforced_glass_floor-8",
    "the east window joins west, got " .. tostring(east.components[1])
)

-- 5. Underfloor visible, not accessible.
local pipe_rows = 0
for _, row in ipairs(t.seen_composition(window_body, 7, 1)) do
    if row.kind == "network" then pipe_rows = pipe_rows + 1 end
end
assert(pipe_rows > 0, "the pipe under the window is shown")
assert(t.network_exposed(7, 1, "pipe") == false, "but cannot be tooled through the glass")

-- 6. The lowest level refuses a floor whose preset opens the substrate.
-- The fallen body, beside the basement floor tile (3, 1), sees it.
local before = composition.seen_sprites(hole_body, 3, 1, BASEMENT)
assert(before.substrates[1] ~= nil, "the basement floor tile shows its substrate")
assert(not t.set_composition(3, 1, "glass_floor", BASEMENT), "an Open substrate is refused on the lowest level")
t.run_ticks(2)
local after = composition.seen_sprites(hole_body, 3, 1, BASEMENT)
assert(
    after.substrates[1] == before.substrates[1] and #after.components == #before.components,
    "the refused tile is unchanged"
)

-- 7. Gravity in orbit: glass receives the station field, so a body stepping
-- onto it from station base stops there. Without it the glass would be
-- weightless and the body would coast east to the wall. Nothing within one tile
-- of (2, 2) braces a body (docs/TURFS.md "Gravity and handholds"); the basement
-- is blank, because dense terrain one level below a neighbour braces too.
t.world(
    [==[(
    name: "glass in orbit",
    levels_below_ground: 1,
    environment: (kind: Exact(space), gravity_m_s2: Exact(9.80665)),
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '_': (composition: (components: [(component: "station_base")])),
        'g': (composition: (substrate: Open, components: [(component: "glass_floor")])),
        'c': (composition: ()),
    },
    levels: [
        (
            rows: [
                "cccccccc",
                "cccccccc",
                "cccccccc",
                "cccccccc",
                "cccccccc",
            ],
            structures: [],
        ),
        (
            rows: [
                "########",
                "#gggggg#",
                "#_ggggg#",
                "#gggggg#",
                "########",
            ],
            structures: [(1, 2, "player_spawn")],
        ),
    ],
)]==],
    0,
    "space_station"
)
local orbiter = t.join()
t.run_ticks(4)
local ox, oy = t.pos(orbiter)
assert(ox == 1 and oy == 2, "the orbiter spawns on station base at (1, 2), got (" .. ox .. ", " .. oy .. ")")
t.move(orbiter, "east")
t.run_seconds(2)
ox, oy = t.pos(orbiter)
assert(ox == 2 and oy == 2, "the station field holds a body on glass in orbit, got (" .. ox .. ", " .. oy .. ")")

-- 8. See-down depth: a glass shaft through four levels shows three of them,
-- the pack's `levels.view.depth` (content/capabilities.luau). Glass, not a
-- hole, because an open tile has nothing to see.
local DEPTH = 3
local GLASS_SHAFT_LEVEL = [[        (
            rows: ["#####", "#.g.#", "#####"],
            structures: [],
        ),
]]
t.world(
    [==[(
    name: "glass shaft",
    needs: ["gravity"],
    levels_below_ground: 4,
    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665), surface_temperature_k: Exact(259.15)),
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'g': (composition: (substrate: Open, components: [(component: "glass_floor")])),
    },
    levels: [
        (
            rows: ["#####", "#...#", "#####"],
            structures: [],
        ),
]==]
        .. string.rep(GLASS_SHAFT_LEVEL, 3)
        .. [==[        (
            rows: ["#####", "#.g.#", "#####"],
            structures: [(1, 1, "player_spawn")],
        ),
    ],
)]==],
    0,
    "free_build"
)
local looker = t.join()
t.run_ticks(4)
for depth = 1, DEPTH do
    assert(#t.seen_composition(looker, 2, 1, -depth) > 0, "the shaft shows level " .. -depth)
end
assert(#t.seen_composition(looker, 2, 1, -(DEPTH + 1)) == 0, "the shaft hides level " .. -(DEPTH + 1) .. ", past the view depth")
