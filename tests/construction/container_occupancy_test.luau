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

local resist_baseline = #t.ledger_rows("container_resist_refused")
t.move(first, "north")
t.run_seconds(0.25)
assert(assert(t.structure_at(4, 4)).state == "closed", "Stage-A directional resist cannot open the holder")
assert(not tile_has_body(4, 4, first), "resist does not turn into a tile step")
assert(#t.ledger_rows("container_resist_refused") == resist_baseline + 1, "resist refusal is ledgered")
t.click(first, 4, 4, target(first, 4, 4, "locker"))
t.tick()
assert(assert(t.structure_at(4, 4)).state == "closed", "an occupant cannot use the holder open")

click(actor, 4, 4, "locker")
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
print("container occupancy: close, drag, capacity, disclosure, dump and Stage-A resist")
