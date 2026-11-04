-- What crosses a level is the pack's answer (`content/lib/level_crossing.luau`,
-- bound by both modes): sound and speech pass an open hole or a glass floor
-- both ways, and a visible message reaches only viewers above. A hand
-- reaches another level only from a flight (`reach`, `via = "link"`;
-- tests/levels/flight_view_test.luau, which also specs its refusal through a
-- hole). Sound comes
-- from picking up a wrench (the wrench's own `wrench_pickup`,
-- tests/verbs/handling_test.luau), a visible message from the IV stand's
-- needle (`iv_drip.attach_start`, a room broadcast).
local iv_drip = require("@helpers/iv_drip")

local PICKUP = "wrench_pickup"
local NEEDLE = "The IV drip needle begins attaching."

local function heard(player: number, sound: string): boolean
    return table.find(t.sounds(player), sound) ~= nil
end

local function said(player: number, line: string): boolean
    for _, message in ipairs(t.messages(player)) do
        if string.find(message, line, 1, true) ~= nil then
            return true
        end
    end
    return false
end

local function pick_up(player: number, x: number, y: number)
    local wrench = assert(t.target_at(player, x, y, "wrench"), "the wrench is disclosed")
    t.click(player, x, y, wrench)
    t.run_ticks(2)
    assert(t.hands(player).held == "wrench", "the wrench is in hand")
end

-- A hole room (x 1-4: hole at 2-3) and a glass room (x 6-9: glass at 7-8),
-- each over its own basement room. Bodies stand in the columns under and over
-- the openings: the basement bodies at (2,1) and (7,1), the upper glass body
-- on the glass at (7,1), the upper hole body beside the hole at (1,1).
t.world(
    [==[(
    name: "level crossing sound",
    needs: ["gravity"],
    levels_below_ground: 1,
    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665), surface_temperature_k: Exact(259.15)),
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (substrate: Open)),
        'g': (composition: (substrate: Open, components: [(component: "glass_floor")])),
        'R': (composition: (components: [(component: "rock")])),
        'c': (composition: (substrate: Named("ground"))),
    },
    levels: [
        (
            rows: [
                "RRRRRRRRRRR",
                "RccccRccccR",
                "RRRRRRRRRRR",
            ],
            structures: [
                (2, 1, "player_spawn", { "jobs": "medic" }),
                (7, 1, "player_spawn", { "jobs": "engineer" }),
            ],
            items: [(3, 1, "wrench"), (8, 1, "wrench")],
        ),
        (
            rows: [
                "###########",
                "#.oo.#.gg.#",
                "###########",
            ],
            structures: [
                (1, 1, "player_spawn", { "jobs": "assistant" }),
                (7, 1, "player_spawn", { "jobs": "security" }),
            ],
            items: [(8, 1, "wrench")],
        ),
    ],
)]==],
    0,
    "free_build"
)

local below_hole = t.join("medic")
local above_hole = t.join("assistant")
local below_glass = t.join("engineer")
local above_glass = t.join("security")
t.run_ticks(4)
for player, want in pairs({ [below_hole] = 2, [above_hole] = 1, [below_glass] = 7, [above_glass] = 7 }) do
    local x, y = t.pos(player)
    assert(x == want and y == 1, "a body spawns at (" .. want .. ", 1), got (" .. x .. ", " .. y .. ")")
end
for _, player in ipairs({ below_hole, above_hole, below_glass, above_glass }) do
    local _ = t.sounds(player)
end

-- 1. Sound under an open hole is heard above.
pick_up(below_hole, 3, 1)
assert(heard(above_hole, PICKUP), "the body above the hole hears the pickup below it")

-- 2. Sound under a glass floor is heard above ("window" passage).
for _, player in ipairs({ below_hole, above_hole, below_glass, above_glass }) do
    local _ = t.sounds(player)
end
pick_up(below_glass, 8, 1)
assert(heard(above_glass, PICKUP), "the body on the glass hears the pickup beneath it")

