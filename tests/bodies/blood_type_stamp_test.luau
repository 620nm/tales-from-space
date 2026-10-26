local clock = require("@helpers/clock")

local SEED = 3
local O_MINUS, A_PLUS = 0, 3
local BLOOD_REPORTS = {
    { name = "O-", donors = "O-" },
    { name = "O+", donors = "O-, O+" },
    { name = "A-", donors = "A-, O-" },
    { name = "A+", donors = "A-, A+, O-, O+" },
    { name = "B-", donors = "B-, O-" },
    { name = "B+", donors = "B-, B+, O-, O+" },
    { name = "AB-", donors = "A-, B-, AB-, O-" },
    { name = "AB+", donors = "A-, A+, B-, B+, O-, O+, AB-, AB+" },
}

t.world(
    [==[(
    name: "blood stamp ward",
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [ "######", "#....#", "#....#", "######" ],
            structures: [
                (2, 1, "player_spawn", { "jobs": "medic" }),
                (1, 1, "player_spawn", { "jobs": "assistant" }),
                (3, 1, "player_spawn", { "jobs": "engineer" }),
            ],
        ),
    ],
)]==],
    SEED,
    "space_station"
)

local function rider_type(target: number | SpecObservedTarget): number?
    local entries = t.riders(target)
    if entries == nil then
        return nil
    end
    for _, entry in ipairs(entries) do
        if entry.id == "blood_identity" and typeof(entry.fields.type) == "number" then
            return entry.fields.type
        end
    end
    return nil
end

local function identity_sets(): { any }
    local out: { any } = {}
    for _, row in ipairs(t.ledger_rows("rider_set")) do
        if row.rider == "blood_identity" then
            table.insert(out, row)
        end
    end
    return out
end

local function row_type(row: any): number?
    if typeof(row.fields) ~= "table" then
        return nil
    end
    for _, field in ipairs(row.fields :: { any }) do
        if field.name == "type" and typeof(field.value) == "number" then
            return field.value
        end
    end
    return nil
end

