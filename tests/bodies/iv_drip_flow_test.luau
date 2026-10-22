local iv_drip = require("@helpers/iv_drip")

local SEED = 3
local O_MINUS, A_PLUS = 0, 3
local NORMAL = 13.75

local function near(got: number, want: number, what: string, slack: number?)
    local tolerance = slack or 1e-9
    assert(math.abs(got - want) < tolerance, ("%s: wanted %g, got %g"):format(what, want, got))
end

local function blood_in(vessel: SpecObservedTarget): number
    local contents = assert(t.contents(vessel), "the observed vessel has contents")
    return contents.blood or 0
end

local function at_position(row: SpecLedgerRow, x: number, y: number): boolean
    local position = row.pos
    return position ~= nil and #position >= 2 and position[1] == x and position[2] == y
end

-- `matter_moved` is the native row for the stand's real transfer command.
-- Its source name and destination-body position correlate concurrent lines.
local function moved_from_at(source: string, x: number, y: number): number
    local total = 0
    for _, row in ipairs(t.ledger_rows("matter_moved")) do
        local moles: any = row.moles
        if row.from == source and at_position(row, x, y) and type(moles) == "number" then
            total += moles
        end
    end
    return total
end

local function minted_at(substance: string, x: number, y: number): number
    local total = 0
    for _, row in ipairs(t.ledger_rows("minted")) do
        local moles: any = row.moles
        if row.substance == substance and at_position(row, x, y) and type(moles) == "number" then
            total += moles
        end
    end
    return total
end

local function rider_type(target: SpecObservedTarget): number?
    local entries = t.riders(target)
    if entries == nil then
        return nil
    end
    for _, entry in ipairs(entries) do
        if entry.id == "blood_identity" then
            local value: any = entry.fields.type
            if type(value) == "number" then
                return value
            end
        end
    end
    return nil
end

local function overlay(target: SpecObservedTarget): string?
    return t.overlays(target)[1]
end

local CHAMBERS = [==[(
    name: "IV chambers",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "####################",
                "#....###....###....#",
                "#....###....###....#",
                "#....###....###....#",
                "#....###....###....#",
                "#....###....###....#",
                "####################",
            ],
            structures: [
                (3, 3, "player_spawn", { "jobs": "medic" }),
                (2, 3, "iv_drip"),
                (10, 3, "player_spawn", { "jobs": "assistant" }),
                (9, 3, "iv_drip"),
                (17, 3, "player_spawn", { "jobs": "engineer" }),
                (16, 3, "iv_drip"),
            ],
            items: [
                (3, 4, "blood_pack"),
                (4, 4, "blood_pack.o_minus"),
                (10, 4, "blood_pack"),
                (11, 4, "blood_pack.a_plus"),
            ],
        ),
    ],
)]==]

local CLINIC = [==[(
    name: "IV clinic",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "#######",
                "#.....#",
                "#.....#",
                "#.....#",
                "#.....#",
                "#######",
            ],
            structures: [
                (3, 3, "player_spawn", { "jobs": "medic" }),
                (2, 3, "iv_drip"),
            ],
            items: [
                (3, 4, "blood_pack"),
                (4, 4, "blood_pack"),
            ],
        ),
    ],
)]==]

-- Two bodies run against separate stands at different rates. Both receive a
-- real draw first so neither injection is confounded by a full bloodstream.
t.world(CHAMBERS, SEED)
local medic = t.join("medic")
local assistant = t.join("assistant")
t.join("engineer")
t.run_seconds(3)

local function predrain(player: number, x: number, stand_x: number): SpecObservedTarget
    local bag = iv_drip.mount(player, "blood_pack", x, 4, stand_x, 3)
    iv_drip.open(player, stand_x, 3)
    iv_drip.action(player, "toggle_mode")
    iv_drip.rate(player, 5)
    iv_drip.attach(player, stand_x, 3, player)
    t.run_seconds(10)
    t.run_ticks(2)
    iv_drip.action(player, "disconnect")
    iv_drip.eject(player)
    assert(t.hands(player).held == "blood_pack", "Eject returns the drawn bag to the patient")
    t.drop(player)
    t.run_ticks(2)
    near(blood_in(bag), 1.25, "five real draw strokes fill the bag")
    local remaining_blood = t.blood_moles(player)
    assert(remaining_blood >= NORMAL - 1.25 - 1e-6, "the patient stays above the amount-drawn floor")
    assert(remaining_blood < NORMAL, "the real draw leaves the patient below normal despite regeneration")
    return bag
end

local medic_draw = predrain(medic, 3, 2)
local assistant_draw = predrain(assistant, 10, 9)
assert(rider_type(medic_draw) == A_PLUS, "the medic's draw carries the A+ rider")
assert(rider_type(assistant_draw) == O_MINUS, "the assistant's draw carries the O- rider")

