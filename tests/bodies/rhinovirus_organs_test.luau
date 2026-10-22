local clock = require("@helpers/clock")
local illness_actions = require("@helpers/illness_actions")
local ui_controls = require("@helpers/ui_controls")

local SEED = 3
local COLD = 0
local BODY_REPORT = "Warning: Virus detected. Name: The Cold. Type: Airborne. Stage: 1/3. Cure: Rest."
local NONE_REPORT = "No pathogens detected."

-- Keep the default breath masks on everyone. The only inoculations in this
-- proof are the explicit culture draws and syringe injections below.
local THEATRE = [==[(
    name: "rhinovirus theatre",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "########",
                "#......#",
                "#......#",
                "########",
            ],
            structures: [
                (1, 1, "player_spawn", { "jobs": "assistant" }),
                (2, 1, "player_spawn", { "jobs": "medic" }),
                (3, 1, "player_spawn", { "jobs": "security" }),
                (2, 1, "optable"),
            ],
            items: [
                (1, 1, "scalpel"), (1, 1, "retractor"), (1, 1, "hemostat"),
                (1, 1, "circular_saw"),
                (1, 2, "syringe"),
                (2, 2, "bottle.rhinovirus_culture"),
                (3, 2, "health_analyzer"),
            ],
        ),
    ],
)]==]

t.world(THEATRE, SEED)
local surgeon = t.join("assistant")
local patient = t.join("medic")
local scanner = t.join("security")
t.run_ticks(3)
t.run_seconds(3)

local sx, sy = t.pos(surgeon)
local px, py = t.pos(patient)
local ax, ay = t.pos(scanner)
assert(sx == 1 and sy == 1, "the surgeon starts beside the table")
assert(px == 2 and py == 1, "the medic starts on the optable")
assert(ax == 3 and ay == 1, "the scanner starts beside the patient")
assert(not illness_actions.has_illness(t.body_target(patient, patient), COLD), "the patient starts without rhinovirus")
assert(not illness_actions.has_illness(t.body_target(surgeon, surgeon), COLD), "the surgeon starts without rhinovirus")
assert(not illness_actions.has_illness(t.body_target(scanner, scanner), COLD), "the scanner starts without rhinovirus")

t.rest(patient, true)
t.unequip(patient, "uniform") -- bare the chest and leave the mask in place
t.run_ticks(2)
assert(assert(t.body(patient)).posture == "lying", "the patient lies on the optable")
assert(t.worn(patient).uniform == nil, "the chest is bared for surgery")

illness_actions.take(scanner, 3, 2, "health_analyzer")
assert(t.hands(scanner).held == "health_analyzer", "the scanner holds the analyzer")

local function says(messages: {string}, fragment: string): boolean
    for _, message in ipairs(messages) do
        if message:find(fragment, 1, true) ~= nil then
            return true
        end
    end
    return false
end

local function latest_ledger_sequence(): number
    local latest = 0
    for _, row in ipairs(t.ledger_rows()) do
        if row.seq > latest then
            latest = row.seq
        end
    end
    return latest
end

local function has_syringe_mode_receipt_after(after_sequence: number, expected_mode: number): boolean
    local rows = t.ledger_rows()
    local use_self_plays: { [number]: boolean } = {}
    local provenance_rows: { [number]: boolean } = {}
    for _, row in ipairs(rows) do
        if row.seq > after_sequence
            and row.event == "played"
            and type(row.claim) == "string"
            and row.claim == "use_self"
        then
            use_self_plays[row.seq] = true
        end
    end
    for _, row in ipairs(rows) do
        if row.seq > after_sequence
            and row.event == "script_provenance"
            and row.cause ~= nil
            and use_self_plays[row.cause]
        then
            provenance_rows[row.seq] = true
        end
    end
    for _, row in ipairs(rows) do
        if row.seq > after_sequence
            and row.event == "mode_set"
            and row.cause ~= nil
            and provenance_rows[row.cause]
            and type(row.mode) == "number"
            and row.mode == expected_mode
        then
            return true
        end
    end
    return false
end

local function body_scan(subject: number): ()
    local x, y = t.pos(subject)
    t.click(scanner, x, y, t.body_target(scanner, subject))
    t.run_ticks(2)
end

local function face(value: unknown): string
    if type(value) ~= "table" then
        return tostring(value)
    end
    local label = ui_controls.record(value)
    if label.args then
        local args = ui_controls.record(label.args)
        if args.organ then
            return tostring(args.operation) .. " " .. tostring(args.organ)
        end
    end
    return tostring(label.text or label.id)
end

local function set_syringe_mode(expected: "draw" | "inject"): ()
    local after_sequence = latest_ledger_sequence()
    illness_actions.flip_syringe(surgeon)
    local expected_mode = if expected == "draw" then 0 else 1
    assert(has_syringe_mode_receipt_after(after_sequence, expected_mode), "the syringe is set to " .. expected)
end

local function hold_tool(id: string): ()
    illness_actions.take(surgeon, 1, 1, id)
    assert(t.hands(surgeon).held == id, "the surgeon holds the " .. id)
end

local function surgical_step(tool: string, seconds: number, state: string): ()
    hold_tool(tool)
    t.click(surgeon, px, py, t.body_target(surgeon, patient))
    t.run_ticks(clock.deadline_ticks(seconds) + 3)
    assert(
        assert(t.parts(patient)).chest.surgical_states[state] == true,
        "the chest reached " .. state
    )
end

-- Open the chest while the patient is healthy so the exposure-to-removal leg
-- stays short and the actual infected lung can be kept alive for reseating.
surgical_step("scalpel", 1.6, "skin_cut")
surgical_step("retractor", 2.4, "skin_open")
surgical_step("hemostat", 2.4, "vessels_clamped")
surgical_step("circular_saw", 5.4, "bone_sawed")
surgical_step("scalpel", 2.4, "organs_cut")

