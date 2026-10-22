-- Cutting is a guarded player action; native despawn receipts authorize
-- exactly two individually attributed metal spawns at the removed target.
local ui_controls = require("@helpers/ui_controls")

local function ledger_rows(event: string): { ui_controls.Record }
    return ui_controls.rows(t.ledger_rows(event))
end

local function tile_xy(row: ui_controls.Record): (number, number)
    local at = ui_controls.array(row.at)
    return ui_controls.number(at[1]), ui_controls.number(at[2])
end

local function joined_player_id(index: number): number
    local row = assert(ledger_rows("joined_job")[index])
    local actor = ui_controls.record(row.actor)
    assert(ui_controls.text(actor.kind) == "player", "the join row identifies its player")
    return ui_controls.number(actor.id)
end

local item_spawn_baseline = 0

local function begin_salvage_observation()
    item_spawn_baseline = #ledger_rows("item_spawned")
end

local function metal_rows(): { ui_controls.Record }
    local rows: { ui_controls.Record } = {}
    for ordinal, row in ipairs(ledger_rows("item_spawned")) do
        if ordinal > item_spawn_baseline and ui_controls.text(row.proto) == "metal" then
            table.insert(rows, row)
        end
    end
    return rows
end

local function assert_metal_at(
    rows: { ui_controls.Record },
    x: number,
    y: number,
    actor_id: number,
    expected: number
)
    local count = 0
    for _, row in ipairs(rows) do
        local row_x, row_y = tile_xy(row)
        if row_x == x and row_y == y then
            count += 1
            assert(ui_controls.text(row.proto) == "metal", "the receipt spawns metal")
            local quantity = ui_controls.record(row.quantity)
            assert(ui_controls.number(quantity.units) == 1, "each output is one metal unit")
            local actor = ui_controls.record(row.actor)
            assert(ui_controls.text(actor.kind) == "script", "the pack helper owns the output")
            assert(
                ui_controls.text(actor.file) == "fixtures/closets.luau",
                "the attached fixture owns the output"
            )
            assert(
                ui_controls.number(actor.triggered_by) == actor_id,
                "the cutting player owns the output"
            )
        end
    end
    assert(count == expected, "exact output count at " .. x .. "," .. y .. ": " .. count)
end

local function assert_removed_at(x: number, y: number, actor_id: number, expected: number)
    local count = 0
    for _, row in ipairs(ledger_rows("structure_step")) do
        local row_x, row_y = tile_xy(row)
        if ui_controls.text(row.to) == "gone" and row_x == x and row_y == y then
            count += 1
            local actor = ui_controls.record(row.actor)
            assert(ui_controls.text(actor.kind) == "script", "the closet handler owns the removal")
            assert(
                ui_controls.text(actor.file) == "fixtures/closets.luau",
                "the attached fixture owns the removal"
            )
            assert(
                ui_controls.number(actor.triggered_by) == actor_id,
                "the cutting player owns the removal"
            )
        end
    end
    assert(count == expected, "exact removal count at " .. x .. "," .. y .. ": " .. count)
end

local function take_and_light(player: number, x: number, y: number)
    t.click(player, x, y, assert(t.target_at(player, x, y, "welder")))
    t.run_ticks(2)
    assert(t.hands(player).held == "welder", "the player holds the welder")
    t.use_self(player)
    t.run_ticks(2)
end

