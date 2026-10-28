local clock = require("@helpers/clock")

local CLOSE_MESSAGE = "The closing container knocks you down."
local ENTRY_TICKS: number

local function move_and_settle(player: number, direction: "north" | "south" | "east" | "west"): ()
    t.move(player, direction)
    t.run_seconds(0.25)
end

local function tile_has_body(x: number, y: number, player: number): boolean
    local wanted = t.body_id(player)
    for _, body in ipairs(t.bodies_at(x, y)) do
        if body.id == wanted then
            return true
        end
    end
    return false
end

local function message_count(player: number, wanted: string): number
    local count = 0
    for _, message in ipairs(t.messages(player)) do
        if message == wanted then
            count += 1
        end
    end
    return count
end

local function target(player: number, x: number, y: number, id: string): SpecObservedTarget
    local observed = assert(t.target_at(player, x, y, id), "the observed target exists")
    return observed
end

local function click(player: number, x: number, y: number, id: string): ()
    t.click(player, x, y, target(player, x, y, id))
    t.tick()
end

local function drag_body(
    actor: number,
    subject: number,
    from_x: number,
    from_y: number,
    onto_x: number,
    onto_y: number,
    id: string
): ()
    t.drag(
        actor,
        from_x,
        from_y,
        t.body_target(actor, subject),
        onto_x,
        onto_y,
        target(actor, onto_x, onto_y, id)
    )
    t.tick()
end

local close_assertions = 0
local function assert_closed_with_message(x: number, y: number, occupants: { number }): ()
    close_assertions += 1
    local structure = assert(t.structure_at(x, y))
    assert(
        structure.state == "closed",
        "the container closes for occupancy check "
            .. close_assertions
            .. "; actual="
            .. tostring(structure.state)
            .. "; script_errors="
            .. #t.script_errors()
            .. "; waits="
            .. #t.ledger_rows("DoAfterStarted")
            .. "; interrupted="
            .. #t.ledger_rows("DoAfterInterrupted")
            .. "; closes="
            .. #t.ledger_rows("container_closed")
    )
    for _, occupant in ipairs(occupants) do
        assert(not tile_has_body(x, y, occupant), "an admitted body leaves the physical tile")
        assert(message_count(occupant, CLOSE_MESSAGE) == 1, "each admitted body gets one close message")
        assert(assert(t.body(occupant)).posture == "lying", "each admitted body is knocked down once")
    end
end

local function assert_open_dump(x: number, y: number, occupants: { number }): ()
    assert(assert(t.structure_at(x, y)).state == "open", "the container opens")
    for _, occupant in ipairs(occupants) do
        assert(tile_has_body(x, y, occupant), "opening restores the occupant to the holder tile")
        assert(message_count(occupant, CLOSE_MESSAGE) == 0, "opening has no second close notification")
    end
end

t.world(
    [==[ (
        name: "real player container occupancy",
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
                (4, 5, "player_spawn", { "jobs": "medic" }),
                (5, 4, "player_spawn", { "jobs": "engineer" }),
                (6, 4, "player_spawn", { "jobs": "security" }),
                (3, 3, "player_spawn", { "jobs": "captain" }),
                (4, 4, "locker"),
            ],
        )],
    ) ]==],
    0
)
ENTRY_TICKS = clock.deadline_ticks(4.0)

local actor = t.join("assistant")
local first = t.join("medic")
local second = t.join("engineer")
local third = t.join("security")
local fourth = t.join("captain")
t.run_ticks(3)

click(actor, 4, 4, "locker")
assert(assert(t.structure_at(4, 4)).state == "open", "the locker opens for co-tile loading")
move_and_settle(first, "north")
move_and_settle(second, "west")
assert(tile_has_body(4, 4, first) and tile_has_body(4, 4, second), "two bodies walk onto the open locker")
message_count(first, CLOSE_MESSAGE)
message_count(second, CLOSE_MESSAGE)
click(actor, 4, 4, "locker")
assert_closed_with_message(4, 4, { first, second })

