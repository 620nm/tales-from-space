-- A docked stand dragged onto a named body starts the shared IV line.
local iv_drip = require("@helpers/iv_drip")
local ui_controls = require("@helpers/ui_controls")

t.world(
    [==[(
    name: "IV drag ward",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [ "########", "#......#", "#......#", "#......#", "########" ],
            structures: [
                (2, 2, "player_spawn", { "jobs": "medic" }),
                (3, 1, "player_spawn", { "jobs": "assistant" }),
                (3, 3, "player_spawn", { "jobs": "engineer" }),
                (3, 2, "iv_drip"),
                (1, 2, "optable"),
            ],
            items: [(3, 2, "beaker")],
        ),
    ],
)]==],
    0
)

local starter = t.join("medic")
local patient = t.join("assistant")
local other_patient = t.join("engineer")
t.run_ticks(3)

local function stand_target(player: number): SpecObservedTarget
    local target = t.target_at(player, 3, 2, "iv_drip")
    assert(target ~= nil, "the stand is visible")
    return target
end

local function appearance(state: string)
    local stand = t.structure_at(3, 2)
    assert(stand ~= nil and stand.id == "iv_drip", "the stand remains on its tile")
    assert(stand.state == state, ("state: wanted %s, got %s"):format(state, tostring(stand.state)))
    assert(stand.sprite == state, ("sprite: wanted %s, got %s"):format(state, tostring(stand.sprite)))
end

local function drag_to_patient(player: number, target_player: number)
    t.drag(
        player,
        3,
        2,
        stand_target(player),
        3,
        if target_player == patient then 1 else 3,
        t.body_target(player, target_player)
    )
end

local function walk(player: number, direction: "east" | "west", count: number)
    for _ = 1, count do
        t.move(player, direction)
        t.run_ticks(8)
    end
end

appearance("iv_drip_injectidle")

-- All three bodies are adjacent; the observed drag target names the patient.
drag_to_patient(starter, patient)
t.run_seconds(1)
appearance("iv_drip_injectidle")

local bag = iv_drip.mount(starter, "beaker", 3, 2, 3, 2)

local function bag_blood(): number
    return ui_controls.number((assert(t.contents(bag))).blood or 0)
end

local invalid_target = t.target_at(starter, 1, 2, "optable")
assert(invalid_target ~= nil, "the non-body target is visible")
t.drag(starter, 3, 2, stand_target(starter), 1, 2, invalid_target)
t.run_seconds(1)
appearance("iv_drip_injectidle")

-- A visible stand and body are still refused when the starter cannot reach
-- both ends of the drag.
walk(starter, "east", 3)
assert(t.pos(starter) == 5, "the starter stepped out of reach")
drag_to_patient(starter, patient)
t.run_seconds(1)
appearance("iv_drip_injectidle")
walk(starter, "west", 3)
assert(t.pos(starter) == 2, "the starter returned to the stand")

-- The guarded attachment is interrupted if its named patient leaves while
-- the one-second attempt is pending.
drag_to_patient(starter, patient)
t.run_ticks(2)
t.move(patient, "east")
t.run_ticks(8)
assert(t.pos(patient) == 4, "the patient left during attachment")
t.run_seconds(1)
appearance("iv_drip_injectidle")
t.move(patient, "west")
t.run_ticks(8)
assert(t.pos(patient) == 3, "the patient returned beside the stand")

iv_drip.open(starter, 3, 2)
drag_to_patient(starter, patient)
t.run_seconds(1)
t.run_ticks(2)
appearance("iv_drip_injecting")

iv_drip.rate(starter, 0)
appearance("iv_drip_injectidle")
iv_drip.action(starter, "toggle_mode")
appearance("iv_drip_donateidle")
iv_drip.rate(starter, 0.1)
appearance("iv_drip_donating")
iv_drip.action(starter, "disconnect")
appearance("iv_drip_donateidle")

-- Reattach for the public control state, then leave the line in draw mode.
drag_to_patient(starter, patient)
t.run_seconds(1)
iv_drip.rate(starter, 0.1)
t.run_ticks(2)
appearance("iv_drip_donating")
iv_drip.action(starter, "toggle_mode")
appearance("iv_drip_injecting")
iv_drip.action(starter, "toggle_mode")
appearance("iv_drip_donating")

-- The empty beaker has 50 mL of headspace. At 0.1 u/s, each two-second
-- stroke transfers 0.005 mol blood, about 2 mL; the full continuation
-- window is at most six strokes, well below its capacity.
t.move(starter, "north")
t.run_ticks(8)
t.move(starter, "west")
t.run_ticks(8)
local starter_x, starter_y = t.pos(starter)
assert(starter_x == 1 and starter_y == 1, "the starter left the stand before dying")
t.set_health(starter, { oxy = 500 })
t.run_ticks(4)
local dead_starter = assert(t.body(starter))
assert(not dead_starter.animate, "the starter is medically dead")
local blood_before_dead_interval = bag_blood()
t.run_seconds(4)
local blood_after_dead_interval = bag_blood()
assert(
    blood_after_dead_interval > blood_before_dead_interval,
    "the bag keeps receiving blood after its starter leaves and dies"
)
appearance("iv_drip_donating")

