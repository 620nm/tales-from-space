local iv_drip = require("@helpers/iv_drip")
local clock = require("@helpers/clock")

local SEED = 3
local O_MINUS, A_PLUS = 0, 3
local NORMAL = 14

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

local function moved_to(destination: string): number
    local total = 0
    for _, row in ipairs(t.ledger_rows("matter_moved")) do
        local moles: any = row.moles
        if row.to == destination and type(moles) == "number" then
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

local CAPACITY_CLINIC = [==[(
    name: "IV capacity",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [(
        rows: ["#######", "#.....#", "#.....#", "#.....#", "#.....#", "#######"],
        structures: [
            (3, 3, "player_spawn", { "jobs": "assistant" }),
            (2, 3, "iv_drip"),
        ],
        items: [(4, 4, "blood_pack"), (4, 2, "blood_pack.o_minus")],
    )],
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

-- A full pack cuts flow off. After Eject, the same stand can keep drawing
-- from a patient below forty percent until the replacement bag fills too.
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

local low_blood_bag = iv_drip.mount(engineer_patient, "blood_pack", 4, 4, 2, 3)
iv_drip.open(engineer_patient, 2, 3)
iv_drip.attach(engineer_patient, 2, 3, engineer_patient)
t.run_seconds(2)
t.run_ticks(2)
near(blood_in(low_blood_bag), 0, "the full-bag cutoff leaves the replacement bag dry")

t.set_blood_moles(engineer_patient, NORMAL * 0.39)
local low_blood_start = t.blood_moles(engineer_patient)
assert(low_blood_start < NORMAL * 0.40, "the unattended draw starts below forty percent")
local regrowth_before_draw = minted_at("blood", 3, 3)
local bag_before_draw = blood_in(low_blood_bag)
local moved_before_draw = #t.ledger_rows("matter_moved")
iv_drip.rate(engineer_patient, 5)
t.run_seconds(42)
t.run_ticks(2)
local low_blood_after_draw = t.blood_moles(engineer_patient)
local blood_regrowth = minted_at("blood", 3, 3) - regrowth_before_draw
local bag_gain = blood_in(low_blood_bag) - bag_before_draw
near(bag_gain, 5, "the unattended drip fills the replacement bag below forty percent")
assert(low_blood_after_draw < NORMAL * 0.40, "the draw continues below forty percent")
near(
    bag_gain,
    low_blood_start + blood_regrowth - low_blood_after_draw,
    "the full bag records donor loss after measured blood regeneration",
    1e-8
)
local full_reading = assert(t.vessel(low_blood_bag), "the filled draw bag has a vessel reading")
assert(full_reading.headspace_l <= 0.001, "the draw bag is full at the one-millilitre cutoff")
local matter_rows_when_full = #t.ledger_rows("matter_moved")
assert(matter_rows_when_full > moved_before_draw, "the low-blood drip made real transfers")
t.run_seconds(4)
t.run_ticks(2)
assert(
    #t.ledger_rows("matter_moved") == matter_rows_when_full,
    "the unattended line stops transferring only after the bag fills"
)
assert(#t.script_errors() == 0, "full cutoff and below-safe strokes run without script errors")

-- A full 200-unit pack has ten units of headroom after one 10-unit infusion.
t.world(CAPACITY_CLINIC, SEED)
local donor = t.join("assistant")
t.run_seconds(3)
local _ = predrain(donor, 4, 2)
local headroom_bag = iv_drip.mount(donor, "blood_pack.o_minus", 4, 2, 2, 3)
iv_drip.open(donor, 2, 3)
iv_drip.rate(donor, 5)
iv_drip.action(donor, "toggle_mode")
local full_bag = assert(t.vessel(headroom_bag), "the O- pack starts with a vessel reading")
assert(full_bag.headspace_l <= 0.001, "the O- pack starts at the full cutoff")
local infusion_before = blood_in(headroom_bag)
local transfer_before = moved_from_at("blood pack - O-", 3, 3)
iv_drip.attach(donor, 2, 3, donor)
for _ = 1, clock.deadline_ticks(2) + 2 do
    if moved_from_at("blood pack - O-", 3, 3) > transfer_before then
        break
    end
    t.tick()
end
local transfer_after = moved_from_at("blood pack - O-", 3, 3)
assert(transfer_after > transfer_before, "one full-rate infusion records a real transfer")
local after_infusion = blood_in(headroom_bag)
local stroke_moles = 5 * 2 * 0.025
near(infusion_before - after_infusion, stroke_moles, "one full-rate infusion removes ten units")
near((infusion_before - after_infusion) / 0.025, 10, "the infusion creates ten units of headroom")
local headroom = assert(t.vessel(headroom_bag), "the partially used pack has a vessel reading")
near(headroom.headspace_l, 0.1, "ten blood units occupy one tenth of a litre", 1e-6)

local before_limited_draw = blood_in(headroom_bag)
local draw_before = moved_to("blood pack - O-")
iv_drip.action(donor, "toggle_mode")
for _ = 1, clock.deadline_ticks(2) + 2 do
    if moved_to("blood pack - O-") > draw_before then
        break
    end
    t.tick()
end
assert(moved_to("blood pack - O-") > draw_before, "the headroom-limited draw records a real transfer")
local limited_draw = blood_in(headroom_bag) - before_limited_draw
assert(limited_draw > 0, "the draw fills the available bag headroom")
assert(limited_draw <= 0.25 + 1e-9, "ten units of headroom cap the next draw at ten units")
near(blood_in(headroom_bag), 5, "the bag accepts no more than its ten-unit headroom")
assert(#t.script_errors() == 0, "the ten-unit headroom draw runs without script errors")
