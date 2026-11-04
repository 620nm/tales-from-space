-- A covered room in space: a glass floor with one bare Open tile in it, on the
-- top level of its map, over a deck. The roof of a map is closed, so the room
-- holds its air and the hole shares it only with the level below. The bare tile
-- has no weight of its own: a body drifts across it while the deck under it is
-- weightless, and once a gravity battery holds that deck the tile drops a body
-- and a thrown crowbar. With a level over the room, that level's open floor
-- shares the room's air and no sky is presumed above it (the engine's
-- `docs/mapping/environment.md` "Exposure", `docs/netcode/gravity.md`).
local ui_controls = require("@helpers/ui_controls")

local ONE_ATM_KPA = 101.325
local READ_TOLERANCE_KPA = 0.05
-- A 5x5 room crosses the hazard line through one hole to vacuum inside this
-- span (open_sky_space_test.luau:VENT_SPAN_S); this room would be well on its way.
local VENT_SPAN_S = 8
local TRACER = "co2"
local TRACER_MOLES = 12.0
-- Six equal cells over a shared opening settle at half; the slack is
-- floor_window_test.luau's for mixing still under way after 120 s.
local MIX_SPAN_S = 120
local SETTLED_SHARE = 0.5
local MIX_SLACK = 0.05

local LOWER = -1
local HOLE = { x = 9, y = 3 }
local BATTERY = { x = 3, y = 3 }

local function assert_holds_air(x: number, y: number, why: string)
    local pressure = assert(t.room_pressure(x, y))
    assert(
        math.abs(pressure - ONE_ATM_KPA) < READ_TOLERANCE_KPA,
        why .. ": (" .. x .. ", " .. y .. ") holds " .. pressure .. " kPa"
    )
end

t.world(
    [==[(
    name: "covered room",
    levels_below_ground: 1,
    environment: (kind: Exact(space), gravity_m_s2: Exact(0.0)),
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'g': (composition: (substrate: Open, components: [(component: "glass_floor")])),
        'o': (composition: (substrate: Open)),
    },
    levels: [
        (
            rows: [
                "#############",
                "#...........#",
                "#...........#",
                "#...........#",
                "#...........#",
                "#...........#",
                "#############",
            ],
            structures: [],
        ),
        (
            rows: [
                "#############",
                "#...........#",
                "#.......ggg.#",
                "#.......gog.#",
                "#.......ggg.#",
                "#...........#",
                "#############",
            ],
            structures: [
                (5, 2, "player_spawn", { "jobs": "engineer" }),
                (9, 1, "player_spawn", { "jobs": "assistant" }),
                (9, 5, "player_spawn", { "jobs": "medic" }),
                (11, 3, "player_spawn", { "jobs": "security" }),
                (3, 3, "grav_smes", "standby"),
            ],
            items: [(9, 5, "crowbar")],
        ),
    ],
)]==],
    0,
    "free_build"
)
assert(t.environment().kind == "space", "the map rolls a space environment: " .. t.environment().id)
assert(
    assert(t.environment().profile).gravity_m_s2 == 0,
    "the sky has no field of its own: " .. t.environment().id
)
t.set_breathing(false)
local operator = t.join("engineer")
local walker = t.join("assistant")
local thrower = t.join("medic")
local drifter = t.join("security")
t.run_ticks(4)

-- 1. Air: the roof over the top level is closed, so the bare tile vents nothing.
assert_holds_air(HOLE.x, HOLE.y, "the bare tile starts on room air")
assert_holds_air(1, 1, "the room starts at one atmosphere")
t.run_seconds(VENT_SPAN_S)
assert_holds_air(HOLE.x, HOLE.y, "a bare tile under a closed roof holds its air")
assert_holds_air(1, 1, "and so does the room around it")

