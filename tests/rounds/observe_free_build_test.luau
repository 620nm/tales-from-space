-- Staff with Control leave their body for an observer and come back, in
-- Free Build (content/lib/observe.luau). The crew is never sent the
-- observer; the body left behind waits where it stood. Space Station's
-- half, with a reconnect while observing, is observe_station_test.luau.
local ui_controls = require("@helpers/ui_controls")

t.world(
    [==[(
    name: "observer room",
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
    "free_build"
)

local PROFILE = string.format("%064x", 4101)
local crew = t.join()
local staff = t.connect(PROFILE)
t.tick()
assert(t.ui(crew, "observe") == nil, "a crewman without Control is offered nothing")
assert(t.ui(staff, "observe") == nil, "nor is staff before the grant")

-- The grant is read at connect, so staff reconnect to be offered it.
assert(t.staff_grant(staff, "control"), "control is a staff permission")
t.disconnect(staff)
staff = t.connect(PROFILE)
t.tick()
local x, y = t.pos(staff)
assert(t.ui(staff, "observe") ~= nil, "staff with Control are offered the way out")

ui_controls.press(staff, "/action/0")
t.run_ticks(4)
assert(assert(t.body(staff)).plan == "observer", "staff now ride the observer")
assert(t.seen(staff).kind ~= "unseen", "and see their own observer")
assert(t.seen(crew, staff).kind == "unseen", "the crew is never sent it")
assert(#t.ledger_rows("MindSeated") == 1, "one seat, in the ledger")

ui_controls.press(staff, "/action/0")
t.run_ticks(4)
assert(assert(t.body(staff)).plan == "human", "back in the body they left")
local back_x, back_y = t.pos(staff)
assert(back_x == x and back_y == y, "which waited where it stood")
assert(t.seen(crew, staff).kind == "player", "and the crew sees them again")
assert(#t.ledger_rows("MindSeated") == 2, "the return is a second seat")
assert(#t.ledger_rows("MobDespawned") == 1, "and the observer is removed")
assert(#t.ledger_rows("ScriptEffectRefused") == 0, "no effect was refused")
assert(#t.script_errors() == 0, "no handler raised")
