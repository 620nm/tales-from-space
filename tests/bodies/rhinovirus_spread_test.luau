local clock = require("@helpers/clock")
local illness_actions = require("@helpers/illness_actions")
local airborne_protection = require("@helpers/airborne_protection")

local SEED = 0
local RHINOVIRUS = 0
local BREATH_SECONDS = 8
local OBSERVATION_SECONDS = 120

local MAP = [==[(
    name: "airborne ward",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "#########",
                "#....#..#",
                "#....#..#",
                "#....#..#",
                "#....#..#",
                "#....#..#",
                "#....#..#",
                "#....#..#",
                "#########",
            ],
            structures: [
                (4, 4, "player_spawn", { "jobs": "medic" }),
                (3, 4, "player_spawn", { "jobs": "assistant" }),
                (2, 6, "player_spawn", { "jobs": "engineer" }),
                (4, 1, "player_spawn", { "jobs": "captain" }),
                (6, 4, "player_spawn", { "jobs": "security" }),
            ],
            items: [
                (4, 4, "bio_protection_probe"),
                (4, 4, "syringe"),
                (4, 4, "bottle.rhinovirus_culture"),
            ],
        ),
    ],
)]==]

t.world(MAP, SEED)

local source = t.join("medic")
local masked = t.join("assistant")
local diagonal = t.join("engineer")
local range_three = t.join("captain")
local behind_wall = t.join("security")
t.run_ticks(3)

local function at(player: number, x: number, y: number, role: string): ()
    local px, py = t.pos(player)
    assert(px == x and py == y, role .. " uses its declared spawn")
end

at(source, 4, 4, "source")
at(masked, 3, 4, "masked target")
at(diagonal, 2, 6, "diagonal target")
at(range_three, 4, 1, "range-three target")
at(behind_wall, 6, 4, "wall target")

for _, player in ipairs({ source, masked, diagonal, range_three, behind_wall }) do
    assert(t.worn(player).mask == "breath_mask", "each job begins masked")
end

local function has_rhinovirus(player: number): boolean
    return illness_actions.has_illness(t.body_target(player, player), RHINOVIRUS)
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

local function pocket_oxygen_tank(player: number): number
    for index, id in ipairs(t.stored(player, "back")) do
        if id == "emergency_tank.oxygen" then
            return index
        end
    end
    error("the assistant carries its pocket oxygen tank")
end

-- The receiver keeps a mask on while its real pocket tank runs internals.
t.take_from(masked, "back", pocket_oxygen_tank(masked))
t.run_ticks(2)
assert(t.hands(masked).held == "emergency_tank.oxygen", "the tank is in hand")
t.use_self(masked)
t.run_ticks(2)
local supply = t.vitals(masked)
assert(supply ~= nil and supply.tank ~= nil, "internals are open behind the mask")
airborne_protection.assert_checks(source, 4, 4)

-- Seed the source through the syringe and the contaminated culture bottle.
illness_actions.take(source, 4, 4, "syringe")
local culture = assert(
    t.target_at(source, 4, 4, "bottle.rhinovirus_culture"),
    "the culture bottle is on the source tile"
)
illness_actions.draw_from_vessel(source, 4, 4, culture)
local after_initial_flip = latest_ledger_sequence()
illness_actions.flip_syringe(source)
assert(has_syringe_mode_receipt_after(after_initial_flip, 1), "the syringe is set to inject")
illness_actions.inject_into_body(source, source)
assert(has_rhinovirus(source), "self-injection gives the masked source rhinovirus")
assert(t.worn(source).mask == "breath_mask", "the source remains masked after inoculation")

local function unmask(player: number, role: string): ()
    t.unequip(player, "mask")
    t.run_ticks(2)
    assert(t.worn(player).mask == nil, role .. " removed its mask")
end

unmask(diagonal, "diagonal target")
unmask(range_three, "range-three target")
unmask(behind_wall, "wall target")

