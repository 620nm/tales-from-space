local clock = require("@helpers/clock")
local ui_controls = require("@helpers/ui_controls")

-- Three seed-3 crew exercise the handheld analyzer through the same body,
-- vessel, inventory, and locker claims a player can make.
local SEED = 3
local NORMAL_BLOOD = 14.0 -- 560 u x 0.025 mol/u: code/__DEFINES/mobs.dm:20
-- Frozen no-args reporter contract: lunatic/tfs:lib.analyzer_pathogens.none.
local PATHOGENS_NONE = "No pathogens detected."
local ARENA = [==[(
    name: "health analyzer ward",
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "#########",
                "#.......#",
                "#.......#",
                "#.......#",
                "#.....#.#",
                "#.......#",
                "#.......#",
                "#########",
            ],
            structures: [
                (5, 3, "player_spawn", { "jobs": "medic" }),
                (4, 3, "player_spawn", { "jobs": "assistant" }),
                (5, 4, "player_spawn", { "jobs": "engineer" }),
                (6, 5, "locker.tools"),
            ],
            items: [
                (5, 2, "health_analyzer"),
                (5, 2, "syringe"),
                (5, 2, "beaker"),
                (6, 3, "beaker.water"),
                (6, 2, "toolbox"),
                (5, 2, "lab_flask"),
                (6, 3, "lab_flask"),
                (4, 2, "lab_flask"),
            ],
        ),
    ],
)]==]

t.world(ARENA, SEED)
local medic = t.connect()
local donor = t.connect()
local patient = t.connect()

local function prepare_named_crew_and_ready(session: number, name: string, job: string): ()
    local accepted = assert(
        t.prepare(session, {
            name = name,
            ranked_jobs = { job },
            fallback = false,
        }),
        "the connected player accepts its character draft"
    )
    assert(accepted.draft.name == name, "the accepted character draft keeps its requested name")
    assert(accepted.issue == nil, "the accepted character draft has no issue")

    local ready = assert(t.ready(session), "the accepted character draft can be marked ready")
    assert(
        ready.ready and ready.draft.name == name and ready.issue == nil,
        "the named player is ready without a preparation issue"
    )
end

prepare_named_crew_and_ready(medic, "player-1", "medic")
prepare_named_crew_and_ready(donor, "Riley North", "assistant")
prepare_named_crew_and_ready(patient, "Cormac Moroz", "engineer")

local preparation = t.round_status()
assert(
    preparation.phase == "preparing" and preparation.connected == 3 and preparation.ready == 3,
    "all three named players are ready during preparation"
)
local remaining_seconds = assert(preparation.remaining_seconds, "the preparation countdown is available")
t.preparation_steps(remaining_seconds * t.tick_hz())
assert(t.round_status().phase == "playing", "the named cohort starts together")
t.run_ticks(3)
t.run_seconds(3)

