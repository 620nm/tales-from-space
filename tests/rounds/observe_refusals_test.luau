-- What the observer way out refuses (content/lib/observe.luau): a press
-- after the grant is gone, a second press in one tick, a dead body, and a
-- way back whose body is gone. The way back never needs the grant.
local ui_controls = require("@helpers/ui_controls")

t.world(
    [==[(
    name: "observer refusals",
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "##########",
                "#........#",
                "##########",
            ],
            structures: [(1, 1, "player_spawn"), (2, 1, "player_spawn"), (3, 1, "player_spawn"), (5, 1, "player_spawn"), (7, 1, "player_spawn"), (8, 1, "player_spawn")],
        ),
    ],
)]==],
    7,
    "free_build"
)

-- A staff member with Control, connected again so the grant is read.
local function staff_with_control(n: number): number
    local profile = string.format("%064x", n)
    local player = t.connect(profile)
    t.tick()
    assert(t.staff_grant(player, "control"), "control is a staff permission")
    t.disconnect(player)
    player = t.connect(profile)
    t.tick()
    assert(t.ui(player, "observe") ~= nil, "staff with Control are offered the way out")
    return player
end

local function press(player: number): ()
    ui_controls.press(player, "/action/0")
    t.run_ticks(4)
end

local function plan(player: number): string?
    local body = t.body(player)
    return if body ~= nil then body.plan else nil
end

local function seats(): number
    return #t.ledger_rows("MindSeated")
end

-- A grant gone while the panel is open: the press of the way out spawns
-- nothing. The snapshot a grant writes names only that word.
local revoked = staff_with_control(4201)
local rx, ry = t.pos(revoked)
local present = #t.bodies_at(rx, ry)
assert(t.staff_grant(revoked, "observe"), "observe replaces control")
press(revoked)
assert(plan(revoked) == "human", "no grant, no way out")
assert(#t.bodies_at(rx, ry) == present, "and no observer was spawned")
assert(seats() == 0, "nor anybody seated")

-- Two presses back to back: the first is applied before the second is
-- read, so the second meets the panel's next offer, the way back. Never a
-- second observer, never a refused seat.
local double = staff_with_control(4202)
local dx, dy = t.pos(double)
local beside = #t.bodies_at(dx, dy)
local node = ui_controls.node(double, "/action/0")
t.ui_press(double, node.id)
t.ui_press(double, node.id)
t.run_ticks(4)
assert(plan(double) == "human", "out and straight back")
assert(#t.bodies_at(dx, dy) == beside, "the one observer is removed")
assert(seats() == 2, "two seats")
press(double)
assert(plan(double) == "observer", "out again")
assert(seats() == 3, "a third seat")

-- The body left behind is gone: the way back is refused, the observer stays.
local left = nil
for _, body in t.bodies_at(dx, dy) do
    if body.plan == "human" then
        left = body
    end
end
assert(t.destroy(assert(left, "the body left behind").id) == nil, "the left body is removed")
press(double)
assert(plan(double) == "observer", "stranded, still observing")
assert(seats() == 3, "nobody was seated")
assert(t.ui(double, "observe") ~= nil, "and the panel still offers the way back")

-- A grant revoked while observing: the way back needs none, and the panel
-- closes once they are home. On reconnect the return is forced.
local home = staff_with_control(4203)
press(home)
assert(plan(home) == "observer", "out")
assert(t.staff_grant(home, "observe"), "observe replaces control")
press(home)
assert(plan(home) == "human", "back without the grant")
assert(t.ui(home, "observe") == nil, "and offered nothing more")
assert(t.staff_grant(home, "control"), "control again")
t.disconnect(home)
home = t.connect(string.format("%064x", 4203))
t.tick()
press(home)
assert(plan(home) == "observer", "out again")
assert(t.staff_grant(home, "observe"), "observe replaces control")
t.disconnect(home)
home = t.connect(string.format("%064x", 4203))
t.run_ticks(4)
assert(plan(home) == "human", "a reconnect without the grant goes home")
assert(t.ui(home, "observe") == nil, "with nothing offered")

-- A grant revoked while observing, with no press and no reconnect: the
-- mode's sweep sends them home within its period.
local swept = staff_with_control(4205)
press(swept)
assert(plan(swept) == "observer", "out")
assert(t.staff_grant(swept, "observe"), "observe replaces control")
t.run_seconds(3)
assert(plan(swept) == "human", "the sweep sent them home")
assert(t.ui(swept, "observe") == nil, "and the panel closed")

-- A grant revoked while observing, the left body destroyed: within the
-- sweep the panel is gone and the observer stops, a dead player's state.
-- The mode's respawn route then gives a fresh body, and no observer stays.
local spent = staff_with_control(4206)
local ex, ey = t.pos(spent)
local left_id = t.body_id(spent)
press(spent)
assert(plan(spent) == "observer", "out")
assert(t.destroy(left_id) == nil, "the left body is removed")
assert(t.staff_grant(spent, "observe"), "observe replaces control")
t.run_seconds(3)
assert(t.ui(spent, "observe") == nil, "the panel is gone")
local stopped = assert(t.body(spent))
assert(stopped.plan == "observer" and not stopped.animate, "the observer stopped")
t.respawn(spent)
t.run_seconds(3)
local fresh = assert(t.body(spent))
assert(fresh.plan == "human" and fresh.animate, "the mode's respawn gave a fresh body")
for _, body in t.bodies_at(ex, ey) do
    assert(body.plan ~= "observer", "and no observer remains")
end

-- A dead staff member presses the way out: a corpse is no body to leave
-- (the reconnect viewpoint over it is observe_station_test.luau's).
local dead = staff_with_control(4204)
local before = seats()
local kx, ky = t.pos(dead)
local standing = #t.bodies_at(kx, ky)
assert(t.staff_kill(dead), "the body dies")
press(dead)
assert(seats() == before, "a corpse is no body to leave")
assert(#t.bodies_at(kx, ky) == standing, "and no observer was spawned")

assert(#t.ledger_rows("ScriptEffectRefused") == 0, "no effect was refused")
assert(#t.script_errors() == 0, "no handler raised")