local medic_source = iv_drip.mount(medic, "blood_pack.o_minus", 4, 4, 2, 3)
local assistant_source = iv_drip.mount(assistant, "blood_pack.a_plus", 11, 4, 9, 3)
iv_drip.open(medic, 2, 3)
iv_drip.action(medic, "toggle_mode")
iv_drip.rate(medic, 5)
iv_drip.open(assistant, 9, 3)
iv_drip.action(assistant, "toggle_mode")
iv_drip.rate(assistant, 1)

near(blood_in(medic_source), 5, "the sealed O- source starts full")
near(blood_in(assistant_source), 5, "the sealed A+ source starts full")
assert(rider_type(medic_source) == O_MINUS, "the compatible source is O-")
assert(rider_type(assistant_source) == A_PLUS, "the incompatible source is A+")

local medic_source_before = blood_in(medic_source)
local assistant_source_before = blood_in(assistant_source)
local medic_blood_before = t.blood_moles(medic)
local assistant_blood_before = t.blood_moles(assistant)
local medic_o_minus_at_medic_before = moved_from_at("blood pack - O-", 3, 3)
local medic_a_plus_at_medic_before = moved_from_at("blood pack - A+", 3, 3)
local assistant_a_plus_at_assistant_before = moved_from_at("blood pack - A+", 10, 3)
local assistant_o_minus_at_assistant_before = moved_from_at("blood pack - O-", 10, 3)
local medic_toxin_minted_before = minted_at("toxin", 3, 3)
local assistant_toxin_minted_before = minted_at("toxin", 10, 3)
iv_drip.attach(medic, 2, 3, medic)
iv_drip.attach(assistant, 9, 3, assistant)
t.run_seconds(10)
t.run_ticks(2)

