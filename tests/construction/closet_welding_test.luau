-- Player-facing closet welding and native open/close fallthrough.
local function structure_state(x: number, y: number): string
    local structure = assert(t.structure_at(x, y), "the structure remains present")
    assert(structure.state ~= nil, "the closet exposes its native state")
    return structure.state
end

t.world(
    [==[ (
        name: "closet welding",
        legend: {
            ' ': (composition: (substrate: Named("space"))),
            '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
            '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        },
        levels: [(
            rows: ["#########", "#.......#", "#.......#", "#.......#", "#.......#", "#.......#", "#########"],
            structures: [
                (3, 2, "player_spawn", { "jobs": "engineer" }),
                (4, 2, "crate.secure", { "access": "command" }),
                (4, 3, "crate"),
                (6, 4, "crate"),
                (3, 5, "locker"),
            ],
            items: [(3, 2, "welder"), (3, 2, "id_captain"), (3, 2, "screwdriver")],
        )],
    ) ]==],
    7
)

local player = t.join("engineer")
t.run_ticks(2)
t.click(player, 3, 2, assert(t.target_at(player, 3, 2, "welder")))
t.run_ticks(2)
assert(t.hands(player).held == "welder", "picked up the unlit welder")
t.click(player, 4, 3, assert(t.target_at(player, 4, 3, "crate")))
t.run_seconds(4.0)
assert(structure_state(4, 3) == "closed", "an unlit welder does not change the crate")

-- Once the unlit tool is dropped, native empty-hand use opens and closes the
-- ordinary crate. The separate secure crate starts locked by default.
t.drop(player)
t.run_ticks(2)
t.click(player, 4, 3)
t.run_ticks(2)
assert(structure_state(4, 3) == "open", "empty-hand use reaches native opening")
t.click(player, 4, 3)
t.run_ticks(2)
t.click(player, 3, 2, assert(t.target_at(player, 3, 2, "id_captain")))
t.run_ticks(2)
t.click(player, 4, 2, assert(t.target_at(player, 4, 2, "crate.secure")))
t.run_ticks(2)
assert(structure_state(4, 2) == "closed", "the command ID unlocks without opening")
t.drop(player)
t.run_ticks(2)
t.click(player, 4, 2)
t.run_ticks(2)
assert(structure_state(4, 2) == "open", "native opening follows the unlock")
t.click(player, 4, 2)
t.run_ticks(2)
t.click(player, 3, 2, assert(t.target_at(player, 3, 2, "id_captain")))
t.run_ticks(2)
t.click(player, 4, 2, assert(t.target_at(player, 4, 2, "crate.secure")))
t.run_ticks(2)
assert(structure_state(4, 2) == "closed", "the command ID relocks it")

-- A lit welder can weld the still-locked crate. The ID unlocks it afterward,
-- but native opening remains blocked until the welded bit is cleared.
t.drop(player)
t.run_ticks(2)
t.click(player, 3, 2, assert(t.target_at(player, 3, 2, "welder")))
t.run_ticks(2)
t.use_self(player)
t.run_ticks(2)
t.click(player, 4, 2, assert(t.target_at(player, 4, 2, "crate.secure")))
t.run_ticks(2)
t.run_seconds(4.0)
t.drop(player)
t.run_ticks(2)
t.click(player, 3, 2, assert(t.target_at(player, 3, 2, "id_captain")))
t.run_ticks(2)
t.click(player, 4, 2, assert(t.target_at(player, 4, 2, "crate.secure")))
t.run_ticks(2)
t.drop(player)
t.run_ticks(2)
t.click(player, 4, 2)
t.run_ticks(2)
assert(structure_state(4, 2) == "closed", "the welded secure crate stays shut after unlock")

-- The task starts on its first wake, then waits four seconds before unwelding.
t.click(player, 3, 2, assert(t.target_at(player, 3, 2, "welder")))
t.run_ticks(2)
t.click(player, 4, 2, assert(t.target_at(player, 4, 2, "crate.secure")))
t.run_ticks(2)
t.run_seconds(4.0)
t.drop(player)
t.run_ticks(2)
t.click(player, 4, 2)
t.run_ticks(2)
assert(structure_state(4, 2) == "open", "the unwelded crate opens natively")

-- A held unrelated tool is declined, so empty-hand use opens the closed
-- crate; the same tool enters ground custody when used on the open crate.
t.click(player, 3, 2, assert(t.target_at(player, 3, 2, "screwdriver")))
t.run_ticks(2)
t.move(player, "west")
t.run_seconds(0.25)
t.move(player, "south")
t.run_seconds(0.25)
t.move(player, "south")
t.run_seconds(0.25)
t.move(player, "east")
t.run_seconds(0.25)
t.move(player, "east")
t.run_seconds(0.25)
t.move(player, "east")
t.run_seconds(0.25)
local player_x, player_y = t.pos(player)
assert(player_x == 5 and player_y == 4, "the player stands beside the test crate")
t.click(player, 6, 4, assert(t.target_at(player, 6, 4, "crate")))
t.run_ticks(2)
assert(structure_state(6, 4) == "closed", "a held unrelated tool leaves the closed crate shut")
assert(t.hands(player).held == "screwdriver", "a declined opening retains the held screwdriver")
t.drop(player)
t.run_ticks(2)
assert(t.hands(player).held == nil, "dropping the screwdriver leaves both hands empty")
assert(
    t.item_at(player_x, player_y, "screwdriver") ~= nil,
    "the dropped screwdriver stays on the player's tile"
)
t.click(player, 6, 4, assert(t.target_at(player, 6, 4, "crate")))
t.run_ticks(2)
assert(structure_state(6, 4) == "open", "empty-hand use reaches native crate opening")
assert(t.item_at(6, 4, "screwdriver") == nil, "opening leaves the screwdriver on its tile")
t.click(player, player_x, player_y, assert(t.target_at(player, player_x, player_y, "screwdriver")))
t.run_ticks(2)
assert(t.hands(player).held == "screwdriver", "the player picks up the grounded screwdriver")
t.click(player, 6, 4, assert(t.target_at(player, 6, 4, "crate")))
t.run_ticks(2)
assert(structure_state(6, 4) == "open", "native placement leaves the crate open")
assert(t.hands(player).held == nil, "native placement releases the screwdriver from the hand")
assert(t.item_at(player_x, player_y, "screwdriver") == nil, "placement clears the original tile")
assert(t.item_at(6, 4, "screwdriver") ~= nil, "native placement leaves the screwdriver on the crate tile")
t.move(player, "west")
t.run_seconds(0.25)
t.move(player, "west")
t.run_seconds(0.25)
t.click(player, 3, 5)
t.run_ticks(2)
assert(structure_state(3, 5) == "open", "empty-hand use opens the locker")
t.click(player, 3, 5)
t.run_ticks(2)
assert(structure_state(3, 5) == "closed", "empty-hand use closes the locker")

-- The same weld guard applies to a native locker: welding a closed locker
-- blocks empty-hand opening until the welder clears the welded bit.
t.move(player, "north")
t.run_seconds(0.25)
t.move(player, "north")
t.run_seconds(0.25)
t.click(player, 3, 2, assert(t.target_at(player, 3, 2, "welder")))
t.run_ticks(2)
t.move(player, "south")
t.run_seconds(0.25)
t.move(player, "south")
t.run_seconds(0.25)
t.click(player, 3, 5, assert(t.target_at(player, 3, 5, "locker")))
t.run_ticks(2)
t.run_seconds(4.0)
t.drop(player)
t.run_ticks(2)
t.click(player, 3, 5)
t.run_ticks(2)
assert(structure_state(3, 5) == "closed", "a welded locker blocks native opening")
t.click(player, 3, 4, assert(t.target_at(player, 3, 4, "welder")))
t.run_ticks(2)
t.click(player, 3, 5, assert(t.target_at(player, 3, 5, "locker")))
t.run_ticks(2)
t.run_seconds(4.0)
t.drop(player)
t.run_ticks(2)
t.click(player, 3, 5)
t.run_ticks(2)
assert(structure_state(3, 5) == "open", "an unwelded locker opens natively")

-- State, reach, held-tool, flame, and concurrent snapshot changes cancel or
-- invalidate work without blocking subsequent native interaction.
t.world(
    [==[ (
        name: "closet interruption",
        legend: {
            ' ': (composition: (substrate: Named("space"))),
            '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
            '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        },
        levels: [(
            rows: ["#######", "#.....#", "#.....#", "#.....#", "#.....#", "#######"],
            structures: [
                (3, 3, "player_spawn", { "jobs": "engineer" }),
                (4, 2, "player_spawn", { "jobs": "assistant" }),
                (3, 2, "crate"),
            ],
            items: [(3, 3, "welder"), (4, 2, "welder")],
        )],
    ) ]==],
    7
)

local worker = t.join("engineer")
local observer = t.join("assistant")
t.run_ticks(2)
t.click(worker, 3, 3, assert(t.target_at(worker, 3, 3, "welder")))
t.run_ticks(2)
t.use_self(worker)
t.run_ticks(2)

local function state(): string
    return structure_state(3, 2)
end

local function observer_opens_and_closes()
    t.click(observer, 3, 2)
    t.run_ticks(2)
    assert(state() == "open", "canceled work leaves native opening available")
    t.click(observer, 3, 2)
    t.run_ticks(2)
    assert(state() == "closed", "the observer restores the closed start state")
end

t.click(worker, 3, 2, assert(t.target_at(worker, 3, 2, "crate")))
t.run_ticks(2)
t.click(observer, 3, 2)
t.run_ticks(2)
assert(state() == "open", "another actor changes the captured target state")
t.run_seconds(4.0)
assert(state() == "open", "completion does not apply to a changed state")
t.click(observer, 3, 2)
t.run_ticks(2)

t.click(worker, 3, 2, assert(t.target_at(worker, 3, 2, "crate")))
t.run_ticks(2)
t.move(worker, "south")
t.run_seconds(0.25)
t.run_seconds(4.0)
assert(state() == "closed", "moving beyond reach cancels the task")
observer_opens_and_closes()
t.move(worker, "north")
t.run_seconds(0.25)

t.click(worker, 3, 2, assert(t.target_at(worker, 3, 2, "crate")))
t.run_ticks(2)
t.drop(worker)
t.run_ticks(2)
t.run_seconds(4.0)
assert(state() == "closed", "dropping the held tool cancels the task")
observer_opens_and_closes()
t.click(worker, 3, 3, assert(t.target_at(worker, 3, 3, "welder")))
t.run_ticks(2)

t.click(worker, 3, 2, assert(t.target_at(worker, 3, 2, "crate")))
t.run_ticks(2)
t.use_self(worker)
t.run_ticks(2)
t.use_self(worker)
t.run_ticks(2)
t.run_seconds(4.0)
assert(state() == "closed", "flame off cancels permanently through relight")
observer_opens_and_closes()

-- Two actors capture the same closed/unwelded snapshot. Only the first
-- completion may toggle it; the second must recheck the original weld bit.
t.click(observer, 4, 2, assert(t.target_at(observer, 4, 2, "welder")))
t.run_ticks(2)
t.use_self(observer)
t.run_ticks(2)
t.click(worker, 3, 2, assert(t.target_at(worker, 3, 2, "crate")))
t.run_ticks(2)
t.click(observer, 3, 2, assert(t.target_at(observer, 3, 2, "crate")))
t.run_ticks(2)
t.run_seconds(4.0)
t.drop(worker)
t.drop(observer)
t.run_ticks(2)
t.click(worker, 3, 2)
t.run_ticks(2)
assert(state() == "closed", "the concurrent second completion cannot undo the first weld")
