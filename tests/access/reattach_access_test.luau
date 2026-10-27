-- A mind that drops its session and reattaches to its living body keeps the
-- body's access: the card the body wears still opens the leaf afterwards.
local access_bench = require("@helpers/access_bench")

local LEAF = 5
local COUNTDOWN = 120

t.world(
    access_bench.source(
        "reattach bench",
        access_bench.spawn("engineer", 3) .. ", (5, 1, \"airlock.engineering\")",
        ""
    ),
    7,
    "space_station"
)
local profile = string.format("%064x", 91)
local first = t.connect(profile)
assert(t.prepare(first, { name = "Reattach Tester", ranked_jobs = { "engineer" }, fallback = false }))
assert(t.ready(first))
t.preparation_steps(COUNTDOWN * t.tick_hz())
assert(t.round_status().phase == "playing", "the cohort is admitted")
local body = t.body_id(first)

access_bench.bump(first, LEAF)
assert(assert(t.door_at(LEAF, 1)).open, "the engineer's worn card opens the leaf before the drop")
access_bench.wait_until_shut(LEAF)

t.disconnect(first)
t.run_ticks(4)
local returned = t.connect(profile)
t.run_ticks(6)
assert(t.body_id(returned) == body, "the mind reattaches to the same living body")
assert(t.worn(returned).id == "id_engineering", "and the body still wears its engineering card")

access_bench.bump(returned, LEAF)
assert(assert(t.door_at(LEAF, 1)).open, "the reattached body's access still opens the leaf")
