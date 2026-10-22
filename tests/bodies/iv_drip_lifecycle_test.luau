local iv_drip = require("@helpers/iv_drip")
local ui_controls = require("@helpers/ui_controls")

local ROOM = [==[(
    name: "iv-line-lifecycle",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [(
        rows: [
            "###############",
            "#.............#",
            "#.............#",
            "#.............#",
            "#.............#",
            "#.............#",
            "#.............#",
            "###############",
        ],
        structures: [
            (4, 2, "iv_drip"),
            (11, 2, "iv_drip"),
            (4, 3, "player_spawn", { "jobs": "assistant" }),
            (5, 3, "player_spawn", { "jobs": "medic" }),
        ],
        items: [(3, 3, "water_bottle_large"), (12, 3, "water_bottle_large")],
    )],
)]==]

local function near(got: number, want: number, what: string): ()
    assert(math.abs(got - want) < 1e-6, ("%s: %.6f, not %.6f"):format(what, got, want))
end

local function vessel_water(vessel: SpecObservedTarget): number
    local contents = assert(t.contents(vessel), "the observed vessel keeps its contents")
    return ui_controls.number(contents.water or 0)
end

local function body_water(player: number): number
    return ui_controls.number(t.blood(player).water or 0)
end

local function has_control(state: ui_controls.Record, field: string, option: string?): boolean
    local function rows_have(value: unknown): boolean
        for _, row in ipairs(ui_controls.rows(value or {})) do
            if row.field == field and (option == nil or row.option == option) then
                return true
            end
        end
        return false
    end

    if rows_have(state.toggles) or rows_have(state.labels) or rows_have(state.setpoints) then
        return true
    end
    for _, panel in ipairs(ui_controls.rows(state.control_panels or {})) do
        if rows_have(panel.toggles) or rows_have(panel.labels) or rows_have(panel.setpoints) then
            return true
        end
    end
    return false
end

local function wounds(player: number): { brute: number, blood: number, bleeding_parts: number }
    local totals = { brute = 0, blood = 0, bleeding_parts = 0 }
    for _, part in pairs(assert(t.parts(player), "the patient has body parts")) do
        totals.brute += ui_controls.number(part.brute or 0)
        local stacks = ui_controls.number(part.leak_stacks.blood or 0)
        totals.blood += stacks
        if stacks > 0 then
            totals.bleeding_parts += 1
        end
    end
    return totals
end

t.world(ROOM, 0)
local patient = t.join("assistant")
local other = t.join("medic")
t.run_ticks(3)
local patient_body_id = t.body_id(patient)

-- Public drag names its patient directly; the panel retains only flow controls.
local vessel_a = iv_drip.mount(patient, "water_bottle_large", 3, 3, 4, 2)
iv_drip.open(patient, 4, 2)
local patient_water = body_water(patient)
local other_water = body_water(other)
local panel_scope = assert(t.ui_document(patient), "the first stand panel is open")
local panel_state = ui_controls.state(patient)
assert(
    not has_control(panel_state, "action", "connect"),
    "Connect is absent from disclosed controls"
)
assert(
    ui_controls.find(patient, "/toggle/action/connect", panel_scope) == nil,
    "Connect is absent from the rendered panel"
)
for _, action in ipairs({
    "disconnect",
    "toggle_mode",
    "flow_down",
    "flow_up",
    "flow_max",
    "flow_off",
}) do
    assert(has_control(panel_state, "action", action), action .. " remains disclosed")
    assert(
        ui_controls.find(patient, "/toggle/action/" .. action, panel_scope) ~= nil,
        action .. " remains rendered"
    )
end
local rate_input_disclosed = false
for _, row in ipairs(ui_controls.rows(panel_state.labels or {})) do
    if row.row == "input" and row.action == "rate" then
        rate_input_disclosed = true
        break
    end
end
assert(rate_input_disclosed, "the rate input remains disclosed")
assert(
    ui_controls.find(patient, "/label/rate/value", panel_scope) ~= nil,
    "the rate input remains rendered"
)
local before_implicit_transfers = #t.ledger_rows("MatterMoved")
t.run_ticks(2)
t.run_seconds(3)
near(vessel_water(vessel_a), 2.5, "panel inspection leaves the vessel untouched")
near(body_water(patient), patient_water, "panel inspection does not transfer to the actor")
near(body_water(other), other_water, "panel inspection does not transfer to the other body")
assert(
    #t.ledger_rows("MatterMoved") == before_implicit_transfers,
    "panel inspection starts no implicit transfer"
)

-- Move the other body away to free the actor's drag route.
for _ = 1, 2 do
    t.move(other, "south")
    t.run_ticks(6)
