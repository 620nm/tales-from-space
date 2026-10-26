local clock = require("@helpers/clock")

local COMPLETED_MESSAGE = "You climb onto the structure."
local CLOSED_TICKS: number
local OPEN_TICKS: number

local function target(player: number, x: number, y: number, id: string): SpecObservedTarget
    local observed = assert(t.target_at(player, x, y, id), "the observed support exists")
    return observed
end

local function has_message(messages: { string }, wanted: string): boolean
    for _, message in ipairs(messages) do
        if message == wanted then
            return true
        end
    end
    return false
end

local function support_rows(reason: string): { SpecLedgerRow }
    local rows = {}
    for _, row in ipairs(t.ledger_rows("support_transition")) do
        if row.reason == reason then
            table.insert(rows, row)
        end
    end
    return rows
end

local function start_closed_drag(player: number, from_x: number, from_y: number, x: number, y: number): ()
    t.drag(player, from_x, from_y, t.body_target(player, player), x, y, target(player, x, y, "crate"))
    t.tick()
end

local function start_open_alt(player: number, x: number, y: number): ()
    t.use_item(player, target(player, x, y, "crate"), "alt_primary")
    t.tick()
end

local function assert_offset(player: number, expected: number, label: string): ()
    assert(t.seen(player, player).offset.y == expected, label .. ": disclosed Y offset")
end

local function assert_position(player: number, x: number, y: number, label: string): ()
    local actual_x, actual_y = t.pos(player)
    assert(actual_x == x and actual_y == y, label .. ": " .. actual_x .. "," .. actual_y)
end

local MAP = [==[ (
    name: "crate climbing",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [(
        rows: [
            "#######",
            "#.....#",
            "#.....#",
            "#.....#",
            "#.....#",
            "#.....#",
            "#######",
        ],
        structures: [
            (2, 3, "player_spawn", { "jobs": "assistant" }),
            (3, 2, "player_spawn", { "jobs": "medic" }),
            (3, 3, "crate"),
        ],
    )],
)]==]

t.world(MAP, 0)
CLOSED_TICKS = clock.deadline_ticks(2.0)
OPEN_TICKS = clock.deadline_ticks(1.0)
local closed_actor = t.join("assistant")
local closed_helper = t.join("medic")
assert(closed_helper ~= nil, "the closed-drag world has two real players")
t.run_ticks(3)

start_closed_drag(closed_actor, 2, 3, 3, 3)
assert_position(closed_actor, 2, 3, "closed climb has not moved the actor at start")
assert_offset(closed_actor, 0, "closed climb starts on the floor")
t.run_ticks(CLOSED_TICKS - 1)
assert_position(closed_actor, 2, 3, "closed climb is not complete one tick early")
assert_offset(closed_actor, 0, "closed climb has no early elevation")
assert(#support_rows("mount") == 0, "closed climb has no early support row")
t.run_ticks(1)
assert_position(closed_actor, 3, 3, "closed climb commits at two seconds")
assert_offset(closed_actor, 14, "closed climb commits elevation")
assert(#support_rows("mount") == 1, "closed climb writes one mount transition")
local closed_receipt = t.messages(closed_actor)
assert(has_message(closed_receipt, COMPLETED_MESSAGE), "the matching closed request presents completed success")

t.move(closed_actor, "east")
t.run_seconds(0.25)
assert_position(closed_actor, 4, 3, "the rider steps off ordinarily")
assert_offset(closed_actor, 0, "step-off returns elevation to zero")
assert(#support_rows("step_off") == 1, "step-off writes one support transition")
assert(has_message(closed_receipt, COMPLETED_MESSAGE), "the committed receipt remains a success after step-off")
assert(not has_message(t.messages(closed_actor), "The climb fails."), "step-off does not rewrite the old receipt")
assert(#support_rows("mount") == 1, "step-off does not add a second mount")
assert(#t.script_errors() == 0, "closed self-drag has no script errors")

t.world(MAP, 0)
local open_actor = t.join("assistant")
local open_helper = t.join("medic")
t.run_ticks(3)
t.click(open_actor, 3, 3, target(open_actor, 3, 3, "crate"))
t.tick()
assert(assert(t.structure_at(3, 3)).state == "open", "the crate opens for the structure gesture")
start_open_alt(open_actor, 3, 3)
t.run_ticks(OPEN_TICKS - 1)
assert_position(open_actor, 2, 3, "open Alt+primary is not complete one tick early")
assert_offset(open_actor, 0, "open Alt+primary has no early elevation")
assert(#support_rows("mount") == 0, "open Alt+primary has no early support row")
t.run_ticks(1)
assert_position(open_actor, 3, 3, "open Alt+primary commits at one second")
assert_offset(open_actor, 14, "open Alt+primary commits elevation")
assert(#support_rows("mount") == 1, "open Alt+primary writes one mount transition")
assert(has_message(t.messages(open_actor), COMPLETED_MESSAGE), "the matching open request presents completed success")
assert(#t.script_errors() == 0, "open structure gesture has no script errors")
assert(open_helper ~= nil, "both real players remain joined for the gesture path")
print("crate climbing: closed drag and open Alt+primary boundaries and receipts")