-- Inoculate by drawing the real, intentionally untyped culture blood and
-- injecting it into the patient through the syringe.
local syringe = illness_actions.take(surgeon, 1, 2, "syringe")
local culture = assert(t.target_at(surgeon, 2, 2, "bottle.rhinovirus_culture"))
illness_actions.draw_from_vessel(surgeon, 2, 2, culture)
assert(illness_actions.has_illness(syringe, COLD), "the culture draw carries The Cold")
set_syringe_mode("inject")
illness_actions.inject_into_body(surgeon, patient)
assert(illness_actions.has_illness(t.body_target(patient, patient), COLD), "the real syringe injection infects the patient")

t.messages(scanner)
t.messages(patient)
body_scan(patient)
local first_report_messages = t.messages(scanner)
local patient_report_messages = t.messages(patient)
assert(says(first_report_messages, BODY_REPORT), "the analyzer sees active stage 1 disease")
assert(not says(patient_report_messages, BODY_REPORT), "the disease report is private to the scanner")

-- The opened chest offers several organs. Use the real choice UI to remove
-- the patient's own lungs, rather than changing a socket or body variable.
hold_tool("hemostat")
t.click(surgeon, px, py, t.body_target(surgeon, patient))
t.run_ticks(2)
local window = ui_controls.record(t.ui(surgeon))
assert(
    window ~= nil and window.document == "modules" and window.presentation == "choices",
    "the organ choice document opened"
)
local lungs_option: string? = nil
for _, toggle in ipairs(ui_controls.rows(window.toggles)) do
    if face(toggle.label):find("lungs", 1, true) then
        lungs_option = ui_controls.text(toggle.option)
    end
end
assert(lungs_option, "the choice UI offers the lungs")
ui_controls.toggle(surgeon, "operation", lungs_option)
t.run_ticks(clock.deadline_ticks(1.0) + 3)

local empty_lungs = assert(t.sockets(patient)).lungs
assert(empty_lungs.ok == false and empty_lungs.seated == false, "the patient's lungs are removed")
assert(assert(t.body(patient)).animate, "the heart keeps the patient alive without lungs")
assert(t.target_at(surgeon, px, py, "organ_lungs") ~= nil, "the removed real lung is available to reseat")

-- One host life interval lets loss of working lungs clear the active illness
-- and rider. The analyzer reads the body through the player target.
t.run_seconds(2)
t.messages(scanner)
body_scan(patient)
local clear_messages = t.messages(scanner)
assert(says(clear_messages, NONE_REPORT), "organ-loss cure reports no active pathogens")
assert(not illness_actions.has_illness(t.body_target(patient, patient), COLD), "organ-loss cure clears the bloodstream rider")

-- A fresh culture draw is rejected while the required working lungs remain
-- absent. This is a player exposure attempt, not a resistance-state probe.
local missing_syringe = illness_actions.take(surgeon, 1, 1, "syringe")
set_syringe_mode("draw")
local missing_culture = assert(t.target_at(surgeon, 2, 2, "bottle.rhinovirus_culture"))
illness_actions.draw_from_vessel(surgeon, 2, 2, missing_culture)
assert(illness_actions.has_illness(missing_syringe, COLD), "the second culture draw is infectious")
set_syringe_mode("inject")
illness_actions.inject_into_body(surgeon, patient)
assert(not illness_actions.has_illness(t.body_target(patient, patient), COLD), "missing working lungs reject fluid exposure")

t.messages(scanner)
body_scan(patient)
local rejected_messages = t.messages(scanner)
assert(says(rejected_messages, NONE_REPORT), "the rejected exposure leaves no active disease")
assert(assert(t.sockets(patient)).lungs.seated == false, "the rejection occurred with the lungs still absent")

-- Pick up and reseat the exact organ produced by surgery, using the ordinary
-- held-organ body gesture. Then expose again to prove organ-loss cure gave no
-- resistance.
local removed_lung = illness_actions.take(surgeon, px, py, "organ_lungs")
assert(removed_lung ~= nil and t.hands(surgeon).held == "organ_lungs", "the surgeon picks up the removed lung")
t.click(surgeon, px, py, t.body_target(surgeon, patient))
t.run_ticks(clock.deadline_ticks(1.0) + 3)
local restored_lungs = assert(t.sockets(patient)).lungs
assert(restored_lungs.ok == true and restored_lungs.seated ~= false, "the real lung is seated and working")
local restored_breath_capacity = assert(
    t.capacity(patient, "breathing"),
    "working breathing capacity is observable after reseating the lung"
)
assert(restored_breath_capacity > 0, "working breath capacity returns")

local final_syringe = illness_actions.take(surgeon, 1, 1, "syringe")
set_syringe_mode("draw")
local final_culture = assert(t.target_at(surgeon, 2, 2, "bottle.rhinovirus_culture"))
illness_actions.draw_from_vessel(surgeon, 2, 2, final_culture)
assert(illness_actions.has_illness(final_syringe, COLD), "the final culture draw carries The Cold")
set_syringe_mode("inject")
illness_actions.inject_into_body(surgeon, patient)
assert(illness_actions.has_illness(t.body_target(patient, patient), COLD), "working lungs accept infection after organ-loss cure")

t.messages(scanner)
t.messages(patient)
body_scan(patient)
local reinfected_messages = t.messages(scanner)
local patient_reinfection_messages = t.messages(patient)
assert(says(reinfected_messages, BODY_REPORT), "the analyzer sees stage 1 after the real lung is reseated")
assert(not says(patient_reinfection_messages, BODY_REPORT), "the reinfection report remains private to the scanner")