local function body_name(x: number, y: number): string
    local bodies = assert(t.bodies_at(x, y), "the body is visible")
    assert(#bodies == 1, "one body occupies the expected tile")
    return (bodies[1] :: any).name
end

local function body_blood(person: number): number
    return ui_controls.number(assert(t.body(person)).blood)
end

local function move_medic(direction: "north" | "south" | "east" | "west")
    t.move(medic, direction)
    t.run_ticks(clock.deadline_ticks(0.2) + 1)
end

local received_message_history: { [number]: { string } } = {}

local function received_messages(person: number): { string }
    local batch = t.messages(person)
    local history = received_message_history[person]
    if history == nil then
        history = {}
        received_message_history[person] = history
    end
    for _, line in ipairs(batch) do
        table.insert(history, line)
    end
    return history
end

local function messages_after(person: number, before: number): { string }
    local all = received_messages(person)
    local result: { string } = {}
    for i = before + 1, #all do
        table.insert(result, all[i])
    end
    return result
end

local function assert_report_count_and_suffix(lines: { string }, base_count: number, context: string)
    local expected_count = base_count + 1
    assert(
        #lines == expected_count,
        ("%s: expected %d report lines (%d base plus one suffix), got %d: %s"):format(
            context,
            expected_count,
            base_count,
            #lines,
            table.concat(lines, " || ")
        )
    )
    assert(lines[expected_count] == PATHOGENS_NONE, context .. ": exact final no-pathogens suffix")
end

local function assert_full_report(got: { string }, expected: { string }, context: string)
    assert_report_count_and_suffix(got, #expected, context)
    for i, line in ipairs(expected) do
        assert(got[i] == line, ("%s message %d: expected %q, got %q"):format(context, i, line, got[i]))
    end
end

local function blood_line(lines: { string }, prefix: string, suffix: string): string?
    for _, line in ipairs(lines) do
        if line:sub(1, #prefix) == prefix and line:sub(-#suffix) == suffix then
            return line
        end
    end
    return nil
end

local function has_report(lines: { string }): boolean
    for _, line in ipairs(lines) do
        if line == PATHOGENS_NONE or line:sub(1, #"Analyzing results for ") == "Analyzing results for " then
            return true
        end
    end
    return false
end

local function assert_private_report(
    before: number,
    donor_before: number,
    patient_before: number,
    context: string,
    expected: { string }
)
    assert_full_report(messages_after(medic, before), expected, context)
    assert(#messages_after(donor, donor_before) == 0, context .. " is private from the donor")
    assert(#messages_after(patient, patient_before) == 0, context .. " is private from the patient")
end

local function assert_private_vessel(
    before: number,
    donor_before: number,
    patient_before: number,
    subject: string,
    expected: string,
    context: string
)
    local lines = messages_after(medic, before)
    assert_full_report(lines, { "Analyzing results for " .. subject .. ":", expected }, context)
    assert(#messages_after(donor, donor_before) == 0, context .. " is private from the donor")
    assert(#messages_after(patient, patient_before) == 0, context .. " is private from the patient")
end

local function assert_no_new_report(before: number, donor_before: number, patient_before: number, context: string)
    assert(not has_report(messages_after(medic, before)), context .. ": no report reaches the scanner")
    assert(not has_report(messages_after(donor, donor_before)), context .. ": no report reaches the donor")
    assert(not has_report(messages_after(patient, patient_before)), context .. ": no report reaches the patient")
end

local function click_target(x: number, y: number, id: string): SpecObservedTarget
    return assert(t.target_at(medic, x, y, id), id .. " is visible at the expected tile")
end

local medic_x, medic_y = t.pos(medic)
local donor_x, donor_y = t.pos(donor)
local patient_x, patient_y = t.pos(patient)
assert(medic_x == 5 and medic_y == 3, "the medic starts in the ward")
assert(donor_x == 4 and donor_y == 3, "the assistant is west of the medic")
assert(patient_x == 5 and patient_y == 4, "the engineer is south of the medic")
local analyzer = click_target(5, 2, "health_analyzer")
t.click(medic, 5, 2, analyzer)
t.tick()
assert(t.hands(medic).held == "health_analyzer", "the analyzer is held for player actions")

local donor_target = t.body_target(medic, donor)
local patient_target = t.body_target(medic, patient)
local donor_name = body_name(4, 3)
local patient_name = body_name(5, 4)
local zero_damage = "Damage: 0 brute, 0 burn, 0 toxin, and 0 suffocation."

local donor_before, donor_bystander_before, patient_bystander_before =
    #received_messages(medic), #received_messages(donor), #received_messages(patient)
t.click(medic, 4, 3, donor_target)
t.tick()
assert_private_report(donor_before, donor_bystander_before, patient_bystander_before, "O- body scan", {
    "Analyzing results for " .. donor_name .. ":",
    "Overall status: 100% healthy.",
    zero_damage,
    "Blood level: 100%, 560 cl O-.",
    "Can receive from types O-.",
})

local patient_before, donor_patient_scan_before, receiver_scan_before =
    #received_messages(medic), #received_messages(donor), #received_messages(patient)
t.click(medic, 5, 4, patient_target)
t.tick()
assert_private_report(patient_before, donor_patient_scan_before, receiver_scan_before, "A+ body scan", {
    "Analyzing results for " .. patient_name .. ":",
    "Overall status: 100% healthy.",
    zero_damage,
    "Blood level: 100%, 560 cl A+.",
    "Can receive from types A-, A+, O-, O+.",
})

local self_name = body_name(5, 3)
local self_before, donor_self_before, patient_self_before =
    #received_messages(medic), #received_messages(donor), #received_messages(patient)
t.use_self(medic)
t.tick()
assert_private_report(self_before, donor_self_before, patient_self_before, "self-use scan", {
    "Analyzing results for " .. self_name .. ":",
    "Overall status: 100% healthy.",
    zero_damage,
    "Blood level: 100%, 560 cl A+.",
    "Can receive from types A-, A+, O-, O+.",
})

-- The saved body target is visible beyond reach and undisclosed behind a wall.
move_medic("north")
local distance_before, distance_donor_before, distance_patient_before =
    #received_messages(medic), #received_messages(donor), #received_messages(patient)
assert(t.target_at(medic, 5, 4, patient_target) ~= nil, "the patient remains visible beyond analyzer reach")
t.click(medic, 5, 4, patient_target)
t.tick()
assert_no_new_report(distance_before, distance_donor_before, distance_patient_before, "distance-two body claim")
move_medic("south")
move_medic("east")
move_medic("east")
move_medic("south")
local x, y = t.pos(medic)
assert(x == 7 and y == 4, "the medic reaches the far side of the wall")
assert(t.target_at(medic, 5, 4, patient_target) == nil, "the wall keeps the saved patient target undisclosed")
move_medic("north")
move_medic("west")
move_medic("west")

-- Draw real O- blood through the syringe, then pour that measured sample.
local sample = click_target(5, 2, "beaker")
t.swap_hands(medic)
t.tick()
local syringe = click_target(5, 2, "syringe")
t.click(medic, 5, 2, syringe)
t.tick()
assert(t.hands(medic).held == "syringe", "the syringe is active in the other hand")
t.click(medic, 4, 3, t.body_target(medic, donor))
t.run_ticks(clock.deadline_ticks(3) + 2)
t.use_self(medic)
t.tick()
t.click(medic, 5, 2, sample)
t.tick()
local actual_sample = (assert(t.contents(sample)).blood or 0)
local sample_volume_cl = actual_sample / 0.025
assert(
    math.abs(sample_volume_cl - 1.5) < 1e-9,
    ("the real syringe draw fills 1.5 cl, got %g cl"):format(sample_volume_cl)
)

-- Both the named world target and the other-hand route scan the same typed sample.
t.swap_hands(medic)
t.tick()
local typed_before = #received_messages(medic)
local typed_donor_before, typed_patient_before = #received_messages(donor), #received_messages(patient)
t.click(medic, 5, 2, sample)
t.tick()
assert_private_vessel(
    typed_before,
    typed_donor_before,
    typed_patient_before,
    "beaker",
    "Blood volume: 1.5 cl, type O-.",
    "drawn O- beaker scan"
)

-- The sample stays visible from here, but the analyzer's item action is out
-- of reach at Chebyshev distance two.
move_medic("east")
move_medic("east")
local far_x, far_y = t.pos(medic)
assert(far_x == 7 and far_y == 3, "the medic stands two tiles from the sample")
assert(t.target_at(medic, 5, 2, sample) ~= nil, "the saved sample is still visible from outside reach")
local distant_before, distant_donor_before, distant_patient_before =
    #received_messages(medic), #received_messages(donor), #received_messages(patient)
t.click(medic, 5, 2, sample)
t.tick()
assert_no_new_report(distant_before, distant_donor_before, distant_patient_before, "visible distance-two vessel claim")
move_medic("west")
move_medic("west")

t.swap_hands(medic)
t.tick()
move_medic("east")
t.drop(medic)
t.tick()
move_medic("west")
local picked_sample = click_target(5, 2, "beaker")
t.click(medic, 5, 2, picked_sample)
t.tick()
t.swap_hands(medic)
t.tick()
local otherhand_before = #received_messages(medic)
local otherhand_donor_before, otherhand_patient_before = #received_messages(donor), #received_messages(patient)
t.use_on_other(medic)
t.tick()
assert_private_vessel(
    otherhand_before,
    otherhand_donor_before,
    otherhand_patient_before,
    "beaker",
    "Blood volume: 1.5 cl, type O-.",
    "other-hand O- beaker scan"
)

local water = click_target(6, 3, "beaker.water")
local water_before = #received_messages(medic)
local water_donor_before, water_patient_before = #received_messages(donor), #received_messages(patient)
t.click(medic, 6, 3, water)
t.tick()
assert_private_vessel(
    water_before,
    water_donor_before,
    water_patient_before,
    "beaker (water)",
    "Blood volume: 0 cl, type untyped.",
    "water vessel scan"
)

-- Put the sample in the worn bag through the player inventory command, then
-- reach it only through the disclosed one-level equipment receipt.
t.swap_hands(medic)
t.tick()
t.store(medic, "back")
t.tick()
t.swap_hands(medic)
t.tick()
local sample_row: number? = nil
for i, id in ipairs(t.stored(medic, "back")) do
    if id == "beaker" then
        sample_row = i
    end
end
local nested_sample = assert(sample_row, "the drawn beaker is in the worn backpack")
local nested_site: SpecItemSite = {
    NestedEquipment = { slot = "back", path = { nested_sample - 1 } },
}
local nested_before = #received_messages(medic)
local nested_donor_before, nested_patient_before = #received_messages(donor), #received_messages(patient)
t.interact_item(medic, nested_site)
t.tick()
assert_private_vessel(
    nested_before,
    nested_donor_before,
    nested_patient_before,
    "beaker",
    "Blood volume: 1.5 cl, type O-.",
    "nested O- beaker scan"
)

-- Closing withdraws the sample from sight; opening spills it back to the deck.
-- The medic moves the opaque locker aside before targeting that same sample.
t.swap_hands(medic)
t.tick()
move_medic("east")
move_medic("east")
move_medic("south")
move_medic("south")
local locker = click_target(6, 5, "locker.tools")
t.click(medic, 6, 5, locker)
t.tick()
t.take_from(medic, "back", nested_sample)
t.tick()
assert(t.hands(medic).held == "beaker", "the sample is retrieved from storage")
t.click(medic, 6, 5, locker)
t.tick()
assert(t.hands(medic).held == nil, "the open locker accepts the held sample")
local hidden_sample = picked_sample
assert(
    t.item_at(6, 5, "beaker") ~= nil and #t.layers(medic, hidden_sample) > 0,
    "the open locker leaves the same sample disclosed on its tile"
)
t.click(medic, 6, 5, locker)
t.tick()
assert(#t.items_at(6, 5) == 0, "closing the locker returns the sample to storage")
assert(t.target_at(medic, 6, 5, hidden_sample) == nil, "the closed locker no longer discloses the saved sample")
local closed_sample = t.seen(medic, hidden_sample)
assert(
    #closed_sample.layers == 0 and closed_sample.posture == "unseen",
    "closing withdraws the same sample from the medic's received scene"
)
t.click(medic, 6, 5, locker)
t.tick()
assert(#t.items_at(6, 5) > 0, "opening spills the locker contents onto the deck")
assert(#t.layers(medic, hidden_sample) > 0, "opening restores the same sample to the medic's received scene")
t.pull(medic, 6, 5, click_target(6, 5, "locker.tools"))
t.tick()
t.move(medic, "south")
t.run_ticks(clock.deadline_ticks(0.2) + clock.deadline_ticks(0.15) + 1)
t.stop_pull(medic)
t.tick()
local pulled_x, pulled_y = t.pos(medic)
assert(
    pulled_x == 7 and pulled_y == 6
        and t.structure_at(6, 5) == nil
        and t.target_at(medic, 7, 5, locker) ~= nil,
    "the same open locker follows the medic clear of the spilled sample"
)
move_medic("north")
local restored_x, restored_y = t.pos(medic)
assert(restored_x == 7 and restored_y == 5, "the medic returns to the original locker scan position")
local visible_sample = assert(
    t.target_at(medic, 6, 5, hidden_sample),
    "the same spilled sample is hittable after the open locker is pulled aside"
)
t.swap_hands(medic)
t.tick()
local visible_before = #received_messages(medic)
local visible_donor_before, visible_patient_before = #received_messages(donor), #received_messages(patient)
t.click(medic, 6, 5, visible_sample)
t.tick()
assert_private_vessel(
    visible_before,
    visible_donor_before,
    visible_patient_before,
    "beaker",
    "Blood volume: 1.5 cl, type O-.",
    "opened-locker visible vessel scan"
)

-- Open three actual 2 L flasks for the bounded player-caused blood draw loop.
move_medic("north")
move_medic("north")
move_medic("west")
move_medic("west")
local x1, y1 = t.pos(medic)
assert(x1 == 5 and y1 == 3, "the medic returns to the ward bench")

t.swap_hands(medic)
t.tick()
local sink_one = click_target(5, 2, "lab_flask")
t.click(medic, 5, 2, sink_one)
t.tick()
assert(t.hands(medic).held == "lab_flask", "the first pressure flask is held")
t.use_self(medic)
t.tick()
move_medic("north")
t.drop(medic)
t.tick()
move_medic("south")
t.swap_hands(medic)
t.tick()

t.swap_hands(medic)
t.tick()
local sink_two = click_target(6, 3, "lab_flask")
t.click(medic, 6, 3, sink_two)
t.tick()
assert(t.hands(medic).held == "lab_flask", "the second pressure flask is held")
t.use_self(medic)
t.tick()
move_medic("east")
t.drop(medic)
t.tick()
move_medic("west")
t.swap_hands(medic)
t.tick()

-- Open the third receiving flask, then return to the ward bench.
t.swap_hands(medic)
t.tick()
move_medic("north")
local sink_three = click_target(4, 2, "lab_flask")
t.click(medic, 4, 2, sink_three)
t.tick()
assert(t.hands(medic).held == "lab_flask", "the third pressure flask is held")
t.use_self(medic)
t.tick()
move_medic("west")
t.drop(medic)
t.tick()
move_medic("east")
move_medic("south")
t.swap_hands(medic)
t.tick()

-- Keep the analyzer in one hand and retrieve the syringe from the nearby
-- deck. The draw wait uses clock.deadline_ticks(3) plus two observation
-- ticks, followed by three action ticks. The exact rate-aware duration is
-- (clock.deadline_ticks(3) + 5) / t.tick_hz(); blood regenerates 0.25 cl/s
-- against each 1.5 cl syringe draw (`content/items/vessels/syringe.luau:64-66`,
-- `content/lib/blood_harmony.luau:34-38`); each receiver holds 200 cl
-- (`content/items/vessels/lab_flask.luau:14`).
t.swap_hands(medic)
t.tick()
local syringe_on_deck = click_target(6, 3, "syringe")
t.click(medic, 6, 3, syringe_on_deck)
t.tick()
assert(t.hands(medic).held == "syringe", "the syringe is ready for measured draws")
t.use_self(medic)
t.tick()
local flask_one = click_target(5, 2, "lab_flask")
local flask_two = click_target(6, 3, "lab_flask")
local flask_three = click_target(4, 2, "lab_flask")
local sink = flask_one
local sink_x, sink_y = 5, 2
local draws = 0
local hz = t.tick_hz()
local draw_ticks = clock.deadline_ticks(3) + 5
local net_draw_loss_cl = 1.5 - 0.25 * draw_ticks / hz
assert(net_draw_loss_cl > 0, "the syringe draw removes more blood than the rate-aware regeneration")
local MAX_DRAWS = math.ceil(170.5 / net_draw_loss_cl) + 12
local DRAWS_PER_FLASK = math.ceil(MAX_DRAWS / 3)
assert(
    DRAWS_PER_FLASK * 1.5 <= 200,
    "the rate-aware bound fits across three 2 L flasks"
)

local function draw_to_vessel()
    assert(draws < MAX_DRAWS, "bounded draw loop reaches the next raw blood band")
    t.click(medic, 5, 4, t.body_target(medic, patient))
    t.run_ticks(clock.deadline_ticks(3) + 2)
    t.use_self(medic)
    t.tick()
    t.click(medic, sink_x, sink_y, sink)
    t.tick()
    t.use_self(medic)
    t.tick()
    draws += 1
    if draws == DRAWS_PER_FLASK then
        sink, sink_x, sink_y = flask_two, 6, 3
    elseif draws == 2 * DRAWS_PER_FLASK then
        sink, sink_x, sink_y = flask_three, 4, 2
    end
end

local function patient_ratio(): number
    return body_blood(patient) / NORMAL_BLOOD
end

local function assert_band_scan(
    expected_state: string,
    expected_percent: number,
    ratio: number,
    expected_recommendation: string?
)
    local percent = math.floor(ratio * 100 + 0.5)
    assert(percent == expected_percent, "the rounded report percent is at the expected band edge")
    local state = if expected_state == "normal" then "Blood level: " else "Blood level: " .. expected_state .. " "
    local prefix = state .. tostring(percent) .. "%, "
    local suffix = " cl A+."
    t.swap_hands(medic)
    t.tick()
    local before = #received_messages(medic)
    local donor_before, patient_before = #received_messages(donor), #received_messages(patient)
    t.click(medic, 5, 4, t.body_target(medic, patient))
    t.tick()
    local lines = messages_after(medic, before)
    local base_count = if expected_recommendation == nil then 5 else 6
    assert_report_count_and_suffix(lines, base_count, "blood-band scan")
    assert(lines[1] == "Analyzing results for " .. patient_name .. ":", "the blood-band report names the patient")
    assert(lines[2]:sub(1, #"Overall status: ") == "Overall status: ", "overall status remains the second report line")
    assert(lines[3]:sub(1, #"Damage: ") == "Damage: ", "damage remains the third report line")
    local rendered_blood = assert(
        blood_line(lines, prefix, suffix),
        "raw blood ratio chooses " .. expected_state .. " while displaying " .. tostring(percent) .. "%"
    )
    assert(lines[4] == rendered_blood, "blood remains the fourth report line")
    assert(lines[5] == "Can receive from types A-, A+, O-, O+.", "compatibility remains the fifth report line")
    local reported_cl = assert(
        tonumber(rendered_blood:sub(#prefix + 1, #rendered_blood - #suffix)),
        "the report includes a numeric blood volume in cl"
    )
    local observed_cl = body_blood(patient) / 0.025
    assert(math.abs(reported_cl - observed_cl) <= 0.5, "reported cl matches post-action blood within snapshot tolerance")
    if expected_recommendation ~= nil then
        assert(lines[6] == expected_recommendation, "the exact recommendation follows the base report")
    end
    assert(not has_report(messages_after(donor, donor_before)), "band report stays private from the donor")
    assert(not has_report(messages_after(patient, patient_before)), "band report stays private from the patient")
    t.swap_hands(medic)
    t.tick()
end

while patient_ratio() > 0.853 do
    draw_to_vessel()
end
local just_above_85 = patient_ratio()
assert(just_above_85 > 0.85 and just_above_85 <= 0.853, "the draw loop lands just above the raw 85% boundary")
assert_band_scan("normal", 85, just_above_85, nil)

while patient_ratio() > 0.703 do
    draw_to_vessel()
end
local just_above_70 = patient_ratio()
assert(just_above_70 > 0.70 and just_above_70 <= 0.703, "the draw loop lands just above the raw 70% boundary")
assert_band_scan("LOW", 70, just_above_70, "Recommendation: compatible blood transfusion.")

while patient_ratio() > 0.69 do
    draw_to_vessel()
end
local just_below_70 = patient_ratio()
assert(just_below_70 < 0.70 and just_below_70 > 0.685, "the bounded draw loop reaches a safe CRITICAL checkpoint")
assert_band_scan("CRITICAL", 69, just_below_70, "Recommendation: urgent compatible blood transfusion.")
assert(draws <= MAX_DRAWS, "all three raw threshold checkpoints fit the source-derived bound")

-- Damage the donor through a real held-tool swing, then verify the analyzer
-- reports the resulting nonzero brute pool privately.
assert(t.hands(medic).held == "syringe", "the analyzer test restores the syringe hand after blood scans")
t.store(medic, "back")
t.tick()
local toolbox = click_target(6, 2, "toolbox")
t.click(medic, 6, 2, toolbox)
t.tick()
assert(t.hands(medic).held == "toolbox", "the medic picks up the damage test tool")
local donor_brute_before = 0
for _, part in pairs(assert(t.parts(donor))) do
    donor_brute_before += ui_controls.number(part.brute or 0)
end
t.click(medic, 4, 3, t.body_target(medic, donor))
t.run_ticks(10)
local donor_brute_after = 0
for _, part in pairs(assert(t.parts(donor))) do
    donor_brute_after += ui_controls.number(part.brute or 0)
end
assert(
    math.abs(donor_brute_after - donor_brute_before - 10) < 1e-6,
    "the player-caused toolbox swing adds 10 brute"
)
t.swap_hands(medic)
t.tick()
local damage_scan_before = #received_messages(medic)
local damage_donor_before, damage_patient_before = #received_messages(donor), #received_messages(patient)
t.click(medic, 4, 3, t.body_target(medic, donor))
t.tick()
local damage_report = messages_after(medic, damage_scan_before)
assert_report_count_and_suffix(damage_report, 5, "damaged-donor scan")
assert(damage_report[1] == "Analyzing results for " .. donor_name .. ":", "the damaged donor is scanned")
assert(damage_report[2]:sub(1, #"Overall status: ") == "Overall status: ", "overall status remains second")
assert(
    damage_report[3] == "Damage: 10 brute, 0 burn, 0 toxin, and 0 suffocation.",
    "the report shows the player-caused brute damage"
)
assert(damage_report[4]:sub(1, #"Blood level: ") == "Blood level: ", "blood remains fourth")
assert(damage_report[5] == "Can receive from types O-.", "compatibility remains fifth")
assert(not has_report(messages_after(donor, damage_donor_before)), "the damage report stays private from the donor")
assert(not has_report(messages_after(patient, damage_patient_before)), "the damage report stays private from the patient")