-- 3. Sound above a glass floor is heard below.
for _, player in ipairs({ below_hole, above_hole, below_glass, above_glass }) do
    local _ = t.sounds(player)
end
pick_up(above_glass, 8, 1)
assert(heard(below_glass, PICKUP), "the body under the glass hears the pickup above it")

-- 4. Speech under the hole is heard above, beside the hole: the passage is read
-- at the speaker's column (2,1), not the listener's floor (1,1).
local _ = t.messages(above_hole)
t.say(below_hole, "up through the hole")
t.run_ticks(2)
assert(said(above_hole, "up through the hole"), "the body beside the hole hears the voice below it")

-- 5. A visible message below a hole is seen above; one above a glass floor is
-- not seen below. The stand's starter and patient stand on its level, the
-- watcher on the other, and the stand sits under the hole or on the glass.
local TEXT_HEADER = [==[(
    name: "level crossing text",
    needs: ["gravity"],
    levels_below_ground: 1,
    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665), surface_temperature_k: Exact(259.15)),
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (substrate: Open)),
        'g': (composition: (substrate: Open, components: [(component: "glass_floor")])),
        'R': (composition: (components: [(component: "rock")])),
        'c': (composition: (substrate: Named("ground"))),
    },
    levels: [
]==]
local TEXT_FOOTER = [==[    ],
)]==]
local STAND_LEVEL = [==[        (
            rows: ["RRRRR", "RcccR", "RcccR", "RRRRR"],
            structures: [
                (1, 1, "player_spawn", { "jobs": "medic" }),
                (1, 2, "player_spawn", { "jobs": "assistant" }),
                (2, 1, "iv_drip"),
            ],
            items: [(2, 1, "beaker")],
        ),
]==]
local WATCH_LEVEL = [==[        (
            rows: ["RRRRR", "RcccR", "RcccR", "RRRRR"],
            structures: [(1, 1, "player_spawn", { "jobs": "engineer" })],
            items: [],
        ),
]==]
local HOLE_ABOVE_WATCHER = [==[        (
            rows: ["#####", "#.o.#", "#...#", "#####"],
            structures: [(1, 1, "player_spawn", { "jobs": "engineer" })],
            items: [],
        ),
]==]
local GLASS_ABOVE_STAND = [==[        (
            rows: ["#####", "#.g.#", "#...#", "#####"],
            structures: [
                (1, 1, "player_spawn", { "jobs": "medic" }),
                (1, 2, "player_spawn", { "jobs": "assistant" }),
                (2, 1, "iv_drip"),
            ],
            items: [(2, 1, "beaker")],
        ),
]==]

-- Starts the needle on the stand at (2,1) and reports whether the watcher
-- and the starter were told.
local function needle_seen(world: string): (boolean, boolean)
    t.world(world, 0, "free_build")
    local starter = t.join("medic")
    local patient = t.join("assistant")
    local watcher = t.join("engineer")
    t.run_ticks(4)
    iv_drip.mount(starter, "beaker", 2, 1, 2, 1)
    local _ = t.messages(watcher)
    local _ = t.messages(starter)
    assert(iv_drip.drag_to_patient(starter, 2, 1, patient) ~= nil, "the needle starts")
    t.run_ticks(2)
    return said(watcher, NEEDLE), said(starter, NEEDLE)
end

-- The stand sits in the basement under the hole, the watcher above it.
local below_seen, below_told = needle_seen(TEXT_HEADER .. STAND_LEVEL .. HOLE_ABOVE_WATCHER .. TEXT_FOOTER)
assert(below_told, "the starter is told the needle begins")
assert(below_seen, "the watcher above sees the message from below")

-- The stand sits on the glass, the watcher in the basement beneath it.
local above_seen, above_told = needle_seen(TEXT_HEADER .. WATCH_LEVEL .. GLASS_ABOVE_STAND .. TEXT_FOOTER)
assert(above_told, "the starter is told the needle begins")
-- Pins the engine's R1 (no upward deep set), not the handler: no candidate forms.
assert(not above_seen, "the watcher below does not see the message from above")
