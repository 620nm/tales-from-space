-- A second player can pull a live line's stand beyond its patient.
local iv_drip = require("@helpers/iv_drip")
local ui_controls = require("@helpers/ui_controls")

local ROOM = [==[(
    name: "iv-drip-rip-endpoint",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [(
        rows: [
            "##############",
            "#............#",
            "#............#",
            "#............#",
            "#............#",
            "##############",
        ],
        structures: [
            (5, 2, "iv_drip"),
            (5, 1, "player_spawn", { "jobs": "assistant" }),
            (4, 2, "player_spawn", { "jobs": "medic" }),
        ],
        items: [(4, 1, "water_bottle_large")],
    )],
)]==]

local function near(got: number, want: number, what: string): ()
    assert(math.abs(got - want) < 1e-6, ("%s: %.6f, not %.6f"):format(what, got, want))
end

local function vessel_water(vessel: SpecObservedTarget): number
    local contents = assert(t.contents(vessel), "the observed vessel keeps its contents")
    return ui_controls.number(contents.water or 0)
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
local puller = t.join("medic")
t.run_ticks(3)

local patient_body_id = t.body_id(patient)
local puller_body_id = t.body_id(puller)
local patient_x, patient_y = t.pos(patient)
local puller_x, puller_y = t.pos(puller)
assert(patient_x == 5 and patient_y == 1, "the original patient starts north of the stand")
assert(puller_x == 4 and puller_y == 2, "the second player starts west of the stand")

local vessel = iv_drip.mount(patient, "water_bottle_large", 4, 1, 5, 2)
local stand = assert(t.target_at(patient, 5, 2, "iv_drip"))
local matter_before_attach = #t.ledger_rows("MatterMoved")
t.drag(patient, 5, 2, stand, 5, 1, t.body_target(patient, patient))
t.run_seconds(1)
iv_drip.open(patient, 5, 2)
iv_drip.rate(patient, 5)
t.run_seconds(3)

local matter_before_rip = #t.ledger_rows("MatterMoved")
assert(matter_before_rip > matter_before_attach, "the active line records a native matter transfer")
assert(vessel_water(vessel) > 0, "the bottle remains nonempty after the pre-rip flow")

local pull_target = assert(t.target_at(puller, 5, 2, "iv_drip"))
local pull_rows_before = #t.ledger_rows("PullStarted")
t.pull(puller, 5, 2, pull_target)
t.run_ticks(1)
local pull_rows = t.ledger_rows("PullStarted")
assert(#pull_rows == pull_rows_before + 1, "the second player starts one real pull")
local pull_actor = pull_rows[#pull_rows].actor
assert(
    pull_actor.kind == "player"
        and pull_actor.id == puller_body_id,
    "the pull ledger names the second player's body"
)

-- Pull follows each step into the tile the puller just left.
t.move(puller, "west")
t.run_ticks(6)
local first_pull_x, first_pull_y = t.pos(puller)
assert(first_pull_x == 3 and first_pull_y == 2, "the puller takes the first west step")
assert(t.same_target(assert(t.target_at(puller, 4, 2, "iv_drip")), stand), "the stand follows to (4,2)")
local still_patient_x, still_patient_y = t.pos(patient)
assert(still_patient_x == patient_x and still_patient_y == patient_y, "the original patient stays put")
assert(#t.ledger_rows("Damaged") == 0, "the first pull step keeps the stand adjacent")

local moved_before_separation = #t.ledger_rows("Moved")
local matter_before_separation = #t.ledger_rows("MatterMoved")
t.move(puller, "west")
t.run_ticks(6)
local separation_x, separation_y = t.pos(puller)
assert(separation_x == 2 and separation_y == 2, "the puller takes the separating step")
assert(t.same_target(assert(t.target_at(puller, 3, 2, "iv_drip")), stand), "the stand reaches (3,2)")
assert(t.target_at(puller, 5, 2, "iv_drip") == nil, "the stand leaves its original tile")
local patient_at_rip_x, patient_at_rip_y = t.pos(patient)
assert(patient_at_rip_x == patient_x and patient_at_rip_y == patient_y, "the patient remains at (5,1)")
local rip_distance = math.max(math.abs(3 - patient_x), math.abs(2 - patient_y))
assert(rip_distance == 2, "the pulled stand reaches separation beyond adjacency")

local moved_rows = t.ledger_rows("Moved")
local puller_move: SpecLedgerRow? = nil
for index = moved_before_separation + 1, #moved_rows do
    local row = moved_rows[index]
    if row.actor.kind == "player" and row.actor.id == puller_body_id then
        puller_move = row
        break
    end
end
local move = assert(puller_move, "the separating walk has a native Moved row for the puller")
local move_cause = assert(move.cause, "the puller's move names its Play input")
local played: SpecLedgerRow? = nil
for _, row in ipairs(t.ledger_rows("Played")) do
    if row.seq == move_cause then
        played = row
        break
    end
end
local played_row = assert(played, "the move cause is the puller's actual Play row")
assert(
    played_row.actor.kind == "player" and played_row.actor.id == puller_body_id,
    "the puller's Play input caused the separating movement"
)

local ripped = wounds(patient)
near(ripped.brute, 3, "the original patient receives one three-brute rip")
near(ripped.blood, 3, "the ordinary bloodshed handler opens one matching wound")
assert(ripped.bleeding_parts == 1, "one rip opens one bleeding part on the original patient")
local damage = t.ledger_rows("Damaged")
assert(
    #damage == 1 and damage[1].zone ~= nil and damage[1].target == patient_body_id,
    "the native damage receipt names the original patient and actual body zone"
)
local rip_actor = damage[1].actor
assert(rip_actor.kind == "script" and rip_actor.file == "fixtures/iv_drip.luau", "the IV handler owns the rip")
assert(rip_actor.triggered_by == puller_body_id, "the puller's body triggered the rip handler")
local damage_cause = assert(damage[1].cause, "the damage names its ScriptProvenance row")
local provenance: SpecLedgerRow? = nil
for _, row in ipairs(t.ledger_rows("ScriptProvenance")) do
    if row.seq == damage_cause then
        provenance = row
        break
    end
end
local provenance_row = assert(provenance, "the damage cause is its actual ScriptProvenance row")
assert(
    provenance_row.cause == played_row.seq,
    "the rip provenance descends from the puller's Play input"
)

local idle_stand = assert(t.structure_at(3, 2), "the stand remains at its separated tile")
assert(idle_stand.id == "iv_drip", "the separated structure is the original stand")
assert(idle_stand.state == "iv_drip_injectidle", "retirement paints the stand idle")
assert(idle_stand.sprite == "iv_drip_injectidle", "the idle state selects the idle sprite")
local matter_after_rip = #t.ledger_rows("MatterMoved")
assert(
    matter_after_rip == matter_before_separation,
    "separation stops native transfers at the positive-rate flow baseline"
)

-- A later stand endpoint event cannot reopen the retired line.
t.move(puller, "west")
t.run_ticks(6)
local later_stand = assert(t.target_at(puller, 2, 2, "iv_drip"))
assert(t.same_target(later_stand, stand), "the loose stand follows one more pull step to (2,2)")
t.stop_pull(puller)
t.run_ticks(1)
t.run_seconds(3)
near(wounds(patient).brute, 3, "later endpoint events do not add another wound")
assert(#t.ledger_rows("Damaged") == 1, "later endpoint events add no damage receipt")
assert(#t.ledger_rows("MatterMoved") == matter_after_rip, "retirement stops all later native transfers")
assert(#t.script_errors() == 0, "the player-driven rip raises no script error")
