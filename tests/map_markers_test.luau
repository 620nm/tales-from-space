-- Marker selection is observed through the body a player receives. The
-- markers themselves are deliberately invisible to that player.
local FILTERED = [==[(
    name: "marker filters",
    legend: {
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "######",
        "#....#",
        "######",
    ],
    structures: [
        (1, 1, "player_spawn", { "jobs": "medic", "roles": "builder" }),
        (2, 1, "player_spawn", { "jobs": "medic", "roles": "crew" }),
        (3, 1, "player_spawn", { "jobs": "engineer" }),
        (4, 1, "threat_spawn", { "weight": 0 }),
    ],
)]==]

-- Space Station's default role is crew. The medic therefore lands at the
-- crew point, not at the same-job point reserved for another role.
t.world(FILTERED, 0, "space_station")
assert(#t.ledger_rows("mob_spawned") == 0,
    "threat markers do not spawn mobs during map boot")
local medic = t.join("medic")
local x, y = t.pos(medic)
assert(x == 2 and y == 1, "the medic uses the matching job and role marker")

-- A different job cannot borrow a filtered point. The engineer point is
-- the only eligible location for this join.
local engineer = t.join("engineer")
x, y = t.pos(engineer)
assert(x == 3 and y == 1, "the engineer uses its job marker")

local ok = pcall(function()
    t.join("assistant")
end)
assert(not ok, "a job with no matching marker is refused")

-- Free Build supplies its own default role. This exercises the same
-- marker schema with a different mode policy.
local FREE_BUILD = [==[(
    name: "builder markers",
    legend: { '.': (turf: Floor), '#': (turf: Wall) },
    rows: ["#####", "#...#", "#####"],
    structures: [
        (1, 1, "player_spawn", { "roles": "builder" }),
        (2, 1, "player_spawn", { "roles": "crew" }),
    ],
)]==]

t.world(FREE_BUILD, 0, "free_build")
local builder = t.join()
x, y = t.pos(builder)
assert(x == 1 and y == 1, "Free Build uses its builder role marker")

-- Zero disables a point. A positive point remains usable beside it.
local DISABLED = [==[(
    name: "disabled marker",
    legend: { '.': (turf: Floor), '#': (turf: Wall) },
    rows: ["#####", "#...#", "#####"],
    structures: [
        (1, 1, "player_spawn", { "weight": 0 }),
        (2, 1, "player_spawn", { "weight": 1 }),
    ],
)]==]

t.world(DISABLED, 0, "space_station")
local available = t.join("engineer")
x, y = t.pos(available)
assert(x == 2 and y == 1, "a zero-weight marker is never selected")

-- A 99:1 pair should visibly favour its high-weight point over a bounded
-- sample of late joins. The fixed seed makes this regression reproducible.
local WEIGHTED = [==[(
    name: "weighted markers",
    legend: { '.': (turf: Floor), '#': (turf: Wall) },
    rows: ["#####", "#...#", "#####"],
    structures: [
        (1, 1, "player_spawn", { "weight": 99 }),
        (2, 1, "player_spawn", { "weight": 1 }),
    ],
)]==]

t.world(WEIGHTED, 37, "space_station")
local favoured = 0
local sample = 32
for _ = 1, sample do
    local player = t.join("engineer")
    x, y = t.pos(player)
    if x == 1 and y == 1 then
        favoured += 1
    end
end
assert(favoured >= 24,
    "relative weights favour the 99-point marker (" .. favoured .. "/" .. sample .. ")")