local second_for_first = t.body_target(first, second)
assert(t.examine(first, 4, 4, second_for_first) ~= nil, "a co-occupant can examine a direct co-occupant")
local outsider_disclosure = pcall(function()
    return t.body_target(actor, second)
end)
assert(not outsider_disclosure, "an outsider gets no hidden body disclosure")

click(actor, 4, 4, "locker")
assert_open_dump(4, 4, { first, second })
t.run_seconds(4.1)
move_and_settle(second, "east")

message_count(first, CLOSE_MESSAGE)
drag_body(first, first, 4, 4, 4, 4, "locker")
t.run_ticks(ENTRY_TICKS - 1)
assert(assert(t.structure_at(4, 4)).state == "open", "self-hide does not finish one tick early")
assert(message_count(first, CLOSE_MESSAGE) == 0, "enter has no early posture message")
t.run_ticks(1)
assert_closed_with_message(4, 4, { first })

click(actor, 4, 4, "locker")
assert_open_dump(4, 4, { first })
message_count(first, CLOSE_MESSAGE)
drag_body(actor, first, 4, 4, 4, 4, "locker")
t.run_ticks(ENTRY_TICKS - 1)
assert(assert(t.structure_at(4, 4)).state == "open", "other-stuffing does not finish one tick early")
assert(message_count(first, CLOSE_MESSAGE) == 0, "other entry has no early posture message")
t.run_ticks(1)
assert_closed_with_message(4, 4, { first })

t.click(first, 4, 4, target(first, 4, 4, "locker"))
t.tick()
assert(assert(t.structure_at(4, 4)).state == "closed", "a click is not a resist: the holder stays shut")