-- Two identical dotted crate variants cut in the same four-second window
-- each produce two metal items attributed to their own initiating player.
t.world(
    [==[ (
        name: "parallel medical crate cuts",
        legend: {
            ' ': (composition: (substrate: Some("space"))),
            '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
            '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        },
        levels: [(
            rows: ["#########", "#.......#", "#.......#", "#########"],
            structures: [
                (2, 2, "player_spawn", { "jobs": "engineer" }),
                (6, 2, "player_spawn", { "jobs": "assistant" }),
                (3, 2, "crate.medical"),
                (5, 2, "crate.medical"),
            ],
            items: [(2, 2, "welder"), (6, 2, "welder")],
        )],
    ) ]==],
    7
)

local first = t.join("engineer")
local second = t.join("assistant")
t.run_ticks(2)
local first_id, second_id = joined_player_id(1), joined_player_id(2)
begin_salvage_observation()
t.click(first, 3, 2, assert(t.target_at(first, 3, 2, "crate.medical")))
t.click(second, 5, 2, assert(t.target_at(second, 5, 2, "crate.medical")))
t.run_ticks(2)
assert(assert(t.structure_at(3, 2)).state == "open", "the first medical crate is open")
assert(assert(t.structure_at(5, 2)).state == "open", "the second medical crate is open")
take_and_light(first, 2, 2)
take_and_light(second, 6, 2)
t.click(first, 3, 2, assert(t.target_at(first, 3, 2, "crate.medical")))
t.click(second, 5, 2, assert(t.target_at(second, 5, 2, "crate.medical")))
t.run_ticks(2)
t.run_seconds(3.5)
assert(t.structure_at(3, 2) ~= nil and t.structure_at(5, 2) ~= nil, "both targets remain before four seconds")
assert(#metal_rows() == 0, "no salvage appears before the four-second waits finish")
t.run_seconds(0.5)

local rows = metal_rows()
assert(#rows == 4, "both concurrent cuts yield exactly four individual items")
assert_metal_at(rows, 3, 2, first_id, 2)
assert_metal_at(rows, 5, 2, second_id, 2)
assert_removed_at(3, 2, first_id, 1)
assert_removed_at(5, 2, second_id, 1)

-- Two players may race on one open target, but its native removal receipt
-- yields only one two-item salvage set. A stale repeat click yields none.
t.world(
    [==[ (
        name: "same crate cut race",
        legend: {
            ' ': (composition: (substrate: Some("space"))),
            '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
            '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        },
        levels: [(
            rows: ["#######", "#.....#", "#.....#", "#######"],
            structures: [
                (2, 2, "player_spawn", { "jobs": "engineer" }),
                (4, 2, "player_spawn", { "jobs": "assistant" }),
                (3, 2, "crate.medical"),
            ],
            items: [(2, 2, "welder"), (4, 2, "welder")],
        )],
    ) ]==],
    7
)

first = t.join("engineer")
second = t.join("assistant")
t.run_ticks(2)
first_id, second_id = joined_player_id(1), joined_player_id(2)
begin_salvage_observation()
t.click(first, 3, 2, assert(t.target_at(first, 3, 2, "crate.medical")))
t.run_ticks(2)
take_and_light(first, 2, 2)
take_and_light(second, 4, 2)
local shared_target = assert(t.target_at(first, 3, 2, "crate.medical"))
t.click(first, 3, 2, shared_target)
t.run_ticks(2)
t.click(second, 3, 2, assert(t.target_at(second, 3, 2, "crate.medical")))
t.run_ticks(2)
t.run_seconds(3.5)
assert(t.structure_at(3, 2) ~= nil, "the shared target remains before four seconds")
assert(#metal_rows() == 0, "the shared target yields no early salvage")
t.run_seconds(0.5)

rows = metal_rows()
assert(#rows == 2, "a shared target produces only one salvage set")
local winning_actor = ui_controls.record(assert(rows[1]).actor)
assert(ui_controls.text(winning_actor.kind) == "script", "the winner is the closet handler")
local triggered_by = winning_actor.triggered_by
assert(triggered_by ~= nil, "the salvage receipt has a player trigger")
local winner_id = ui_controls.number(triggered_by)
assert(winner_id == first_id or winner_id == second_id, "salvage names one initiating player")
assert_metal_at(rows, 3, 2, winner_id, 2)
assert_removed_at(3, 2, winner_id, 1)
pcall(function()
    t.click(first, 3, 2, shared_target)
end)
t.run_seconds(4.0)
assert(#metal_rows() == 2, "a repeated claim on the removed target creates no salvage")
assert_removed_at(3, 2, winner_id, 1)

-- A second player drops a wrench onto the open crate's tile during the wait.
-- Cutting removes the crate while preserving that independent ground item.
t.world(
    [==[ (
        name: "cut preserves tile item",
        legend: {
            ' ': (composition: (substrate: Some("space"))),
            '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
            '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        },
        levels: [(
            rows: ["#######", "#.....#", "#.....#", "#######"],
            structures: [
                (2, 2, "player_spawn", { "jobs": "engineer" }),
                (4, 2, "player_spawn", { "jobs": "assistant" }),
                (3, 2, "crate.medical"),
            ],
            items: [(2, 2, "welder"), (4, 2, "wrench")],
        )],
    ) ]==],
    7
)

first = t.join("engineer")
second = t.join("assistant")
t.run_ticks(2)
local preservation_actor_id = joined_player_id(1)
begin_salvage_observation()
t.click(first, 3, 2, assert(t.target_at(first, 3, 2, "crate.medical")))
t.run_ticks(2)
take_and_light(first, 2, 2)
local original_wrench = assert(t.target_at(second, 4, 2, "wrench"))
t.click(second, 4, 2, original_wrench)
t.run_ticks(2)
t.click(first, 3, 2, assert(t.target_at(first, 3, 2, "crate.medical")))
t.run_ticks(2)
t.click(second, 3, 2, assert(t.target_at(second, 3, 2, "crate.medical")))
t.run_ticks(2)
assert(t.hands(second).held == nil, "the native open crate accepts the wrench")
assert(table.find(t.items_at(3, 2), "wrench") ~= nil, "the wrench is on the open crate tile")
t.run_seconds(4.0)
assert(t.structure_at(3, 2) == nil, "the open crate is removed")
local preserved_rows = metal_rows()
assert(#preserved_rows == 2, "the cut yields exactly two individual metal items")
assert_metal_at(preserved_rows, 3, 2, preservation_actor_id, 2)
assert_removed_at(3, 2, preservation_actor_id, 1)
assert(table.find(t.items_at(3, 2), "wrench") ~= nil, "the wrench remains on the cut tile")
assert(
    t.same_target(original_wrench, assert(t.target_at(second, 3, 2, "wrench"))),
    "the same wrench entity survives on the cut tile"
)

-- The same fixture attaches to actual freezer and locker base structures.
t.world(
    [==[ (
        name: "freezer and locker cuts",
        legend: {
            ' ': (composition: (substrate: Some("space"))),
            '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
            '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        },
        levels: [(
            rows: ["#######", "#.....#", "#.....#", "#.....#", "#######"],
            structures: [
                (2, 2, "player_spawn", { "jobs": "engineer" }),
                (3, 2, "freezer"),
                (2, 3, "locker"),
            ],
            items: [(2, 2, "welder")],
        )],
    ) ]==],
    7
)

first = t.join("engineer")
t.run_ticks(2)
local parity_actor_id = joined_player_id(1)
begin_salvage_observation()
t.click(first, 3, 2, assert(t.target_at(first, 3, 2, "freezer")))
t.run_ticks(2)
take_and_light(first, 2, 2)
t.click(first, 3, 2, assert(t.target_at(first, 3, 2, "freezer")))
t.run_ticks(2)
t.run_seconds(4.0)
assert_metal_at(metal_rows(), 3, 2, parity_actor_id, 2)
assert_removed_at(3, 2, parity_actor_id, 1)

t.use_self(first)
t.run_ticks(2)
t.drop(first)
t.run_ticks(2)
t.click(first, 2, 3, assert(t.target_at(first, 2, 3, "locker")))
t.run_ticks(2)
assert(assert(t.structure_at(2, 3)).state == "open", "the real locker opens natively")
take_and_light(first, 2, 2)
t.click(first, 2, 3, assert(t.target_at(first, 2, 3, "locker")))
t.run_ticks(2)
t.run_seconds(4.0)
rows = metal_rows()
assert(#rows == 4, "freezer and locker each yield exactly two items")
assert_metal_at(rows, 3, 2, parity_actor_id, 2)
assert_metal_at(rows, 2, 3, parity_actor_id, 2)
assert_removed_at(2, 3, parity_actor_id, 1)

-- A fixture-only player action races the end of the first cut and removes its
-- target. A later cut still completes instead of inheriting a stale ticket.
t.world(
    [==[ (
        name: "external closet removal releases later cuts",
        legend: {
            ' ': (composition: (substrate: Some("space"))),
            '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
            '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        },
        levels: [(
            rows: ["#############", "#...........#", "#...........#", "#############"],
            structures: [
                (2, 2, "player_spawn", { "jobs": "engineer" }),
                (4, 2, "player_spawn", { "jobs": "assistant" }),
                (10, 2, "player_spawn", { "jobs": "medic" }),
                (3, 2, "crate.medical"),
                (9, 2, "crate.medical"),
            ],
            items: [
                (2, 2, "welder"),
                (4, 2, "lunatic/tfs:closet_cut_test_remover"),
                (10, 2, "welder"),
            ],
        )],
    ) ]==],
    7
)

first = t.join("engineer")
second = t.join("assistant")
local third = t.join("medic")
t.run_ticks(2)
local external_remover_id, later_cutter_id = joined_player_id(2), joined_player_id(3)
begin_salvage_observation()
t.click(first, 3, 2, assert(t.target_at(first, 3, 2, "crate.medical")))
t.click(third, 9, 2, assert(t.target_at(third, 9, 2, "crate.medical")))
t.run_ticks(2)
take_and_light(first, 2, 2)
take_and_light(third, 10, 2)
t.click(
    second,
    4,
    2,
    assert(t.target_at(second, 4, 2, "lunatic/tfs:closet_cut_test_remover"))
)
t.run_ticks(2)
assert(t.hands(second).held == "lunatic/tfs:closet_cut_test_remover", "the fixture remover is held")

t.click(first, 3, 2, assert(t.target_at(first, 3, 2, "crate.medical")))
t.run_ticks(2)
t.run_seconds(3.5)
t.click(second, 3, 2, assert(t.target_at(second, 3, 2, "crate.medical")))
t.run_ticks(2)
assert(t.structure_at(3, 2) == nil, "the second player's action removes the first cut target")
assert_removed_at(3, 2, external_remover_id, 1)
t.run_seconds(1.0)

t.click(third, 9, 2, assert(t.target_at(third, 9, 2, "crate.medical")))
t.run_ticks(2)
t.run_seconds(4.0)
assert(t.structure_at(9, 2) == nil, "the second closet is cut successfully")
assert_metal_at(metal_rows(), 9, 2, later_cutter_id, 2)
assert_removed_at(9, 2, later_cutter_id, 1)
