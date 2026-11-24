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

-- Free Build is the local playtest drop-in: a playtest boot of the
-- real mode seats the mapper at connect by the pack's assignment
-- alone — jobless, under a generated name, at the spawn point.
-- Without the mode's assign handler this connect stays bodiless:
-- a playtest round runs no connection spawn of its own.
t.world(ROOM, 7, "free_build", { playtest = true })
assert(t.round_status().phase == "playing", "the Free Build playtest plays at once")
local builder = t.connect()
t.run_ticks(10)
local builder_body = assert(t.body(builder), "the assignment seats the mapper at connect")
assert(builder_body.animate, "and the body stands")
local bx, by = t.pos(builder)
assert(bx == 1 and by == 1, "at the map's spawn point")
assert(#t.ledger_rows("joined_job") == 0, "jobless: the kit is gear, not a job")
local builder_named = t.ledger_rows("mind_named")
assert(#builder_named == 1, "one mind is named by the assignment")
local builder_name = builder_named[1].name
assert(
    type(builder_name) == "string" and builder_name:match("^%a+ %a+$") ~= nil,
    "under a generated crew name: " .. tostring(builder_name)
)

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
local heard = table.concat(t.messages(unseated), " | ")
assert(
    heard:find("no spawn point", 1, true) ~= nil,
    "and the joiner is told why, in words: " .. heard
)

-- The fallback tier: the only marker names another job and role, and
-- a playtester still lands on it. The fallback is every round's: the
-- same map in an ordinary Free Build round seats its joiner too.
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
assert(t.body(ordinary) ~= nil, "an ordinary round falls back too")
x, y = t.pos(ordinary)
assert(x == 2 and y == 1, "on the only marker the map has")

t.world(FOREIGN_MARKER, 7, "free_build", { playtest = true })
local fallback_builder = t.connect()
t.run_ticks(10)
assert(t.body(fallback_builder) ~= nil, "the playtest fallback seats the builder anyway")
x, y = t.pos(fallback_builder)
assert(x == 2 and y == 1, "on the only marker the map has")
assert(#t.ledger_rows("joined_job") == 0, "jobless: the kit is gear, not a job")
