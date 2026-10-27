-- A mind that reattaches to its living body finds the body's access as the body
-- holds it now. While the mind is gone a second player strips the engineering ID
-- off the body, so the reattached body is refused at the engineering leaf; once a
-- card is back in its hand it is admitted. The reconnect's own re-derive is
-- pinned by engine tests.
local access_bench = require("@helpers/access_bench")
local clock = require("@helpers/clock")
local ui_controls = require("@helpers/ui_controls")

local LEAF = 5
local COUNTDOWN = 120
local ENGINEER_PROFILE = string.format("%064x", 91)
local STRIPPER_PROFILE = string.format("%064x", 92)

t.world(
    access_bench.source(
        "reattach bench",
        access_bench.spawn("engineer", 3)
            .. ", "
            .. access_bench.spawn("assistant", 2)
            .. ", (5, 1, \"airlock.engineering\")",
        ""
    ),
    7,
    "space_station"
)
local first = t.connect(ENGINEER_PROFILE)
assert(t.prepare(first, {
    name = "Reattach Tester",
    ranked_jobs = { "engineer" },
    fallback = false,
}))
assert(t.ready(first))
local stripper = t.connect(STRIPPER_PROFILE)
assert(t.prepare(stripper, {
    name = "Reattach Stripper",
    ranked_jobs = { "assistant" },
    fallback = false,
}))
assert(t.ready(stripper))
t.preparation_steps(COUNTDOWN * t.tick_hz())
assert(t.round_status().phase == "playing", "the cohort is admitted")
local body = t.body_id(first)
assert(t.worn(first).id == "id_engineering", "the engineer wears the engineering ID")
-- Taken while the mind is still attached; the stripper aims at this body later.
local victim = t.body_target(stripper, first)

access_bench.bump(first, LEAF)
assert(assert(t.door_at(LEAF, 1)).open, "the worn engineering ID opens the leaf before the drop")
access_bench.wait_until_shut(LEAF)

-- ---- the mind is gone; the stripper takes the ID off the body it left -------
t.disconnect(first)
t.run_ticks(4)
t.move(stripper, "east")
t.run_ticks(5)
assert(t.pos(stripper) == 3, "the stripper stands beside the sleeping body")
t.drag(stripper, 4, 1, victim, 3, 1, t.body_target(stripper, stripper))
t.run_ticks(2)
ui_controls.toggle(stripper, "strip", "id")
t.run_ticks(clock.deadline_ticks(4.0) + 5) -- the strip's 4 s default, as for a jumpsuit
assert(
    table.find(t.items_at(4, 1), "id_engineering") ~= nil,
    "the ID lands at the sleeping body's feet"
)

-- ---- the mind comes back to a body with no ID on it ------------------------
local returned = t.connect(ENGINEER_PROFILE)
t.run_ticks(6)
assert(t.body_id(returned) == body, "the mind reattaches to the same living body")
assert(t.worn(returned).id == nil, "and the body now wears no ID")

local refused = #t.ledger_rows("door_denied")
access_bench.bump(returned, LEAF)
assert(not assert(t.door_at(LEAF, 1)).open, "the reattached body is refused without its ID")
assert(#t.ledger_rows("door_denied") > refused, "and the refusal is on the record")

-- ---- a card back in its hand admits it -------------------------------------
t.click(returned, 4, 1, assert(t.target_at(returned, 4, 1, "id_engineering")))
t.run_ticks(2)
assert(t.hands(returned).held == "id_engineering", "the reattached body picks the ID up")
access_bench.bump(returned, LEAF)
assert(assert(t.door_at(LEAF, 1)).open, "the card in its hand admits the reattached body")
