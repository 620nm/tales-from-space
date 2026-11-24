-- Playtest entry: a playtest round plays at once and the pack seats
-- each joiner by assignment — no draft, no Ready, no countdown, and
-- no job board. Observed only through the body and rows a player
-- could cause.
local ROOM = [==[(
    name: "playtest entry room",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: ["#####", "#...#", "#####"],
            structures: [(1, 1, "player_spawn")],
        ),
    ],
)]==]

-- Space Station: the round is already playing before anyone connects,
-- and the first connect is admitted as an assistant under a generated
-- crew name without any preparation step.
t.world(ROOM, 7, "space_station", { playtest = true })
assert(t.round_status().phase == "playing", "a playtest round skips preparation")
local crew = t.connect()
t.run_ticks(10)
local crew_body = assert(t.body(crew), "the playtest assignment seats the joiner at connect")
assert(crew_body.animate, "and the body stands")
local x, y = t.pos(crew)
assert(x == 1 and y == 1, "at the map's spawn point")
local joined = t.ledger_rows("joined_job")
assert(#joined == 1 and joined[1].job == "assistant", "admitted as assistant")
local named = t.ledger_rows("mind_named")
assert(#named == 1, "one mind is named by the assignment")
local assigned_name = named[1].name
assert(
    type(assigned_name) == "string" and assigned_name:match("^%a+ %a+$") ~= nil,
    "under a generated crew name: " .. tostring(assigned_name)
)

-- No assignment can invent a spawn point: a playtest map with no
-- player_spawn marker admits nobody, and the round still plays.
local MARKERLESS = [==[(
    name: "playtest markerless",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: ["#####", "#...#", "#####"],
            structures: [],
        ),
    ],
)]==]

t.world(MARKERLESS, 7, "space_station", { playtest = true })
assert(t.round_status().phase == "playing", "the markerless playtest still plays")
local unseated = t.connect()
t.run_ticks(10)
local seated = pcall(function()
    return t.body(unseated)
end)
assert(not seated, "no marker, no body: the joiner stays bodiless")
assert(#t.ledger_rows("joined_job") == 0, "and no job admission is rowed")

-- The fallback tier: the only marker names another job and role, and a
-- playtester still lands on it. The same map in an ordinary Free
-- Build round seats nobody, so the fallback is the playtest's alone.
local FOREIGN_MARKER = [==[(
    name: "playtest foreign marker",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: ["#####", "#...#", "#####"],
            structures: [(2, 1, "player_spawn", { "jobs": "medic", "roles": "crew" })],
        ),
    ],
)]==]

t.world(FOREIGN_MARKER, 7, "free_build")
local ordinary = t.connect()
t.run_ticks(10)
local ordinary_seated = pcall(function()
    return t.body(ordinary)
end)
assert(not ordinary_seated, "an ordinary round honors the marker filters")

t.world(FOREIGN_MARKER, 7, "free_build", { playtest = true })
local builder = t.connect()
t.run_ticks(10)
assert(t.body(builder) ~= nil, "the playtest fallback seats the builder anyway")
x, y = t.pos(builder)
assert(x == 2 and y == 1, "on the only marker the map has")
assert(#t.ledger_rows("joined_job") == 0, "jobless: the kit is gear, not a job")