end

-- Movement interrupts a pending self drag. Its generation cannot later flow.
iv_drip.drag_to_patient(patient, 4, 2, patient)
t.move(patient, "east")
t.run_ticks(6)
local moved_x, moved_y = t.pos(patient)
assert(moved_x == 5 and moved_y == 3, "the patient reaches the pending-movement destination")
t.run_seconds(3)
near(vessel_water(vessel_a), 2.5, "movement cancels the pending attempt")
near(body_water(patient), patient_water, "the canceled attempt injects nothing")
t.move(patient, "west")
t.run_ticks(6)
t.ui_close(patient)
t.run_ticks(2)
iv_drip.open(patient, 4, 2)
iv_drip.drag_to_patient(patient, 4, 2, patient)
iv_drip.drag_to_patient(patient, 4, 2, patient)
t.run_seconds(1)
t.run_ticks(2)

-- Pull the real stand one tile while the patient remains adjacent. The
-- native body-location edge must keep this line; its first stroke still lands.
local stand_a = assert(t.target_at(patient, 4, 2, "iv_drip"))
t.pull(patient, 4, 2, stand_a)
t.run_ticks(1)
t.move(patient, "east")
t.run_ticks(6)
local moved_stand_a = assert(t.target_at(patient, 4, 3, "iv_drip"))
assert(t.same_target(moved_stand_a, stand_a), "the real pull moved the stand into the vacated tile")
assert(wounds(patient).brute == 0, "an adjacent pulled stand does not rip the line")
t.run_seconds(2.5)
near(vessel_water(vessel_a), 2.25, "one current generation makes one stroke")
local water_transfers = t.ledger_rows("MatterMoved")
assert(#water_transfers == 1, "one current generation makes one native water receipt")
near(
    ui_controls.number(water_transfers[1].moles),
    0.25,
    "the native water receipt carries one quarter mole"
)
-- One native metabolism pass at tick 240 removes 0.005 mol from the healthy body.
near(
    body_water(patient),
    patient_water + 0.25 - 0.005,
    "one stroke reaches the attached patient"
)
assert(#t.ledger_rows("Damaged") == 0, "adjacent stand motion creates no damage receipt")

-- Disconnect before leaving station A so the next patient's movement tests
-- cannot be attributed to this line.
t.stop_pull(patient)
t.ui_close(patient)
t.run_ticks(2)
iv_drip.open(patient, 4, 3)
iv_drip.action(patient, "disconnect")
local after_disconnect_transfers = #t.ledger_rows("MatterMoved")
t.run_seconds(2.5)
near(vessel_water(vessel_a), 2.25, "intentional disconnect stops strokes while the vessel stays docked")
assert(
    #t.ledger_rows("MatterMoved") == after_disconnect_transfers,
    "intentional disconnect adds no water transfer"
)
assert(#t.ledger_rows("Damaged") == 0, "intentional disconnect leaves no rip receipt")

-- A zero-rate line still follows the patient-location edge. One tile is
-- adjacent; crossing beyond Chebyshev distance one opens one real wound.
for _ = 1, 6 do
    t.move(patient, "east")
    t.run_ticks(6)
end
local px, py = t.pos(patient)
assert(px == 11 and py == 3, "the patient reaches the second station")
local vessel_b = iv_drip.mount(patient, "water_bottle_large", 12, 3, 11, 2)
iv_drip.open(patient, 11, 2)
local second_stand_scope = assert(t.ui_document(patient), "second stand rate document is open")
local second_stand_rate_input = ui_controls.node(patient, "/label/rate/value", second_stand_scope)
t.ui_edit(patient, second_stand_rate_input.id, "0")
ui_controls.press(patient, "/label/rate/send", nil, second_stand_scope)
t.run_ticks(2)
local before_zero_rate_transfers = #t.ledger_rows("MatterMoved")
iv_drip.attach(patient, 11, 2, patient)
t.run_seconds(2.5)
near(vessel_water(vessel_b), 2.5, "zero rate does not drain the second vessel")
assert(
    #t.ledger_rows("MatterMoved") == before_zero_rate_transfers,
    "zero rate adds no water transfer"
)

t.move(patient, "east")
t.run_ticks(6)
assert(wounds(patient).brute == 0, "the first step remains within line range")
assert(#t.ledger_rows("Damaged") == 0, "adjacency produces no damage receipt")
local moved_before_rip = #t.ledger_rows("Moved")
t.move(patient, "east")
t.run_ticks(6)
local ripped = wounds(patient)
near(ripped.brute, 3, "leaving adjacency applies one three-brute rip")
near(ripped.blood, 3, "the ordinary bloodshed handler opens one matching wound")
assert(ripped.bleeding_parts == 1, "one rip opens one bleeder")
local moved_rows = t.ledger_rows("Moved")
assert(#moved_rows == moved_before_rip + 1, "the rip follows one native move")
local move = moved_rows[#moved_rows]
assert(
    move.actor.kind == "player" and move.actor.id == patient_body_id,
    "the rip follows the patient's actual movement"
)
local move_cause = assert(move.cause, "the move names its Play input")
local played: SpecLedgerRow? = nil
for _, row in ipairs(t.ledger_rows("Played")) do
    if row.seq == move_cause then
        played = row
        break
    end
end
local played_row = assert(played, "the move cause is its actual Play row")
assert(
    played_row.actor.kind == "player" and played_row.actor.id == patient_body_id,
    "the patient's Play input caused the movement"
)
local damage = t.ledger_rows("Damaged")
assert(
    #damage == 1 and damage[1].zone ~= nil and damage[1].target == patient_body_id,
    "the rip has one native damage receipt naming its patient and part"
)
local rip_actor = damage[1].actor
assert(rip_actor.kind == "script", "the IV handler owns the rip")
assert(
    rip_actor.file == "fixtures/iv_drip.luau"
        and rip_actor.triggered_by == patient_body_id,
    "the IV handler names the patient who triggered it"
)
local damage_cause = assert(damage[1].cause, "the rip names its IV handler provenance row")
local provenance: SpecLedgerRow? = nil
for _, row in ipairs(t.ledger_rows("ScriptProvenance")) do
    if row.seq == damage_cause then
        provenance = row
        break
    end
end
local provenance_row = assert(provenance, "the rip cause is its actual ScriptProvenance row")
assert(
    provenance_row.cause == played_row.seq,
    "the IV handler provenance descends from the same Play input as the movement"
)
near(vessel_water(vessel_b), 2.5, "the zero-rate vessel stays full through the rip")
t.run_seconds(2.5)
near(wounds(patient).brute, 3, "the endpoint does not reinjure on later checks")
assert(#t.ledger_rows("Damaged") == 1, "later checks add no second damage receipt")

-- Return to station A. Eject alone must survive the next two-second dock
-- check safely; a later Disconnect refusal proves the line already retired.
for _ = 1, 8 do
    t.move(patient, "west")
    t.run_ticks(6)
end
px, py = t.pos(patient)
assert(px == 5 and py == 3, "the patient returns beside the moved first stand")
t.ui_close(patient)
t.run_ticks(2)
iv_drip.open(patient, 4, 3)
local before_reconnect_transfers = #t.ledger_rows("MatterMoved")
iv_drip.attach(patient, 4, 3, patient)
local damage_before_eject = #t.ledger_rows("Damaged")
iv_drip.eject(patient)
assert(t.hands(patient).held == "water_bottle_large", "native Eject returns the docked vessel to the patient")
t.run_seconds(3)
near(vessel_water(vessel_a), 2.25, "Eject alone stops later strokes after the dock check")
assert(
    #t.ledger_rows("MatterMoved") == before_reconnect_transfers,
    "Eject alone adds no later water transfer"
)
assert(wounds(patient).brute == 3, "Eject alone does not rip the line")
assert(#t.ledger_rows("Damaged") == damage_before_eject, "Eject alone adds no damage receipt")
t.swap_hands(patient)
assert(t.hands(patient).held == nil, "the active hand is empty before reopening the stand")
t.ui_close(patient)
t.run_ticks(2)
iv_drip.open(patient, 4, 3)
t.messages(patient)
iv_drip.action(patient, "disconnect")
local disconnect_messages = t.messages(patient)
assert(
    #disconnect_messages == 1,
    "the later Disconnect is refused after Eject's safe detach"
)
assert(#t.script_errors() == 0, "the lifecycle actions run without script errors")

-- Empty-dock wrench work binds the actual IV receiver, rechecks occupancy
-- through the native Eject path, and only pays out after a completed chore.
t.world(
    [==[(
    name: "iv-drip-wrench",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [(
        rows: ["#######", "#.....#", "#.....#", "#.....#", "#######"],
        structures: [
            (2, 1, "iv_drip"),
            (2, 2, "player_spawn", { "jobs": "assistant" }),
        ],
        items: [(3, 2, "water_bottle_large"), (1, 2, "wrench")],
    )],
)]==],
    0
)

local dismantler = t.join("assistant")
t.run_ticks(3)
local docked_vessel = iv_drip.mount(dismantler, "water_bottle_large", 3, 2, 2, 1)
near(vessel_water(docked_vessel), 2.5, "the observed vessel is docked before wrench refusal")
local metal_before = t.count_items("metal")
t.click(dismantler, 1, 2, t.target_at(dismantler, 1, 2, "wrench"))
t.run_ticks(2)
assert(t.hands(dismantler).held == "wrench", "the wrench is in hand beside the mounted vessel")

t.messages(dismantler)
t.click(dismantler, 2, 1, t.target_at(dismantler, 2, 1, "iv_drip"))
t.run_ticks(2)
local occupied_refusal = t.messages(dismantler)
assert(#occupied_refusal == 1, "a docked vessel refuses one wrench attempt")
assert(assert(t.structure_at(2, 1)).id == "iv_drip", "the occupied stand stays in place")
assert(t.count_items("metal") == metal_before, "an occupied stand pays out no metal")
assert(t.hands(dismantler).held == "wrench", "the occupied refusal keeps the wrench")

-- Native Eject returns the vessel; drop both carried objects through the
-- player action so the empty stand can be selected with the wrench again.
t.drop(dismantler)
t.run_ticks(2)
iv_drip.open(dismantler, 2, 1)
iv_drip.eject(dismantler)
assert(t.hands(dismantler).held == "water_bottle_large", "native Eject returns the vessel to hand")
t.drop(dismantler)
t.run_ticks(2)
t.ui_close(dismantler)
t.run_ticks(2)
t.click(dismantler, 2, 2, t.target_at(dismantler, 2, 2, "wrench"))
t.run_ticks(2)
assert(t.hands(dismantler).held == "wrench", "the dropped wrench is picked up again")

-- Leaving the work interrupts the four-second chore; its deadline cannot
-- remove the stand or mint a sheet after the actor has walked away.
local interruptions_before = #t.ledger_rows("DoAfterInterrupted")
t.messages(dismantler)
t.click(dismantler, 2, 1, t.target_at(dismantler, 2, 1, "iv_drip"))
t.run_ticks(2)
local wrench_started = t.messages(dismantler)
assert(#wrench_started == 1, "an empty stand begins one wrench chore")
t.run_seconds(3.8)
assert(assert(t.structure_at(2, 1)).id == "iv_drip", "nothing stands a breath short of four seconds")
assert(t.count_items("metal") == metal_before, "the incomplete chore pays out no metal")
t.move(dismantler, "south")
t.run_ticks(6)
t.move(dismantler, "east")
t.run_ticks(6)
local away_x, away_y = t.pos(dismantler)
assert(away_x == 3 and away_y == 3, "the actor left wrench reach")
t.run_seconds(4.5)
assert(assert(t.structure_at(2, 1)).id == "iv_drip", "walking away interrupts deconstruction")
assert(t.count_items("metal") == metal_before, "an interrupted chore pays out no metal")
assert(
    #t.ledger_rows("DoAfterInterrupted") == interruptions_before + 1,
    "the native wrench chore records its interruption"
)

-- Return to reach and finish a fresh, uninterrupted native receiver action.
t.move(dismantler, "west")
t.run_ticks(6)
t.move(dismantler, "north")
t.run_ticks(6)
local back_x, back_y = t.pos(dismantler)
assert(back_x == 2 and back_y == 2, "the actor returned beside the empty stand")
t.messages(dismantler)
local spawned_before_completed_wrench = #t.ledger_rows("ItemSpawned")
t.click(dismantler, 2, 1, t.target_at(dismantler, 2, 1, "iv_drip"))
t.run_seconds(4.5)
assert(t.structure_at(2, 1) == nil, "the completed wrench chore removes the stand")
assert(t.count_items("metal") == metal_before + 1, "one completed stand returns exactly one metal")
local spawned = t.ledger_rows("ItemSpawned")
local metal_rows = 0
local metal_units = 0
for index = spawned_before_completed_wrench + 1, #spawned do
    local row = spawned[index]
    if ui_controls.text(row.proto) == "metal" then
        local metal_row = row :: { proto: string, quantity: { units: number? } }
        local units = ui_controls.number(metal_row.quantity.units)
        assert(units == 1, "the native metal spawn row carries one typed unit")
        metal_rows += 1
        metal_units += units
    end
end
assert(metal_rows == 1, "the completed wrench chore creates one metal spawn row")
assert(metal_units == 1, "the completed wrench chore returns one metal unit total")
assert(t.hands(dismantler).held == "wrench", "deconstruction does not consume the wrench")
assert(#t.script_errors() == 0, "the receiver actions run without script errors")