t.disconnect(starter)
t.run_ticks(4)
local blood_before_disconnect_interval = bag_blood()
t.run_seconds(4)
local blood_after_disconnect_interval = bag_blood()
assert(
    blood_after_disconnect_interval > blood_before_disconnect_interval,
    "the bag keeps receiving blood after its starter disconnects"
)
appearance("iv_drip_donating")

-- Keep the second nearby patient explicit through the whole spec.
assert(t.body(other_patient) ~= nil, "the other visible patient remained in the ward")

print("iv drag: explicit patient selection, painter states, guarded starts, and starter-independent flow")

local function selection_body_water(player: number): number
    return ui_controls.number(t.blood(player).water or 0)
end

local function selection_vessel_water(vessel: SpecObservedTarget): number
    return ui_controls.number((assert(t.contents(vessel))).water or 0)
end

local function verify_selected_body(selected_job: "assistant" | "engineer"): ()
    t.world(
        [==[(
    name: "IV drag selection",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [(
        rows: [ "########", "#......#", "#......#", "#......#", "########" ],
        structures: [
            (3, 2, "iv_drip"),
            (2, 2, "player_spawn", { "jobs": "medic" }),
            (3, 1, "player_spawn", { "jobs": "assistant" }),
            (3, 3, "player_spawn", { "jobs": "engineer" }),
        ],
        items: [(2, 3, "water_bottle_large")],
    )],
)]==],
        0
    )

    local starter = t.join("medic")
    local assistant = t.join("assistant")
    local engineer = t.join("engineer")
    t.run_ticks(3)
    local selected = if selected_job == "assistant" then assistant else engineer
    local unselected = if selected_job == "assistant" then engineer else assistant
    local starter_x, starter_y = t.pos(starter)
    local assistant_x, assistant_y = t.pos(assistant)
    local engineer_x, engineer_y = t.pos(engineer)
    assert(
        starter_x == 2 and starter_y == 2
            and assistant_x == 3 and assistant_y == 1
            and engineer_x == 3 and engineer_y == 3,
        "the starter and both distinct body targets are adjacent to the same stand"
    )

    local starter_body_id = t.body_id(starter)
    local bottle = iv_drip.mount(starter, "water_bottle_large", 2, 3, 3, 2)
    local source_before = selection_vessel_water(bottle)
    local starter_before = selection_body_water(starter)
    local selected_before = selection_body_water(selected)
    local unselected_before = selection_body_water(unselected)
    local selected_x, selected_y = t.pos(selected)

    iv_drip.attach(starter, 3, 2, selected)
    t.run_seconds(2.5)

    local transfers = t.ledger_rows("MatterMoved")
    assert(#transfers == 1, "one isolated public attachment makes one native transfer")
    local receipt = transfers[1]
    local moved = ui_controls.number(receipt.moles)
    assert(math.abs(moved - 0.25) < 1e-6, "the native receipt carries one quarter mole")
    local position = ui_controls.array(
        assert(receipt.pos, "the receipt records its destination tile")
    )
    assert(
        ui_controls.number(position[1]) == selected_x
            and ui_controls.number(position[2]) == selected_y,
        "the receipt destination is the uniquely selected body's actual tile"
    )
    assert(
        math.abs((source_before - selection_vessel_water(bottle)) - moved) < 1e-6,
        "the mounted vessel loses exactly the amount in its native receipt"
    )
    assert(selection_body_water(selected) > selected_before, "the selected body gains water")
    assert(
        math.abs(selection_body_water(unselected) - unselected_before) < 1e-6,
        "the unselected adjacent body gains no water"
    )
    assert(
        math.abs(selection_body_water(starter) - starter_before) < 1e-6,
        "the starter gains no water"
    )

    local actor = receipt.actor
    assert(actor.kind == "script", "the native transfer is attributed to its script")
    assert(
        actor.file == "fixtures/iv_drip.luau" and actor.triggered_by == starter_body_id,
        "the transfer retains the drag handler and initiating body"
    )
    local receipt_cause = assert(receipt.cause, "the transfer names its script provenance")
    local provenance: SpecLedgerRow? = nil
    for _, row in ipairs(t.ledger_rows("ScriptProvenance")) do
        if row.seq == receipt_cause then
            provenance = row
            break
        end
    end
    local provenance_row = assert(
        provenance,
        "the transfer cause is its actual ScriptProvenance row"
    )
    local provenance_actor = provenance_row.actor
    assert(
        provenance_actor.kind == "script",
        "the transfer cause names a script provenance row"
    )
    assert(
        provenance_actor.file == actor.file
            and provenance_actor.triggered_by == starter_body_id,
        "the receipt provenance retains the valid IV script actor and triggering body"
    )
end

verify_selected_body("assistant")
verify_selected_body("engineer")