local function body_name(x: number, y: number): string
    local bodies = assert(t.bodies_at(x, y), "the joined body is visible")
    assert(#bodies == 1, "exactly one body occupies the spawn")
    return (bodies[1] :: any).name
end

local medic = t.join("medic")
local medic_stamps = identity_sets()
assert(#medic_stamps == 1, "the medic has one spawn stamp before time advances")
assert(row_type(medic_stamps[1]) == A_PLUS, "the pre-life medic stamp is A+")

local donor = t.join("assistant")
local receiver = t.join("engineer")
local joins = t.ledger_rows("joined_job")
local stamps = identity_sets()
assert(#joins == 3, ("three join completions are recorded, got %d"):format(#joins))
assert(#stamps == 3, ("three spawn stamps land before life, got %d"):format(#stamps))

local dealt: { [string]: number } = {}
for index, row in ipairs(stamps) do
    local join = joins[index]
    local join_actor = join.actor
    assert(row.tick == join.tick, "each stamp shares its join completion tick")
    assert(join_actor.kind == "player", "each join completion belongs to its player")
    assert(row.actor.kind == "script", "each rider is written by the body script")
    assert(row.actor.triggered_by == join_actor.id, "each stamp is caused by that join")
    dealt[row.owner] = assert(row_type(row), "each rider row records its type")
end
assert(dealt[body_name(2, 1)] == A_PLUS, "the final medic Mind name draws A+")
assert(dealt[body_name(1, 1)] == O_MINUS, "the seed-3 donor Mind name draws O-")
assert(dealt[body_name(3, 1)] == A_PLUS, "the seed-3 receiver Mind name draws A+")

-- Joined bodies become observable on the first second; their spawn stamps
-- already precede the first and repeated mob.life passes.
t.run_seconds(1)
local medic_body = assert(t.body_target(medic, medic), "the published medic can observe their own body")
local donor_body = assert(t.body_target(donor, donor), "the published donor can observe their own body")
local receiver_body = assert(t.body_target(receiver, receiver), "the published receiver can observe their own body")
assert(rider_type(medic_body) == A_PLUS, "the published medic remains A+")
assert(rider_type(donor_body) == O_MINUS, "the published seed-3 donor remains O-")
assert(rider_type(receiver_body) == A_PLUS, "the published seed-3 receiver remains A+")
t.run_seconds(3)
assert(#identity_sets() == #stamps, "repeated mob.life passes add no spawn duplicates")
assert(#t.script_errors() == 0, "spawn stamps and repeated life passes run cleanly")

-- A stocked native drawer starts with its typed, stopped body hidden.
t.world(
    [==[(
    name: "typed cadaver bench",
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
    },
    levels: [
        (
            rows: [ "#######", "#.....#", "#.....#", "#.aoG.#", "#######" ],
            items: [
                (1, 1, "health_analyzer"),
            ],
            structures: [
                (1, 1, "player_spawn"),
                (2, 1, "cadaver_chamber.cadaver", { "dir": "east" }),
                (2, 2, "cadaver_chamber", { "dir": "east" }),
                (2, 3, "apc"),
            ],
            networks: [
                (x: 4, y: 3, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 2, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 2, y: 3, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 3, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 3, y: 3, network: "power", channel: "l2", kind: "cable", facing: 15),
            ],
        ),
    ],
)]==],
    0
)

local attendant = t.join()
t.tick()
assert(#t.bodies_at(3, 1) == 0, "joining does not disclose the cadaver")
local pre_open_sets = identity_sets()
assert(#pre_open_sets == 2, "the hidden cadaver and attendant each have one pre-open stamp")
local attendant_name = body_name(1, 1)
local attendant_joins = t.ledger_rows("joined_job")
assert(#attendant_joins == 1, "the attendant has one join completion")
local join_actor = attendant_joins[1].actor
assert(join_actor.kind == "player", "the attendant join belongs to its player")
local cadaver_stamp: any = nil
local attendant_stamp: any = nil
for _, row in ipairs(pre_open_sets) do
    if row.actor.triggered_by == join_actor.id then
        assert(attendant_stamp == nil, "one pre-open stamp belongs to the attendant")
        attendant_stamp = row
    else
        assert(cadaver_stamp == nil, "one pre-open stamp belongs to the hidden cadaver")
        cadaver_stamp = row
    end
end
attendant_stamp = assert(attendant_stamp, "the attendant has a causal spawn stamp")
assert(attendant_stamp.owner == attendant_name, "the causal stamp belongs to the attendant")
cadaver_stamp = assert(cadaver_stamp, "the hidden cadaver has a pre-open rider row")
local pre_open_type = assert(row_type(cadaver_stamp), "the hidden body stamp carries a type")

local drawer = assert(t.target_at(attendant, 2, 1, "cadaver_chamber.cadaver"))
t.click(attendant, 2, 1, drawer)
t.tick()

local revealed = assert(t.bodies_at(3, 1), "the opened drawer reveals its body")
assert(#revealed == 1, "the drawer reveals exactly one cadaver")
local corpse = revealed[1]
assert(corpse.plan == "human" and corpse.player == false, "the revealed native body is a human cadaver")
assert(corpse.animate == false, "the body is stopped")
assert(cadaver_stamp.owner == corpse.name, "the pre-open ledger stamp belongs to the revealed corpse")
assert(rider_type(corpse.id) == pre_open_type, "the disclosed body keeps its pre-open blood type")
assert(#t.script_errors() == 0, "native cadaver stamping runs cleanly")

local function move_attendant(direction: "north" | "south" | "east" | "west")
    t.move(attendant, direction)
    t.run_ticks(clock.deadline_ticks(0.2) + 1)
end

local analyzer = assert(t.target_at(attendant, 1, 1, "health_analyzer"), "the analyzer is visible beside the attendant")
t.click(attendant, 1, 1, analyzer)
t.tick()
assert(t.hands(attendant).held == "health_analyzer", "the attendant holds the analyzer for player actions")

move_attendant("south")
move_attendant("south")
move_attendant("east")
move_attendant("east")
move_attendant("north")
local attendant_x, attendant_y = t.pos(attendant)
assert(attendant_x == 3 and attendant_y == 2, "the attendant walks around both cabinets to the corpse")

local corpse_target = assert(
    t.target_at(attendant, 3, 1, "name:" .. corpse.name),
    "the revealed stopped corpse is targetable by its disclosed name"
)
local report_before = #t.messages(attendant)
t.click(attendant, 3, 1, corpse_target)
t.tick()

local blood_report = assert(BLOOD_REPORTS[pre_open_type + 1], "the pre-open type maps to a blood report")
-- 560 cl reports the full 14 mol reservoir (code/__DEFINES/mobs.dm:20 at 0.025 mol/u).
local expected_report = {
    "Analyzing results for " .. corpse.name .. ":",
    "Overall status: Deceased.",
    "Damage: 200 brute, 0 burn, 0 toxin, and 0 suffocation.",
    "Blood level: 100%, 560 cl " .. blood_report.name .. ".",
    "Can receive from types " .. blood_report.donors .. ".",
}
local all_messages = t.messages(attendant)
local new_messages: { string } = {}
for index = report_before + 1, #all_messages do
    table.insert(new_messages, all_messages[index])
end
assert(
    #new_messages == #expected_report or #new_messages == #expected_report + 1,
    ("the corpse scan emits its five-line report and optional pathogen suffix, got %d lines: %s"):format(
        #new_messages,
        table.concat(new_messages, " || ")
    )
)
for index, expected in ipairs(expected_report) do
    assert(
        new_messages[index] == expected,
        ("corpse scan message %d: expected %q, got %q"):format(index, expected, new_messages[index])
    )
end
if #new_messages == #expected_report + 1 then
    assert(
        new_messages[#new_messages] == "No pathogens detected.",
        "only the contracted pathogen suffix follows the report"
    )
end
assert(#t.script_errors() == 0, "the stopped corpse scan runs cleanly")
