local clock = require("@helpers/clock")

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
-- `stuffed` lists the occupants another player stuffed in: only they are
-- knocked down (`closets.dm:1014`); a body that walks in, hides or is gathered
-- by the close is not.
local function assert_closed(x: number, y: number, occupants: { number }, stuffed: { number }): ()
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
    end
    for _, occupant in ipairs(stuffed) do
        assert(assert(t.body(occupant)).posture == "lying", "a body stuffed in by another is knocked down")
    end
end

local function assert_open_dump(x: number, y: number, occupants: { number }): ()
    assert(assert(t.structure_at(x, y)).state == "open", "the container opens")
    for _, occupant in ipairs(occupants) do
        assert(tile_has_body(x, y, occupant), "opening restores the occupant to the holder tile")
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
click(actor, 4, 4, "locker")
assert_closed(4, 4, { first, second }, {})
assert(assert(t.body(first)).posture == "standing", "a body gathered by the close is not knocked down")
assert(assert(t.body(second)).posture == "standing", "a second gathered body is not knocked down")

local second_for_first = t.body_target(first, second)
assert(t.examine(first, 4, 4, second_for_first) ~= nil, "a co-occupant can examine a direct co-occupant")
local outsider_disclosure = pcall(function()
    return t.body_target(actor, second)
end)
assert(not outsider_disclosure, "an outsider gets no hidden body disclosure")
-- `occupant_sight`: tg shows an occupant the closet's surroundings
-- (`closet_see_inside.dm:8-10,22-60`).
local occupant_sees_out = pcall(function()
    return t.body_target(first, actor)
end)
assert(occupant_sees_out, "an occupant sees out of the closed container")

click(actor, 4, 4, "locker")
assert_open_dump(4, 4, { first, second })
t.run_seconds(4.1)
move_and_settle(second, "east")

drag_body(first, first, 4, 4, 4, 4, "locker")
t.run_ticks(ENTRY_TICKS - 1)
assert(assert(t.structure_at(4, 4)).state == "open", "self-hide does not finish one tick early")
t.run_ticks(1)
assert_closed(4, 4, { first }, {})
assert(assert(t.body(first)).posture == "standing", "a body that hides itself is not knocked down")

click(actor, 4, 4, "locker")
assert_open_dump(4, 4, { first })
drag_body(actor, first, 4, 4, 4, 4, "locker")
t.run_ticks(ENTRY_TICKS - 1)
assert(assert(t.structure_at(4, 4)).state == "open", "other-stuffing does not finish one tick early")
t.run_ticks(1)
assert_closed(4, 4, { first }, { first })

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
assert_closed(4, 4, { first, second }, { second })

click(actor, 4, 4, "locker")
assert_open_dump(4, 4, { first, second })
t.run_seconds(4.1)
move_and_settle(third, "west")
move_and_settle(third, "west")
drag_body(actor, third, 4, 4, 4, 4, "locker")
t.run_ticks(ENTRY_TICKS + 1)
assert_closed(4, 4, { first, second, third }, { third })

click(actor, 4, 4, "locker")
assert_open_dump(4, 4, { first, second, third })
move_and_settle(fourth, "east")
move_and_settle(fourth, "south")
assert(tile_has_body(4, 4, fourth), "the fourth candidate is co-tile and otherwise eligible")
drag_body(fourth, fourth, 4, 4, 4, 4, "locker")
t.run_ticks(ENTRY_TICKS + 1)
assert(assert(t.structure_at(4, 4)).state == "open", "a timed fourth body is refused without a partial close")
assert(tile_has_body(4, 4, first) and tile_has_body(4, 4, second) and tile_has_body(4, 4, third), "the original three remain outside atomically")
assert(tile_has_body(4, 4, fourth), "the fourth body remains outside with the original three")
assert(assert(t.body(fourth)).posture == "standing", "the refused fourth gets no posture")

move_and_settle(fourth, "north")
click(actor, 4, 4, "locker")
assert_closed(4, 4, { first, second, third }, {})
assert(tile_has_body(4, 3, fourth), "primary close leaves the unselected fourth outside")
assert(assert(t.body(fourth)).posture == "standing", "the unselected fourth gets no posture")