-- 2. No field: a body pushing off the wall drifts over the bare tile and stays
-- on its level, for the deck under the tile is weightless too.
t.move(drifter, "west")
t.run_seconds(1.5)
local drifted_to = t.pos(drifter)
assert(drifted_to < HOLE.x, "the drift crosses the bare tile, got x = " .. drifted_to)
assert(#t.ledger_rows("level_changed") == 0, "a weightless floor lends the bare tile no weight")

-- 3. The battery comes up. Its field stands on the decks, never on the bare tile.
t.set_store_charge(BATTERY.x, BATTERY.y, 1.0)
t.click(
    operator,
    BATTERY.x + 1,
    BATTERY.y,
    t.target_at(operator, BATTERY.x + 1, BATTERY.y, "grav_smes")
)
t.run_ticks(2)
ui_controls.toggle(operator, "action", "start")
t.run_seconds(3.2)
local battery = tostring(assert(t.structure_at(BATTERY.x, BATTERY.y)).state)
assert(string.find(battery, "^active") ~= nil, "the battery is up, got " .. battery)

-- 4. A crowbar thrown onto the bare tile falls to the deck below it.
t.click(thrower, HOLE.x, 5, t.target_at(thrower, HOLE.x, 5, "crowbar"))
t.run_ticks(2)
assert(t.hands(thrower).held == "crowbar", "the crowbar is in hand")
t.throw(thrower, HOLE.x, HOLE.y)
t.run_seconds(3)
local falls = t.ledger_rows("level_changed")
assert(#falls == 1 and falls[1].via == "fall", "the crowbar fell, got " .. #falls .. " rows")
local under = t.items_at(HOLE.x, HOLE.y, LOWER)
assert(#under == 1 and under[1] == "crowbar", "the crowbar lies on the deck under the hole")
assert(#t.items_at(HOLE.x, HOLE.y, 0) == 0, "nothing is left over the hole")

-- 5. So does a body stepping onto it.
t.move(walker, "south")
t.run_seconds(0.6)
local wx, wy = t.pos(walker)
assert(wx == HOLE.x and wy == HOLE.y - 1, "the glass holds the walker, got (" .. wx .. ", " .. wy .. ")")
assert(#t.ledger_rows("level_changed") == 1, "only the crowbar has fallen yet")
t.move(walker, "south")
t.run_seconds(3)
falls = t.ledger_rows("level_changed")
assert(#falls == 2, "a body fell too, got " .. #falls .. " rows")
assert(falls[2].via == "fall" and falls[2].levels == 1, "it fell one level, via " .. tostring(falls[2].via))
wx, wy = t.pos(walker)
assert(wx == HOLE.x and wy == HOLE.y, "the walker landed under the hole, got (" .. wx .. ", " .. wy .. ")")

-- 6. A level over the room: its open floor joins the two rooms' air, and the
-- closed roof over it lets none of it go. Reads are the lower room, level 0.
t.world(
    [==[(
    name: "room under a room",
    environment: (kind: Exact(space), gravity_m_s2: Exact(0.0)),
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (substrate: Open)),
    },
    levels: [
        (
            rows: [
                "#####",
                "#...#",
                "#####",
            ],
            structures: [(1, 1, "player_spawn")],
        ),
        (
            rows: [
                "#####",
                "#ooo#",
                "#####",
            ],
            structures: [],
        ),
    ],
)]==],
    0,
    "free_build"
)
t.set_breathing(false)
t.foul_room(1, 1, TRACER, TRACER_MOLES)
t.run_seconds(MIX_SPAN_S)
local tracer = 0.0
for x = 1, 3 do
    local gas = assert(t.room_gas(x, 1))
    tracer = tracer + (gas[TRACER] or 0.0)
end
assert(
    math.abs(tracer - SETTLED_SHARE * TRACER_MOLES) < MIX_SLACK * TRACER_MOLES,
    "the open floor above shares the tracer, settled half is "
        .. SETTLED_SHARE * TRACER_MOLES
        .. ": "
        .. tracer
)
-- The tracer adds to the room, so a lost mole shows as a fall below one atmosphere.
local held = assert(t.room_pressure(2, 1))
assert(held > ONE_ATM_KPA, "a room with a level over it loses nothing to a presumed sky: " .. held .. " kPa")