local resist_baseline = #t.ledger_rows("container_resist_refused")
local opened_baseline = #t.ledger_rows("container_opened")
t.move(first, "north")
t.run_seconds(0.25)
assert(assert(t.structure_at(4, 4)).state == "open", "an unsecured resist opens the holder at once")
assert(#t.ledger_rows("container_opened") == opened_baseline + 1, "the resist open is ledgered")
assert(#t.ledger_rows("container_resist_refused") == resist_baseline, "an unsecured resist is not refused")
local resist_opening = t.ledger_rows("container_opened")
local resist_opener = resist_opening[#resist_opening].actor
assert(
    resist_opener.kind == "script" and (resist_opener :: { [string]: unknown }).triggered_by == t.body_id(first),
    "the closet lib's handler opens as the pushing occupant"
)
assert_open_dump(4, 4, { first })
message_count(first, CLOSE_MESSAGE)
message_count(second, CLOSE_MESSAGE)
move_and_settle(actor, "south")
move_and_settle(actor, "east")
move_and_settle(actor, "north")
move_and_settle(actor, "north")
move_and_settle(actor, "east")
local actor_x, actor_y = t.pos(actor)
assert(actor_x == 5 and actor_y == 3, "the external actor is beside the locker and next subject")
move_and_settle(second, "west")
assert(tile_has_body(4, 4, first) and tile_has_body(4, 4, second), "the next timed subject steps onto the open holder")
drag_body(actor, second, 4, 4, 4, 4, "locker")
t.run_ticks(ENTRY_TICKS + 1)
assert_closed_with_message(4, 4, { first, second })

click(actor, 4, 4, "locker")
assert_open_dump(4, 4, { first, second })
t.run_seconds(4.1)
move_and_settle(third, "west")
move_and_settle(third, "west")
message_count(first, CLOSE_MESSAGE)
message_count(second, CLOSE_MESSAGE)
message_count(third, CLOSE_MESSAGE)
drag_body(actor, third, 4, 4, 4, 4, "locker")
t.run_ticks(ENTRY_TICKS + 1)
assert_closed_with_message(4, 4, { first, second, third })

click(actor, 4, 4, "locker")
assert_open_dump(4, 4, { first, second, third })
move_and_settle(fourth, "east")
move_and_settle(fourth, "south")
assert(tile_has_body(4, 4, fourth), "the fourth candidate is co-tile and otherwise eligible")
message_count(first, CLOSE_MESSAGE)
message_count(second, CLOSE_MESSAGE)
message_count(third, CLOSE_MESSAGE)
message_count(fourth, CLOSE_MESSAGE)
drag_body(fourth, fourth, 4, 4, 4, 4, "locker")
t.run_ticks(ENTRY_TICKS + 1)
assert(assert(t.structure_at(4, 4)).state == "open", "a timed fourth body is refused without a partial close")
assert(tile_has_body(4, 4, first) and tile_has_body(4, 4, second) and tile_has_body(4, 4, third), "the original three remain outside atomically")
assert(tile_has_body(4, 4, fourth), "the fourth body remains outside with the original three")
assert(message_count(fourth, CLOSE_MESSAGE) == 0, "the refused fourth gets no close message")
assert(assert(t.body(fourth)).posture == "standing", "the refused fourth gets no posture")

move_and_settle(fourth, "north")
message_count(first, CLOSE_MESSAGE)
message_count(second, CLOSE_MESSAGE)
message_count(third, CLOSE_MESSAGE)
click(actor, 4, 4, "locker")
assert_closed_with_message(4, 4, { first, second, third })
assert(tile_has_body(4, 3, fourth), "primary close leaves the unselected fourth outside")
assert(message_count(fourth, CLOSE_MESSAGE) == 0, "the unselected fourth gets no close message")
assert(assert(t.body(fourth)).posture == "standing", "the unselected fourth gets no posture")

click(actor, 4, 4, "locker")
assert_open_dump(4, 4, { first, second, third })
assert(#t.script_errors() == 0, "the real-player occupancy flow has no script errors")
local ITEM_MAP = [==[ (
    name: "independent body and item capacity",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [(
        rows: [
            "##########",
            "#........#",
            "#........#",
            "#........#",
            "#........#",
            "#........#",
            "#........#",
            "#........#",
            "##########",
        ],
        structures: [
            (3, 4, "player_spawn", { "jobs": "assistant" }),
            (4, 5, "player_spawn", { "jobs": "medic" }),
            (5, 4, "player_spawn", { "jobs": "engineer" }),
            (6, 4, "player_spawn", { "jobs": "security" }),
            (4, 4, "locker"),
            (7, 6, "locker"),
        ],
        items: [
            (4, 4, "wrench"), (4, 4, "wrench"), (4, 4, "wrench"), (4, 4, "wrench"),
            (4, 4, "wrench"), (4, 4, "wrench"), (4, 4, "wrench"), (4, 4, "wrench"),
            (4, 4, "wrench"), (4, 4, "wrench"), (4, 4, "wrench"), (4, 4, "wrench"),
            (4, 4, "wrench"), (4, 4, "wrench"), (4, 4, "wrench"), (4, 4, "wrench"),
            (4, 4, "wrench"), (4, 4, "wrench"), (4, 4, "wrench"), (4, 4, "wrench"),
            (4, 4, "wrench"), (4, 4, "wrench"), (4, 4, "wrench"), (4, 4, "wrench"),
            (4, 4, "wrench"), (4, 4, "wrench"), (4, 4, "wrench"), (4, 4, "wrench"),
            (4, 4, "wrench"), (4, 4, "wrench"), (4, 4, "wrench"),
        ],
    )],
)]==]

t.world(ITEM_MAP, 0)
local item_actor = t.join("assistant")
local item_first = t.join("medic")
local item_second = t.join("engineer")
local item_third = t.join("security")
t.run_ticks(3)
click(item_actor, 4, 4, "locker")
move_and_settle(item_first, "north")
move_and_settle(item_second, "west")
move_and_settle(item_third, "west")
move_and_settle(item_third, "west")
message_count(item_first, CLOSE_MESSAGE)
message_count(item_second, CLOSE_MESSAGE)
message_count(item_third, CLOSE_MESSAGE)
click(item_actor, 4, 4, "locker")
assert_closed_with_message(4, 4, { item_first, item_second, item_third })
assert(#t.items_at(4, 4) == 1, "thirty items fit independently of all three bodies")
assert(#t.ledger_rows("container_insert_refused") == 0, "the closing handler asks for no more than fits")
click(item_actor, 4, 4, "locker")
assert_open_dump(4, 4, { item_first, item_second, item_third })
assert(#t.items_at(4, 4) == 31, "opening returns thirty stored items and the one overflow")

t.run_seconds(4.1)
move_and_settle(item_first, "south")
move_and_settle(item_second, "east")
move_and_settle(item_third, "east")
move_and_settle(item_third, "east")
message_count(item_first, CLOSE_MESSAGE)
message_count(item_second, CLOSE_MESSAGE)
message_count(item_third, CLOSE_MESSAGE)
click(item_actor, 4, 4, "locker")
assert(assert(t.structure_at(4, 4)).state == "closed", "an item-only close succeeds")
assert(#t.items_at(4, 4) == 1, "item-only close still stores exactly thirty items")
for _, player in ipairs({ item_first, item_second, item_third }) do
    assert(message_count(player, CLOSE_MESSAGE) == 0, "item-only close has no body notification")
    assert(assert(t.body(player)).posture == "standing", "item-only close applies no posture")
end
click(item_actor, 4, 4, "locker")
assert(#t.items_at(4, 4) == 31, "item-only reopening preserves every item")

move_and_settle(item_actor, "south")
move_and_settle(item_actor, "south")
move_and_settle(item_actor, "east")
move_and_settle(item_actor, "east")
move_and_settle(item_actor, "east")
click(item_actor, 7, 6, "locker")
assert(#t.items_at(7, 6) == 0, "the empty locker exposes no items")
message_count(item_actor, CLOSE_MESSAGE)
click(item_actor, 7, 6, "locker")
assert(assert(t.structure_at(7, 6)).state == "closed", "an empty close succeeds")
assert(message_count(item_actor, CLOSE_MESSAGE) == 0, "empty close emits no posture message")
assert(assert(t.body(item_actor)).posture == "standing", "empty close applies no posture")
assert(#t.script_errors() == 0, "independent capacity and empty closes have no script errors")

local GUARD_MAP = [==[ (
    name: "container entry guards",
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
            "#......#",
            "########",
        ],
        structures: [
            (3, 4, "player_spawn", { "jobs": "assistant" }),
            (4, 5, "player_spawn", { "jobs": "medic" }),
            (5, 4, "player_spawn", { "jobs": "engineer" }),
            (4, 4, "locker"),
        ],
        items: [(5, 4, "lunatic/tfs:closet_cut_test_remover")],
    )],
)]==]

local DESTRUCTION_MAP = [==[ (
    name: "container entry destruction",
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
            "#......#",
            "########",
        ],
        structures: [
            (3, 4, "player_spawn", { "jobs": "assistant" }),
            (4, 5, "player_spawn", { "jobs": "medic" }),
            (5, 4, "player_spawn", { "jobs": "engineer" }),
            (4, 4, "crate"),
        ],
        items: [(5, 4, "lunatic/tfs:closet_cut_test_remover")],
    )],
)]==]

local function start_guard_world(): (number, number, number)
    t.world(GUARD_MAP, 0)
    local guard_actor = t.join("assistant")
    local guard_subject = t.join("medic")
    local guard_helper = t.join("engineer")
    t.run_ticks(3)
    click(guard_actor, 4, 4, "locker")
    return guard_actor, guard_subject, guard_helper
end

local function wait_for_entry(): ()
    t.run_ticks(ENTRY_TICKS + 2)
end

local function assert_unadmitted(player: number, x: number, y: number, label: string): ()
    assert(tile_has_body(x, y, player), label .. ": the subject remains outside")
    assert(message_count(player, CLOSE_MESSAGE) == 0, label .. ": no close message")
    assert(assert(t.body(player)).posture == "standing", label .. ": no close posture")
end

local ga, gs, gh = start_guard_world()
move_and_settle(gs, "north")
message_count(gs, CLOSE_MESSAGE)
drag_body(ga, gs, 4, 4, 4, 4, "locker")
local actor_interruptions = #t.ledger_rows("DoAfterInterrupted")
move_and_settle(ga, "west")
wait_for_entry()
assert(assert(t.structure_at(4, 4)).state == "open", "actor movement leaves the holder open")
assert_unadmitted(gs, 4, 4, "actor movement")
assert(#t.ledger_rows("DoAfterInterrupted") > actor_interruptions, "actor movement interrupts the pins")

ga, gs, gh = start_guard_world()
move_and_settle(gs, "north")
message_count(gs, CLOSE_MESSAGE)
drag_body(ga, gs, 4, 4, 4, 4, "locker")
local subject_interruptions = #t.ledger_rows("DoAfterInterrupted")
move_and_settle(gs, "south")
wait_for_entry()
assert(assert(t.structure_at(4, 4)).state == "open", "subject movement leaves the holder open")
assert_unadmitted(gs, 4, 5, "subject movement")
assert(#t.ledger_rows("DoAfterInterrupted") > subject_interruptions, "subject movement interrupts the pins")

ga, gs, gh = start_guard_world()
move_and_settle(gs, "north")
message_count(gs, CLOSE_MESSAGE)
drag_body(ga, gs, 4, 4, 4, 4, "locker")
local holder_interruptions = #t.ledger_rows("DoAfterInterrupted")
t.pull(gh, 4, 4, target(gh, 4, 4, "locker"))
t.tick()
t.move(gh, "east")
t.run_ticks(6)
t.stop_pull(gh)
t.tick()
wait_for_entry()
assert(t.structure_at(4, 4) == nil, "the pulled holder leaves its original tile")
assert(assert(t.structure_at(5, 4)).state == "open", "the moved holder remains open")
assert_unadmitted(gs, 4, 4, "holder movement")
assert(#t.ledger_rows("DoAfterInterrupted") > holder_interruptions, "holder movement interrupts the target pin")

ga, gs, gh = start_guard_world()
message_count(gs, CLOSE_MESSAGE)
drag_body(ga, gs, 4, 5, 4, 4, "locker")
click(gh, 4, 4, "locker")
assert(assert(t.structure_at(4, 4)).state == "closed", "another player closes an empty holder during entry")
assert_unadmitted(gs, 4, 5, "empty close")
wait_for_entry()
assert(assert(t.structure_at(4, 4)).state == "closed", "the closed-state recheck queues no entry")
assert(#t.ledger_rows("container_closed") == 1, "the later drag adds no second close")

ga, gs, gh = start_guard_world()
move_and_settle(gs, "north")
message_count(gs, CLOSE_MESSAGE)
local duplicate_body = t.body_target(ga, gs)
local duplicate_holder = target(ga, 4, 4, "locker")
t.drag(ga, 4, 4, duplicate_body, 4, 4, duplicate_holder)
t.drag(ga, 4, 4, duplicate_body, 4, 4, duplicate_holder)
t.tick()
wait_for_entry()
assert_closed_with_message(4, 4, { gs })
assert(#t.ledger_rows("container_closed") == 1, "duplicate input produces one close")
assert(#t.script_errors() == 0, "duplicate input has no script errors")

t.world(DESTRUCTION_MAP, 0)
ga = t.join("assistant")
gs = t.join("medic")
gh = t.join("engineer")
t.run_ticks(3)
click(ga, 4, 4, "crate")
message_count(gs, CLOSE_MESSAGE)
drag_body(ga, gs, 4, 5, 4, 4, "crate")
click(gh, 5, 4, "lunatic/tfs:closet_cut_test_remover")
t.run_ticks(2)
assert(t.hands(gh).held == "lunatic/tfs:closet_cut_test_remover", "the removal tool is held")
click(gh, 4, 4, "crate")
t.run_seconds(6.0)
assert(t.structure_at(4, 4) == nil, "player deconstruction destroys the holder during entry")
assert_unadmitted(gs, 4, 5, "holder destruction")

ga, gs, gh = start_guard_world()
move_and_settle(gs, "north")
message_count(gs, CLOSE_MESSAGE)
drag_body(ga, gs, 4, 4, 4, 4, "locker")
local incapacity_interruptions = #t.ledger_rows("DoAfterInterrupted")
t.set_health(ga, { brute = 100 })
t.tick()
wait_for_entry()
assert(assert(t.structure_at(4, 4)).state == "open", "incapacity leaves the holder open")
assert_unadmitted(gs, 4, 4, "actor incapacity")
assert(#t.ledger_rows("DoAfterInterrupted") > incapacity_interruptions, "incapacity interrupts entry")
assert(#t.script_errors() == 0, "entry guard matrix has no script errors")
t.world(DESTRUCTION_MAP, 0)
ga = t.join("assistant")
gs = t.join("medic")
gh = t.join("engineer")
t.run_ticks(3)
t.drag(gs, 4, 5, t.body_target(gs, gs), 4, 4, target(gs, 4, 4, "crate"))
t.tick()
t.run_ticks(clock.deadline_ticks(2.0) + 1)
assert(t.seen(gs, gs).offset.y == 14, "the occupant climbs onto the closed crate")
click(ga, 4, 4, "crate")
click(ga, 4, 4, "crate")
assert(assert(t.structure_at(4, 4)).state == "closed", "native close does not recapture the launch")
t.run_seconds(3.0)
assert(tile_has_body(4, 4, gs), "the occupied landing keeps the rider blocked outside")
assert(t.seen(gs, gs).offset.y == 14, "blocked flight is not knock-off or containment")
click(ga, 4, 4, "crate")
drag_body(ga, gs, 4, 4, 4, 4, "crate")
wait_for_entry()
assert_closed_with_message(4, 4, { gs })
local dump_baseline = #t.ledger_rows("container_dumped")
click(gh, 5, 4, "lunatic/tfs:closet_cut_test_remover")
t.run_ticks(2)
assert(t.hands(gh).held == "lunatic/tfs:closet_cut_test_remover", "the occupied removal tool is held")
click(gh, 4, 4, "crate")
t.run_seconds(2.0)
assert(t.structure_at(4, 4) == nil, "public deconstruction destroys the occupied holder")
assert(tile_has_body(4, 4, gs), "holder destruction dumps its occupant onto the live tile")
local dump_rows = t.ledger_rows("container_dumped")
assert(#dump_rows == dump_baseline + 1, "occupied destruction writes one container dump")
assert(dump_rows[#dump_rows].bodies == 1, "the destruction dump names exactly one body")
assert(#t.script_errors() == 0, "occupied destruction recovery has no script errors")

-- The closing handler asks for everything on the tile; a refused insert stays
-- out with one row and the close still commits with the rest.
t.world(
    [==[ (
        name: "refused close insert",
        legend: {
            '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
            '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        },
        levels: [(
            rows: [
                "######",
                "#....#",
                "#....#",
                "#....#",
                "######",
            ],
            structures: [
                (2, 2, "player_spawn", { "jobs": "engineer" }),
                (3, 2, "locker"),
                (3, 2, "iv_drip"),
            ],
            items: [(3, 2, "wrench")],
        )],
    ) ]==],
    0
)
local loader = t.join("engineer")
t.run_ticks(3)
local opened_rows = #t.ledger_rows("container_opened")
local closed_rows = #t.ledger_rows("container_closed")
click(loader, 3, 2, "locker")
assert(#t.ledger_rows("container_opened") == opened_rows + 1, "the locker opens for loading")
click(loader, 3, 2, "locker")
assert(#t.ledger_rows("container_closed") == closed_rows + 1, "a refused insert does not stop the close")
assert(#t.items_at(3, 2) == 0, "the admitted item is stored")
assert(t.target_at(loader, 3, 2, "iv_drip") ~= nil, "the refused stand stays on the tile")
local refusals = t.ledger_rows("container_insert_refused")
assert(#refusals == 1, "the refused stand has one row")
assert(refusals[1].reason == "not_admissible", "the stand is no item or body")
assert(#t.script_errors() == 0, "a refused insert raises no script error")
print("container occupancy: capacity, drag, disclosure, recovery, resist and entry guards")