click(actor, 4, 4, "locker")
assert_open_dump(4, 4, { first, second, third })
assert(#t.script_errors() == 0, "the real-player occupancy flow has no script errors")
local ITEM_MAP = [==[ (
    name: "body and item capacity",
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
click(item_actor, 4, 4, "locker")
assert(assert(t.structure_at(4, 4)).state == "closed", "the full tile still closes")
-- Tg's `storage_capacity` counts mobs too, and the gather stops when full
-- (`closets.dm:56,525-529,563`): the stored things total exactly thirty.
local stored = 31 - #t.items_at(4, 4)
for _, player in ipairs({ item_first, item_second, item_third }) do
    if not tile_has_body(4, 4, player) then
        stored += 1
    end
end
assert(stored == 30, "bodies count toward the thirty things a close takes in")
assert(#t.ledger_rows("container_insert_refused") == 0, "the closing handler asks for no more than fits")
click(item_actor, 4, 4, "locker")
assert_open_dump(4, 4, { item_first, item_second, item_third })
assert(#t.items_at(4, 4) == 31, "opening returns every stored item and the overflow")

t.run_seconds(4.1)
move_and_settle(item_first, "south")
move_and_settle(item_second, "east")
move_and_settle(item_third, "east")
move_and_settle(item_third, "east")
click(item_actor, 4, 4, "locker")
assert(assert(t.structure_at(4, 4)).state == "closed", "an item-only close succeeds")
assert(#t.items_at(4, 4) == 1, "item-only close still stores exactly thirty items")
for _, player in ipairs({ item_first, item_second, item_third }) do
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
click(item_actor, 7, 6, "locker")
assert(assert(t.structure_at(7, 6)).state == "closed", "an empty close succeeds")
assert(assert(t.body(item_actor)).posture == "standing", "empty close applies no posture")
assert(#t.script_errors() == 0, "shared capacity and empty closes have no script errors")

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
    assert(assert(t.body(player)).posture == "standing", label .. ": no close posture")
end

local ga, gs, gh = start_guard_world()
move_and_settle(gs, "north")
drag_body(ga, gs, 4, 4, 4, 4, "locker")
local actor_interruptions = #t.ledger_rows("DoAfterInterrupted")
move_and_settle(ga, "west")
wait_for_entry()
assert(assert(t.structure_at(4, 4)).state == "open", "actor movement leaves the holder open")
assert_unadmitted(gs, 4, 4, "actor movement")
assert(#t.ledger_rows("DoAfterInterrupted") > actor_interruptions, "actor movement interrupts the pins")

ga, gs, gh = start_guard_world()
move_and_settle(gs, "north")
drag_body(ga, gs, 4, 4, 4, 4, "locker")
local subject_interruptions = #t.ledger_rows("DoAfterInterrupted")
move_and_settle(gs, "south")
wait_for_entry()
assert(assert(t.structure_at(4, 4)).state == "open", "subject movement leaves the holder open")
assert_unadmitted(gs, 4, 5, "subject movement")
assert(#t.ledger_rows("DoAfterInterrupted") > subject_interruptions, "subject movement interrupts the pins")

ga, gs, gh = start_guard_world()
move_and_settle(gs, "north")
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
drag_body(ga, gs, 4, 5, 4, 4, "locker")
click(gh, 4, 4, "locker")
assert(assert(t.structure_at(4, 4)).state == "closed", "another player closes an empty holder during entry")
assert_unadmitted(gs, 4, 5, "empty close")
wait_for_entry()
assert(assert(t.structure_at(4, 4)).state == "closed", "the closed-state recheck queues no entry")
assert(#t.ledger_rows("container_closed") == 1, "the later drag adds no second close")

ga, gs, gh = start_guard_world()
move_and_settle(gs, "north")
local duplicate_body = t.body_target(ga, gs)
local duplicate_holder = target(ga, 4, 4, "locker")
t.drag(ga, 4, 4, duplicate_body, 4, 4, duplicate_holder)
t.drag(ga, 4, 4, duplicate_body, 4, 4, duplicate_holder)
t.tick()
wait_for_entry()
assert_closed(4, 4, { gs }, { gs })
assert(#t.ledger_rows("container_closed") == 1, "duplicate input produces one close")
assert(#t.script_errors() == 0, "duplicate input has no script errors")

t.world(DESTRUCTION_MAP, 0)
ga = t.join("assistant")
gs = t.join("medic")
gh = t.join("engineer")
t.run_ticks(3)
click(ga, 4, 4, "crate")
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
assert(assert(t.structure_at(4, 4)).state == "open", "the crate opens under its rider")
t.run_seconds(3.0)
assert(tile_has_body(4, 4, gs), "the occupied landing keeps the rider blocked outside")
assert(t.seen(gs, gs).offset.y == 14, "blocked flight is not knock-off or containment")
drag_body(ga, gs, 4, 4, 4, 4, "crate")
wait_for_entry()
assert_closed(4, 4, { gs }, { gs })
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

-- The closing handler takes only items and bodies (`Handle.kind`): a stand on
-- the tile is never asked for, so the close commits with no refusal row.
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
assert(#t.ledger_rows("container_closed") == closed_rows + 1, "the close commits beside the stand")
assert(#t.items_at(3, 2) == 0, "the admitted item is stored")
assert(t.target_at(loader, 3, 2, "iv_drip") ~= nil, "the stand stays on the tile")
assert(#t.ledger_rows("container_insert_refused") == 0, "the stand is never asked for")
assert(#t.script_errors() == 0, "closing beside a stand raises no script error")
print("container occupancy: capacity, drag, disclosure, recovery, resist and entry guards")