local breath_ticks = clock.deadline_ticks(BREATH_SECONDS)

-- A masked carrier stays blocked through a full body-local breath interval.
t.run_ticks(breath_ticks)
assert(not has_rhinovirus(diagonal), "a masked source cannot infect an unmasked diagonal subject")
assert(not has_rhinovirus(range_three), "a masked source cannot infect a range-three subject")
assert(not has_rhinovirus(masked), "a masked source cannot infect a masked internals user")
assert(not has_rhinovirus(behind_wall), "a masked source cannot infect a subject behind the wall")

unmask(source, "source")
if t.now() % breath_ticks == 0 then
    t.tick()
end
assert(t.now() % breath_ticks ~= 0, "the source becomes unmasked off the global breath phase")

local diagonal_seen = false
local range_three_seen = false
local behind_wall_seen = false

-- Sample each second so a later cure cannot erase evidence of acquisition.
for _ = 1, OBSERVATION_SECONDS do
    t.run_seconds(1)
    diagonal_seen = diagonal_seen or has_rhinovirus(diagonal)
    range_three_seen = range_three_seen or has_rhinovirus(range_three)
    behind_wall_seen = behind_wall_seen or has_rhinovirus(behind_wall)
end

assert(
    diagonal_seen,
    "the unmasked source eventually infects the diagonal-two subject under seed 0"
)
assert(not range_three_seen, "a subject three tiles away remains clear")
assert(not behind_wall_seen, "a full wall column separates the other room")

-- The same coordinates on another declared level remain outside the
-- player-visible exposure path; native LOS also participates in that rule.
local LEVEL_MAP = [==[(
    name: "stacked ward",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [ "#####", "#...#", "#...#", "#...#", "#####" ],
            structures: [(2, 2, "player_spawn", { "jobs": "medic" })],
            items: [(2, 2, "syringe"), (2, 2, "bottle.rhinovirus_culture")],
        ),
        (
            rows: [ "#####", "#...#", "#...#", "#...#", "#####" ],
            structures: [(2, 2, "player_spawn", { "jobs": "assistant" })],
        ),
    ],
)]==]

t.world(LEVEL_MAP, SEED)
local level_source = t.join("medic")
local other_level = t.join("assistant")
t.run_ticks(3)

local source_x, source_y = t.pos(level_source)
local target_x, target_y = t.pos(other_level)
assert(source_x == 2 and source_y == 2, "the source uses its level-zero marker")
assert(target_x == 2 and target_y == 2, "the target shares coordinates on level one")
assert(t.worn(level_source).mask == "breath_mask", "the second source starts masked")
assert(t.worn(other_level).mask == "breath_mask", "the second target starts masked")

illness_actions.take(level_source, 2, 2, "syringe")
local level_culture = assert(
    t.target_at(level_source, 2, 2, "bottle.rhinovirus_culture"),
    "the second culture bottle is on the source tile"
)
illness_actions.draw_from_vessel(level_source, 2, 2, level_culture)
local after_level_flip = latest_ledger_sequence()
illness_actions.flip_syringe(level_source)
assert(has_syringe_mode_receipt_after(after_level_flip, 1), "the syringe is set to inject")
illness_actions.inject_into_body(level_source, level_source)
assert(has_rhinovirus(level_source), "the second source is inoculated while masked")

unmask(other_level, "other-level target")
unmask(level_source, "second source")

local other_level_seen = has_rhinovirus(other_level)
local source_lost_illness = not has_rhinovirus(level_source)
for _ = 1, OBSERVATION_SECONDS do
    t.run_seconds(1)
    other_level_seen = other_level_seen or has_rhinovirus(other_level)
    source_lost_illness = source_lost_illness or not has_rhinovirus(level_source)
end

assert(not source_lost_illness, "the source carries rhinovirus through the level observation")
assert(not other_level_seen, "same coordinates on another level remain clear while unmasked")