near(medic_source_before - blood_in(medic_source), 1.25, "the 5u/s source loses five exact strokes")
near(assistant_source_before - blood_in(assistant_source), 0.25, "the 1u/s source loses five exact strokes")
near(
    moved_from_at("blood pack - O-", 3, 3) - medic_o_minus_at_medic_before,
    1.25,
    "the compatible line's native receipts reach the medic from its O- pack"
)
near(
    moved_from_at("blood pack - A+", 10, 3) - assistant_a_plus_at_assistant_before,
    0.25,
    "the incompatible line's native receipts reach the assistant from its A+ pack"
)
near(
    moved_from_at("blood pack - A+", 3, 3) - medic_a_plus_at_medic_before,
    0,
    "the assistant's A+ receipts never land on the compatible medic"
)
near(
    moved_from_at("blood pack - O-", 10, 3) - assistant_o_minus_at_assistant_before,
    0,
    "the medic's O- receipts never land on the incompatible assistant"
)
assert(t.blood_moles(medic) > medic_blood_before, "compatible infusion raises the medic's blood above its prior level")
assert(t.blood_moles(medic) <= NORMAL + 0.25 + 1e-6, "the post-stroke surplus stays within one 0.25-mol stroke")
assert(t.blood_moles(assistant) >= assistant_blood_before + 0.20, "incompatible infusion raises the assistant's blood")
assert(t.blood_moles(assistant) <= NORMAL, "the incompatible patient's blood stays within normal")
near(minted_at("toxin", 3, 3) - medic_toxin_minted_before, 0, "compatible O- mints no toxin on the A+ medic")
near(
    minted_at("toxin", 10, 3) - assistant_toxin_minted_before,
    0.125,
    "the incompatible assistant receives the exact toxin mint for its moved dose"
)
assert(rider_type(medic_source) == O_MINUS, "the partially used compatible bag keeps its rider")
assert(rider_type(assistant_source) == A_PLUS, "the partially used incompatible bag keeps its rider")
assert(#t.script_errors() == 0, "concurrent self-lines run without script errors")

-- A sub-rung amount is still real blood: the nonempty pack has its first
-- picture and rider, and the next measured stroke empties both away.
t.world(CLINIC, SEED)
local patient = t.join("medic")
t.run_seconds(3)
local tiny = iv_drip.mount(patient, "blood_pack", 3, 4, 2, 3)
iv_drip.open(patient, 2, 3)
iv_drip.action(patient, "toggle_mode")
iv_drip.rate(patient, 0.01)
iv_drip.attach(patient, 2, 3, patient)
t.run_seconds(2)
t.run_ticks(2)
near(blood_in(tiny), 0.0005, "one minimum-rate stroke still moves blood")
assert(rider_type(tiny) == A_PLUS, "the tiny nonempty draw keeps blood identity")
assert(overlay(tiny) == "bloodpack10", "a nonempty rounded-zero pack shows its first picture")

local tiny_return_before = moved_from_at("blood pack", 3, 3)
iv_drip.action(patient, "toggle_mode")
t.run_seconds(2)
t.run_ticks(2)
near(blood_in(tiny), 0, "the return stroke leaves a truly empty pack")
near(moved_from_at("blood pack", 3, 3) - tiny_return_before, 0.0005, "the native return receipt reaches the patient")
assert(rider_type(tiny) == nil, "true empty clears the blood identity rider")
assert(overlay(tiny) == nil, "true empty removes the pack picture")
assert(#t.script_errors() == 0, "small direct IV strokes run without script errors")

-- Filling a sealed pack cuts flow off. The stand remembers rate zero after
-- Eject, and the same patient can then be drawn only as far as forty percent.
t.world(CLINIC, SEED)
local engineer_patient = t.join("medic")
t.run_seconds(3)
local full = iv_drip.mount(engineer_patient, "blood_pack", 3, 4, 2, 3)
iv_drip.open(engineer_patient, 2, 3)
iv_drip.action(engineer_patient, "toggle_mode")
iv_drip.rate(engineer_patient, 5)
iv_drip.attach(engineer_patient, 2, 3, engineer_patient)
t.run_seconds(42)
t.run_ticks(2)
near(blood_in(full), 5, "the sealed bag fills to five moles")
local blood_after_full = t.blood_moles(engineer_patient)
assert(blood_after_full >= NORMAL - 5 - 1e-6, "the donor retains blood regenerated during the five-mole draw")
assert(blood_after_full <= NORMAL - 4.6, "the full bag's five moles came from the donor after timed regrowth")
assert(rider_type(full) == A_PLUS, "the full bag retains the patient's rider")

iv_drip.action(engineer_patient, "disconnect")
iv_drip.eject(engineer_patient)
assert(t.hands(engineer_patient).held == "blood_pack", "the full sealed bag ejects into the hand")
t.drop(engineer_patient)
t.run_ticks(2)

local floor_bag = iv_drip.mount(engineer_patient, "blood_pack", 4, 4, 2, 3)
iv_drip.open(engineer_patient, 2, 3)
iv_drip.attach(engineer_patient, 2, 3, engineer_patient)
t.run_seconds(2)
t.run_ticks(2)
near(blood_in(floor_bag), 0, "the full-bag cutoff leaves the replacement bag dry")

local floor = NORMAL * 0.40
local blood_before_floor = t.blood_moles(engineer_patient)
local floor_regrowth_before = minted_at("blood", 3, 3)
local floor_bag_before = blood_in(floor_bag)
iv_drip.rate(engineer_patient, 5)
t.run_seconds(30)
t.run_ticks(2)
local blood_at_floor = t.blood_moles(engineer_patient)
local floor_regrowth = minted_at("blood", 3, 3) - floor_regrowth_before
local floor_bag_gain = blood_in(floor_bag) - floor_bag_before
assert(blood_at_floor >= floor - 1e-6, "repeated real strokes never cross forty percent")
assert(blood_at_floor <= floor + 0.05, "enough strokes bring the donor to the protected floor")
assert(floor_bag_gain > 3, "the replacement bag receives the available blood surplus")
near(
    floor_bag_gain,
    blood_before_floor + floor_regrowth - blood_at_floor,
    "the floor bag records donor loss after measured blood regeneration",
    1e-8
)
assert(
    floor_bag_gain <= blood_before_floor - floor + floor_regrowth + 1e-8,
    "flow cannot take more than the surplus plus measured regeneration"
)

local blood_before_regrowth = blood_at_floor
local regrowth_before_followup = minted_at("blood", 3, 3)
local bag_before_followup = blood_in(floor_bag)
t.run_seconds(8)
t.run_ticks(2)
local blood_after_regrowth = t.blood_moles(engineer_patient)
local regenerated_surplus = minted_at("blood", 3, 3) - regrowth_before_followup
local regrowth_drawn = blood_in(floor_bag) - bag_before_followup
assert(blood_after_regrowth >= floor - 1e-6, "later strokes continue to respect the forty-percent floor")
assert(blood_after_regrowth <= floor + 0.05, "ongoing flow stays close to the protected floor")
assert(regrowth_drawn > 0, "the active line draws blood that the patient regenerates")
assert(
    regrowth_drawn <= blood_before_regrowth - floor + regenerated_surplus + 1e-8,
    "ongoing flow is limited to the starting surplus plus measured regeneration"
)
near(
    regrowth_drawn,
    blood_before_regrowth + regenerated_surplus - blood_after_regrowth,
    "follow-up draw matches regenerated blood",
    1e-8
)
assert(#t.script_errors() == 0, "full cutoff and floor strokes run without script errors")
