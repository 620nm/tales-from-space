-- Scored spawn choice: exact job beats category beats general, a
-- named role beats an unnamed one, an unused point beats a used
-- one, and the fallback-attributed marker answers only when
-- nothing better fits. Positions are what the bodies report.
local LEGEND = [[
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },]]

local EXACT = string.format(
    [==[(
    name: "spawn choice exactness",
%s
    levels: [
        (
            rows: ["##############", "#............#", "##############"],
            structures: [
                (1, 1, "player_spawn"),
                (2, 1, "player_spawn", { "jobs": "engineer" }),
                (3, 1, "player_spawn", { "jobs": "medical" }),
            ],
        ),
    ],
)]==],
    LEGEND
)

t.world(EXACT, 0, "space_station")
local engineer = t.join("engineer")
local x, y = t.pos(engineer)
assert(x == 2 and y == 1, "the exact job lands on its own marker")
local medic = t.join("medic")
x, y = t.pos(medic)
assert(x == 3 and y == 1, "with no medic marker, the medical category answers")
local assistant = t.join("assistant")
x, y = t.pos(assistant)
assert(x == 1 and y == 1, "with neither, the general marker answers")

-- A role tag scores only when it is not the mode's default role:
-- roles=crew on a general marker does not outrank an exact-job
-- marker in the station round, where crew is everyone's role. A
-- non-default role (an antagonist) rides the same tier when
-- something stamps it.
local ROLED = string.format(
    [==[(
    name: "spawn choice role",
%s
    levels: [
        (
            rows: ["##############", "#............#", "##############"],
            structures: [
                (1, 1, "player_spawn", { "roles": "crew" }),
                (2, 1, "player_spawn", { "jobs": "engineer" }),
            ],
        ),
    ],
)]==],
    LEGEND
)

t.world(ROLED, 0, "space_station")
local station_engineer = t.join("engineer")
x, y = t.pos(station_engineer)
assert(x == 2 and y == 1, "the exact job beats a default-role-tagged general marker")

-- Unused first: two joins at one tier land on two different points
-- while unused points remain.
local PAIR = string.format(
    [==[(
    name: "spawn choice unused",
%s
    levels: [
        (
            rows: ["##############", "#............#", "##############"],
            structures: [
                (1, 1, "player_spawn"),
                (2, 1, "player_spawn"),
            ],
        ),
    ],
)]==],
    LEGEND
)

t.world(PAIR, 0, "space_station")
local first = t.join("assistant")
local second = t.join("assistant")
local fx, _ = t.pos(first)
local sx, _ = t.pos(second)
assert(fx ~= sx, "the second join takes the unused point")

-- Fallback last: a job nothing fits lands on the fallback-attributed
-- marker, never on a merely filtered one; with no fallback authored
-- the join is refused outright.
local FALLBACK = string.format(
    [==[(
    name: "spawn choice fallback",
%s
    levels: [
        (
            rows: ["##############", "#............#", "##############"],
            structures: [
                (2, 1, "player_spawn", { "jobs": "medic" }),
                (3, 1, "player_spawn", { "jobs": "engineer", "fallback": true }),
            ],
        ),
    ],
)]==],
    LEGEND
)

t.world(FALLBACK, 0, "space_station")
local security = t.join("security")
x, y = t.pos(security)
assert(x == 3 and y == 1, "no fit lands on the fallback marker, not a filtered one")

local NO_FALLBACK = string.format(
    [==[(
    name: "spawn choice no fallback",
%s
    levels: [
        (
            rows: ["##############", "#............#", "##############"],
            structures: [
                (2, 1, "player_spawn", { "jobs": "medic" }),
            ],
        ),
    ],
)]==],
    LEGEND
)

t.world(NO_FALLBACK, 0, "space_station")
local seated = pcall(function()
    return t.join("security")
end)
assert(not seated, "with no fallback authored, an unfit join is refused")

