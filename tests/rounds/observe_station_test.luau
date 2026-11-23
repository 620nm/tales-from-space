-- Staff with Control leave their body for an observer and come back, in
-- Space Station (content/lib/observe.luau). A disconnect while observing
-- changes nothing: the reconnect finds the observer and is offered the
-- way back, which still leads to the waiting body.
local ui_controls = require("@helpers/ui_controls")

local COUNTDOWN = 120
local PROFILE = string.format("%064x", 4102)

t.world(
    [==[(
    name: "observer bay",
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "######",
                "#....#",
                "######",
            ],
            structures: [(1, 1, "player_spawn"), (3, 1, "player_spawn")],
        ),
    ],
)]==],
    7,
    "space_station"
)

local staff = t.connect(PROFILE)
assert(t.staff_grant(staff, "control"), "control is a staff permission")
t.disconnect(staff)
staff = t.connect(PROFILE)
assert(t.prepare(staff, { name = "Grace Hopper", ranked_jobs = { "engineer" }, fallback = false }))
assert(t.ready(staff))
t.preparation_steps(COUNTDOWN * t.tick_hz())
assert(t.round_status().phase == "playing", "the cohort is admitted")
assert(assert(t.body(staff)).plan == "human", "staff start in their own body")

ui_controls.press(staff, "/action/0")
t.run_ticks(4)
assert(assert(t.body(staff)).plan == "observer", "staff now ride the observer")

-- Gone and back: still observing, and offered the way home.
t.disconnect(staff)
t.run_ticks(4)
staff = t.connect(PROFILE)
t.run_ticks(4)
assert(assert(t.body(staff)).plan == "observer", "the reconnect finds the observer")
assert(t.ui(staff, "observe") ~= nil, "and the document again")

ui_controls.press(staff, "/action/0")
t.run_ticks(4)
local body = assert(t.body(staff))
assert(body.plan == "human" and body.animate, "back in the living body they left")
assert(#t.ledger_rows("MindSeated") == 2, "out and back are two seats")
assert(#t.ledger_rows("MobDespawned") == 1, "and the observer is removed")

-- Dead, then reconnected: the Mind rides the engine's viewpoint over the
-- corpse, which has no body. Pressing the way out leaves nothing behind.
local x, y = t.pos(staff)
assert(t.staff_kill(staff), "the body dies")
t.disconnect(staff)
t.run_ticks(4)
staff = t.connect(PROFILE)
t.run_ticks(4)
assert(t.body(staff) == nil, "the reconnect rides a viewpoint with no body")
assert(t.ui(staff, "observe") ~= nil, "still offered the way out")
ui_controls.press(staff, "/action/0")
t.run_ticks(4)
assert(t.body(staff) == nil, "which a bodiless viewpoint cannot take")
assert(#t.bodies_at(x, y) == 1, "no observer beside the corpse")
assert(#t.ledger_rows("MindSeated") == 2, "nobody was seated")
assert(#t.ledger_rows("ScriptEffectRefused") == 0, "no effect was refused")
assert(#t.script_errors() == 0, "no handler raised")
