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

local function joined_player_id(index: number): number
    local row = assert(t.ledger_rows("joined_job")[index])
    local actor = row.actor
    assert(actor.kind == "player", "the join row identifies a player")
    return actor.id
end

local function assert_forced_exits(expected: number, actor_id: number, label: string): ()
    local rows = support_rows("support_ineligible")
    assert(#rows == expected, label .. ": exact forced-launch transition count")
    local moved_rows = t.ledger_rows("moved")
    local used_causes: { [number]: boolean } = {}
    for _, row in ipairs(rows) do
        local actor = row.actor
        assert(actor.kind == "script", label .. ": the closet handler owns the forced transition")
        assert(actor.file == "fixtures/closets.luau", label .. ": the closet fixture owns the transition")
        assert(actor.triggered_by == actor_id, label .. ": the attacking player owns the transition")
        local cause = assert(row.cause, label .. ": every forced transition has a cause")
        assert(not used_causes[cause], label .. ": forced transitions have distinct causes")
        used_causes[cause] = true
        local moved: SpecLedgerRow? = nil
        for _, candidate in ipairs(moved_rows) do
            if candidate.seq == cause then
                moved = candidate
                break
            end
        end
        assert(moved ~= nil, label .. ": every forced transition is caused by an actual Moved row")
        local moved_actor = moved.actor
        assert(moved_actor.kind == "script", label .. ": the causal move has script attribution")
        assert(moved_actor.triggered_by == actor_id, label .. ": the causal move names the attacker")
    end
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
t.run_ticks(5)
t.click(closed_helper, 3, 3, target(closed_helper, 3, 3, "crate"))
t.tick()
assert(assert(t.structure_at(3, 3)).state == "open", "the helper opens the support during the wait")
t.run_ticks(CLOSED_TICKS - 7)
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
t.run_ticks(5)
t.click(open_helper, 3, 3, target(open_helper, 3, 3, "crate"))
t.tick()
assert(assert(t.structure_at(3, 3)).state == "closed", "the helper closes the support during the wait")
t.run_ticks(OPEN_TICKS - 7)
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
t.world(MAP, 0)
local resting_actor = t.join("assistant")
t.run_ticks(3)
start_closed_drag(resting_actor, 2, 3, 3, 3)
t.run_ticks(5)
t.rest(resting_actor, true)
t.tick()
t.run_ticks(CLOSED_TICKS + 1)
assert_position(resting_actor, 2, 3, "resting during the wait refuses the mount")
assert_offset(resting_actor, 0, "resting refusal has no elevation")
assert(#support_rows("mount") == 0, "resting refusal writes no mount")
assert(
    has_message(t.messages(resting_actor), "You must be standing to climb."),
    "the pack veto before sim.climb presents body_not_standing"
)
t.rest(resting_actor, false)
t.tick()
local retry_body = t.body_target(resting_actor, resting_actor)
local retry_support = target(resting_actor, 3, 3, "crate")
t.drag(resting_actor, 2, 3, retry_body, 3, 3, retry_support)
t.drag(resting_actor, 2, 3, retry_body, 3, 3, retry_support)
t.tick()
t.run_ticks(CLOSED_TICKS + 1)
assert_position(resting_actor, 3, 3, "standing retry succeeds after the typed refusal")
assert_offset(resting_actor, 14, "retry mounts normally")
assert(#support_rows("mount") == 1, "duplicate retry input produces one mount")
assert(has_message(t.messages(resting_actor), COMPLETED_MESSAGE), "the new request has its own completed receipt")
assert(#t.script_errors() == 0, "resting refusal and retry have no script errors")

t.world(MAP, 0)
local lying_actor = t.join("assistant")
t.run_ticks(3)
t.rest(lying_actor, true)
t.tick()
start_closed_drag(lying_actor, 2, 3, 3, 3)
t.run_ticks(CLOSED_TICKS + 1)
assert_position(lying_actor, 2, 3, "a lying actor never climbs")
assert_offset(lying_actor, 0, "the post-wait veto has no elevation")
assert(#support_rows("mount") == 0, "the post-wait veto writes no mount")
assert(
    has_message(t.messages(lying_actor), "You must be standing to climb."),
    "the pack veto after the wait presents body_not_standing"
)
assert(#t.script_errors() == 0, "post-wait veto has no script errors")

t.world(MAP, 0)
local moving_actor = t.join("assistant")
t.run_ticks(3)
start_closed_drag(moving_actor, 2, 3, 3, 3)
local actor_interruptions = #t.ledger_rows("DoAfterInterrupted")
t.move(moving_actor, "west")
t.run_seconds(0.25)
t.run_ticks(CLOSED_TICKS + 2)
assert_position(moving_actor, 1, 3, "actor movement interrupts before mount")
assert_offset(moving_actor, 0, "actor interruption has no elevation")
assert(#support_rows("mount") == 0, "actor interruption queues no climb")
assert(#t.ledger_rows("DoAfterInterrupted") > actor_interruptions, "actor movement interrupts the stationary pin")
t.move(moving_actor, "east")
t.run_seconds(0.25)
start_closed_drag(moving_actor, 2, 3, 3, 3)
t.run_ticks(CLOSED_TICKS + 1)
assert_position(moving_actor, 3, 3, "a fresh attempt succeeds after interruption")
assert(#support_rows("mount") == 1, "the retry has one mount")
assert(#t.script_errors() == 0, "actor interruption and retry have no script errors")

t.world(MAP, 0)
local support_actor = t.join("assistant")
local support_puller = t.join("medic")
t.run_ticks(3)
start_closed_drag(support_actor, 2, 3, 3, 3)
local support_interruptions = #t.ledger_rows("DoAfterInterrupted")
t.pull(support_puller, 3, 3, target(support_puller, 3, 3, "crate"))
t.tick()
t.move(support_puller, "north")
t.run_ticks(6)
t.stop_pull(support_puller)
t.tick()
t.run_ticks(CLOSED_TICKS + 2)
assert_position(support_actor, 2, 3, "support movement interrupts before mount")
assert_offset(support_actor, 0, "support interruption has no elevation")
assert(#support_rows("mount") == 0, "support interruption queues no climb")
assert(#t.ledger_rows("DoAfterInterrupted") > support_interruptions, "support movement interrupts the target pin")
start_closed_drag(support_actor, 2, 3, 3, 2)
t.run_ticks(CLOSED_TICKS + 1)
assert_position(support_actor, 3, 2, "a retry onto the moved support succeeds")
assert(#support_rows("mount") == 1, "the moved-support retry has one mount")
assert(#t.script_errors() == 0, "support interruption and retry have no script errors")

local CONNECTED_MAP = [==[ (
    name: "connected crate walking",
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
            (3, 3, "crate"),
            (4, 3, "crate"),
        ],
    )],
)]==]

t.world(CONNECTED_MAP, 0)
local connected_actor = t.join("assistant")
t.run_ticks(3)
start_closed_drag(connected_actor, 2, 3, 3, 3)
t.run_ticks(CLOSED_TICKS + 1)
assert_position(connected_actor, 3, 3, "connected walking starts mounted")
t.rest(connected_actor, true)
t.tick()
assert(assert(t.body(connected_actor)).posture == "lying", "resting on support is lying")
assert_offset(connected_actor, 14, "resting retains support elevation")
t.rest(connected_actor, false)
t.tick()
assert_offset(connected_actor, 14, "standing again retains support")
t.move(connected_actor, "east")
t.run_seconds(0.25)
assert_position(connected_actor, 4, 3, "supported walking enters the adjacent crate")
assert_offset(connected_actor, 14, "connected walking retains elevation")
assert(#support_rows("traverse") == 1, "connected walking writes one traverse")
assert(#support_rows("mount") == 1, "connected walking does not write a second mount")
t.move(connected_actor, "south")
t.run_seconds(0.25)
assert_position(connected_actor, 4, 4, "the connected rider steps onto the floor")
assert_offset(connected_actor, 0, "connected step-off clears elevation")
assert(#support_rows("step_off") == 1, "connected step-off writes one transition")
assert(#t.script_errors() == 0, "connected support walking has no script errors")

t.world(MAP, 0)
local relocated_rider = t.join("assistant")
local relocated_puller = t.join("medic")
t.run_ticks(3)
start_closed_drag(relocated_rider, 2, 3, 3, 3)
t.run_ticks(CLOSED_TICKS + 1)
assert_offset(relocated_rider, 14, "the support-relocation rider starts mounted")
t.pull(relocated_puller, 3, 3, target(relocated_puller, 3, 3, "crate"))
t.tick()
t.move(relocated_puller, "north")
t.run_ticks(6)
t.stop_pull(relocated_puller)
t.tick()
assert_position(relocated_rider, 3, 3, "a pulled support does not tow its rider")
assert_offset(relocated_rider, 0, "support relocation clears rider elevation")
assert(#support_rows("support_moved") == 1, "support relocation writes one support_moved row")
assert(t.structure_at(3, 3) == nil, "the support leaves the rider's tile")
assert(assert(t.structure_at(3, 2)).state == "closed", "the pulled support survives")
assert(#t.script_errors() == 0, "support relocation has no script errors")
local function primary(player: number, x: number, y: number, id: string): ()
    t.click(player, x, y, target(player, x, y, id))
    t.tick()
end

local SINGLE_MAP = [==[ (
    name: "single crate rider knock-off",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [(
        rows: [
            "########",
            "#......#",
            "#......#",
            "#......#",
            "#......#",
            "#......#",
            "########",
        ],
        structures: [
            (3, 4, "player_spawn", { "jobs": "assistant" }),
            (4, 3, "player_spawn", { "jobs": "medic" }),
            (4, 4, "crate"),
        ],
    )],
)]==]

t.world(SINGLE_MAP, 0)
local single_attacker = t.join("assistant")
local single_rider = t.join("medic")
t.run_ticks(3)
start_closed_drag(single_rider, 4, 3, 4, 4)
t.run_ticks(CLOSED_TICKS + 1)
primary(single_attacker, 4, 4, "crate")
t.run_seconds(3.0)
local single_notices = table.concat(t.messages(single_attacker), " | ")
local single_x, single_y = t.pos(single_rider)
assert(
    single_x > 4 and single_y == 4,
    "one rider launches east: "
        .. single_x
        .. ","
        .. single_y
        .. "; notices="
        .. single_notices
        .. "; refusals="
        .. #t.ledger_rows("script_effect_refused")
)
assert_offset(single_rider, 0, "one rider's displacement clears support")
assert_forced_exits(1, joined_player_id(1), "single rider")

local KNOCK_MAP = [==[ (
    name: "crate rider knock-off",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [(
        rows: [
            "#########",
            "#.......#",
            "#.......#",
            "#.......#",
            "#.......#",
            "#.......#",
            "#.......#",
            "#.......#",
            "#########",
        ],
        structures: [
            (3, 4, "player_spawn", { "jobs": "assistant" }),
            (4, 3, "player_spawn", { "jobs": "medic" }),
            (5, 4, "player_spawn", { "jobs": "engineer" }),
            (2, 4, "player_spawn", { "jobs": "security" }),
            (4, 4, "crate"),
        ],
        items: [(3, 4, "wrench")],
    )],
)]==]

local function start_knock_world(): (number, number, number, number)
    t.world(KNOCK_MAP, 0)
    local attacker = t.join("assistant")
    local first_rider = t.join("medic")
    local second_rider = t.join("engineer")
    local non_rider = t.join("security")
    t.run_ticks(3)
    assert_position(non_rider, 2, 4, "the unsupported body starts beside the crate")
    assert_offset(non_rider, 0, "the adjacent non-rider has no support elevation")
    start_closed_drag(first_rider, 4, 3, 4, 4)
    t.run_ticks(CLOSED_TICKS + 1)
    start_closed_drag(second_rider, 5, 4, 4, 4)
    t.run_ticks(CLOSED_TICKS + 1)
    assert_position(first_rider, 4, 4, "the first rider shares the support")
    assert_position(second_rider, 4, 4, "the second rider shares the support")
    assert_offset(first_rider, 14, "the first rider is elevated")
    assert_offset(second_rider, 14, "the second rider is elevated")
    assert_offset(non_rider, 0, "the non-rider remains unelevated")
    return attacker, first_rider, second_rider, non_rider
end

local ka, kr1, kr2, kn = start_knock_world()
primary(kr1, 4, 4, "crate")
assert(assert(t.structure_at(4, 4)).state == "open", "co-located primary still falls through to native opening")
assert_offset(kr1, 14, "the co-located actor stays supported")
assert_offset(kr2, 14, "a co-located candidate is not knocked off")
assert(assert(t.body(kr2)).posture == "standing", "a co-located candidate gets no posture")
assert_offset(kn, 0, "the adjacent non-rider remains unelevated")
assert(assert(t.body(kn)).posture == "standing", "the adjacent non-rider gets no posture")
assert(#support_rows("support_ineligible") == 0, "co-located input writes no forced-launch transition")
assert(#t.script_errors() == 0, "co-located refusal has no script errors")

local BLOCKED_MAP = [==[ (
    name: "blocked crate knock-off",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [(
        rows: [
            "########",
            "#......#",
            "#......#",
            "#......#",
            "#....#.#",
            "#......#",
            "########",
        ],
        structures: [
            (3, 4, "player_spawn", { "jobs": "assistant" }),
            (4, 3, "player_spawn", { "jobs": "medic" }),
            (4, 4, "crate"),
        ],
    )],
)]==]

t.world(BLOCKED_MAP, 0)
local blocked_attacker = t.join("assistant")
local blocked_rider = t.join("medic")
t.run_ticks(3)
start_closed_drag(blocked_rider, 4, 3, 4, 4)
t.run_ticks(CLOSED_TICKS + 1)
assert_offset(blocked_rider, 14, "the blocked-flight rider starts mounted")
primary(blocked_attacker, 4, 4, "crate")
t.run_seconds(3.0)
assert_position(blocked_rider, 4, 4, "a wall prevents rider displacement")
assert_offset(blocked_rider, 14, "blocked flight is not knock-off")
assert(assert(t.body(blocked_rider)).posture == "lying", "blocked flight still applies the declared posture")
assert(#support_rows("support_ineligible") == 0, "blocked flight writes no forced-launch exit")
assert(assert(t.structure_at(4, 4)).state == "open", "blocked knock-off still falls through to native opening")
assert(#t.script_errors() == 0, "blocked knock-off has no script errors")

ka, kr1, kr2, kn = start_knock_world()
primary(ka, 3, 4, "wrench")
t.run_ticks(2)
assert(t.hands(ka).held == "wrench", "the attacker holds an unrelated tool")
primary(ka, 4, 4, "crate")
assert(assert(t.structure_at(4, 4)).state == "closed", "a held unrelated tool leaves the crate closed")
assert_offset(kr1, 14, "a held tool does not knock off the first rider")
assert_offset(kr2, 14, "a held tool does not knock off the second rider")
assert(assert(t.body(kr1)).posture == "standing", "a held tool applies no rider posture")
assert(assert(t.body(kn)).posture == "standing", "a held tool leaves the non-rider alone")
assert(#support_rows("support_ineligible") == 0, "a held tool writes no forced-launch transition")
t.drop(ka)
t.tick()
primary(ka, 4, 4, "crate")
t.run_seconds(3.0)
assert(assert(t.structure_at(4, 4)).state == "open", "native opening follows the empty-hand knock-off")
local attacker_x = t.pos(ka)
assert(4 - attacker_x > 0, "the east launch points away from the attacker")
assert_position(kr2, 5, 4, "the second rider launches east")
assert_offset(kr2, 0, "the launched rider's displacement clears support elevation")
assert(
    assert(t.body(kr2)).posture == "lying",
    "the launched rider receives the four-second knockdown"
)
assert_position(kr1, 4, 4, "the first rider's launch is blocked")
assert_offset(kr1, 14, "the blocked rider remains supported")
assert(
    assert(t.body(kr1)).posture == "lying",
    "the blocked rider receives the four-second knockdown"
)
assert_position(kn, 2, 4, "the adjacent non-rider is not launched")
assert_offset(kn, 0, "the adjacent non-rider stays unelevated")
assert(assert(t.body(kn)).posture == "standing", "the non-rider gets no knockdown")
assert_forced_exits(1, joined_player_id(1), "one launched rider and one blocked rider")
assert(#t.script_errors() == 0, "actual knock-off has no script errors")

ka, kr1, kr2, kn = start_knock_world()
primary(kr1, 4, 4, "crate")
assert(assert(t.structure_at(4, 4)).state == "open", "the open-start case begins with an open crate")
primary(ka, 4, 4, "crate")
assert(
    assert(t.structure_at(4, 4)).state == "closed",
    "native closing follows empty-hand knock-off on an open crate"
)
t.run_seconds(3.0)
assert_position(kr2, 5, 4, "open-start knock-off launches the second rider instead of capturing them")
assert_offset(kr2, 0, "the open-start launched rider loses support elevation")
assert(assert(t.body(kr2)).posture == "lying", "the open-start launched rider is knocked down")
assert_position(kr1, 4, 4, "open-start knock-off leaves the blocked rider outside at the crate")
assert_offset(kr1, 14, "the open-start blocked rider remains supported, not contained")
assert(assert(t.body(kr1)).posture == "lying", "the open-start blocked rider is knocked down")
assert_position(kn, 2, 4, "open-start knock-off leaves the non-rider alone")
assert_forced_exits(1, joined_player_id(1), "open-start launched and blocked riders")
assert(#t.script_errors() == 0, "open-start knock-off has no script errors")
print("crate climbing: timing, support, riders, knock-off and blocked displacement")
