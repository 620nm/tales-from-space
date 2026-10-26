local composition = require("@helpers/composition")
local illness_actions = require("@helpers/illness_actions")

local SEED = 3
local COLD = 0
local O_MINUS = 0
local A_PLUS = 3
local WAIT_LIMIT_SECONDS = 240

-- This is a player-action proof. The water route is deliberately a water
-- and culture-blood mixture; it does not claim to make a blood-free specimen.
-- Keep the jobs' default breath masks; the distant drinker is remote from the ward.
t.world(
    [==[(
    name: "rhinovirus ward",
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "##################",
                "#................#",
                "#................#",
                "#................#",
                "#................#",
                "##################",
            ],
            structures: [
                (2, 1, "player_spawn", { "jobs": "medic" }),
                (9, 1, "player_spawn", { "jobs": "assistant" }),
                (3, 1, "player_spawn", { "jobs": "engineer" }),
                (16, 1, "player_spawn", { "jobs": "captain" }),
            ],
            items: [
                (2, 2, "syringe"),
                (3, 2, "bottle.rhinovirus_culture"),
                (4, 2, "bottle.rhinovirus_culture"),
                (5, 2, "bottle.rhinovirus_culture"),
                (6, 2, "health_analyzer"),
                (10, 2, "beaker.water"),
            ],
        ),
    ],
)]==],
    SEED
)

local medic = t.join("medic")
local incompatible = t.join("assistant")
local donor = t.join("engineer")
local water_drinker = t.join("captain")
t.run_ticks(3)
t.run_seconds(3)

local function go(player: number, x: number, y: number): ()
    local px, py = t.pos(player)
    local function move_x(): ()
        while px < x do
            t.move(player, "east")
            t.run_ticks(5)
            px += 1
        end
        while px > x do
            t.move(player, "west")
            t.run_ticks(5)
            px -= 1
        end
    end
    local function move_y(): ()
        while py < y do
            t.move(player, "south")
            t.run_ticks(5)
            py += 1
        end
        while py > y do
            t.move(player, "north")
            t.run_ticks(5)
            py -= 1
        end
    end
    if py == 1 and (x ~= px or y > 1) then
        -- Leave the spawn row before crossing occupied player spawns.
        t.move(player, "south")
        t.run_ticks(5)
        py += 1
        move_x()
        move_y()
    else
        move_x()
        move_y()
    end
    local arrived_x, arrived_y = t.pos(player)
    assert(arrived_x == x and arrived_y == y, "the player reaches the requested tile")
end

local function says(messages: {string}, fragment: string): boolean
    for _, message in ipairs(messages) do
        if message:find(fragment, 1, true) ~= nil then
            return true
        end
    end
    return false
end

local function has_rider(target: number | SpecObservedTarget, id: string): boolean
    for _, row in ipairs(t.riders(target) or {}) do
        if row.id == id then
            return true
        end
    end
    return false
end

local function rider_number(target: number | SpecObservedTarget, id: string, key: string): number?
    for _, row in ipairs(t.riders(target) or {}) do
        if row.id == id then
            local value = row.fields[key]
            if type(value) == "number" then
                return value
            end
        end
    end
    return nil
end

local function body_illness(player: number): boolean
    return illness_actions.has_illness(t.body_target(player, player), COLD)
end

local function body_scan(scanner: number, subject: number): ()
    local x, y = t.pos(subject)
    t.click(scanner, x, y, t.body_target(scanner, subject))
    t.run_ticks(2)
end

local function item_scan(scanner: number, x: number, y: number, target: SpecObservedTarget): ()
    t.click(scanner, x, y, target)
    t.run_ticks(2)
end

local function self_scan(scanner: number): ()
    t.use_self(scanner)
    t.run_ticks(2)
end

local function take_nearby(actor: number, x: number, y: number, id: string): SpecObservedTarget
    return illness_actions.take(actor, x, y, id)
end

local function set_syringe(expected: "draw" | "inject"): ()
    t.messages(medic)
    illness_actions.flip_syringe(medic)
    local phrase = if expected == "draw" then "set the syringe to draw" else "set the syringe to inject"
    local messages = t.messages(medic)
    assert(says(messages, phrase), "the syringe dial matches the next gesture")
end

local function no_blood_identity(target: SpecObservedTarget, message: string): ()
    assert(not has_rider(target, "blood_identity"), message)
end

local medic_x, medic_y = t.pos(medic)
local incompatible_x, incompatible_y = t.pos(incompatible)
local donor_x, donor_y = t.pos(donor)
local drinker_x, drinker_y = t.pos(water_drinker)
assert(medic_x == 2 and medic_y == 1, "the medic starts at the middle spawn")
assert(incompatible_x == 9 and incompatible_y == 1, "the O- assistant starts remote from the infected donor")
assert(donor_x == 3 and donor_y == 1, "the engineer starts east of the medic")
assert(drinker_x == 16 and drinker_y == 1, "the water recipient starts remote from the ward")
assert(rider_number(t.body_target(medic, medic), "blood_identity", "type") == A_PLUS, "seed 3 gives the medic A+")
assert(rider_number(t.body_target(incompatible, incompatible), "blood_identity", "type") == O_MINUS, "seed 3 gives the recipient O-")
assert(rider_number(t.body_target(donor, donor), "blood_identity", "type") == A_PLUS, "seed 3 gives the donor A+")
assert(not body_illness(medic) and not body_illness(incompatible) and not body_illness(donor), "the three ward patients start without rhinovirus")

-- The culture starts with blood and a rhinovirus rider, but no blood type.
local culture1 = assert(t.target_at(medic, 3, 2, "bottle.rhinovirus_culture"), "the first culture bottle is visible")
assert((assert(t.contents(culture1)).blood or 0) > 0, "the culture bottle contains blood")
assert(illness_actions.has_illness(culture1, COLD), "the culture bottle carries The Cold")
no_blood_identity(culture1, "the culture blood is intentionally untyped")

local syringe = take_nearby(medic, 2, 2, "syringe")
illness_actions.draw_from_vessel(medic, 3, 2, culture1)
assert(illness_actions.has_illness(syringe, COLD), "a real draw carries rhinovirus into the syringe")
no_blood_identity(syringe, "the culture draw remains untyped")
set_syringe("inject")
local donor_toxin = t.blood(donor).toxin or 0
illness_actions.inject_into_body(medic, donor)
assert(body_illness(donor), "the culture injection infects the engineer")
assert((t.blood(donor).toxin or 0) <= donor_toxin + 1e-9, "untyped culture blood causes no compatibility toxin")
no_blood_identity(culture1, "drawing from the culture does not type its remaining blood")

-- The reporter proves both a staged body observation and a carried specimen.
go(medic, 6, 3)
take_nearby(medic, 6, 2, "health_analyzer")
go(medic, 3, 2)
local body_report = "Warning: Virus detected. Name: The Cold. Type: Airborne. Stage: 1/3. Cure: Rest."
t.messages(medic)
t.messages(donor)
body_scan(medic, donor)
local body_messages = t.messages(medic)
local donor_messages = t.messages(donor)
assert(says(body_messages, body_report), "the analyzer reports The Cold at stage 1/3")
assert(not says(donor_messages, body_report), "the body report is private to the scanner")
assert(body_illness(donor), "the analyzer observation agrees with the bloodstream rider")

local culture2 = assert(t.target_at(medic, 4, 2, "bottle.rhinovirus_culture"), "a second culture bottle is visible")
local vessel_report = "Warning: Virus detected. Name: The Cold. Type: Airborne. Stage: Carried in fluid. Host cure: Rest."
go(medic, 4, 3)
t.messages(medic)
local donor_vessel_x, donor_vessel_y = t.pos(donor)
assert(donor_vessel_x == 3 and donor_vessel_y == 1, "the nearby donor remains at the ward")
t.messages(donor)
t.messages(water_drinker)
item_scan(medic, 4, 2, culture2)
local vessel_messages = t.messages(medic)
local donor_vessel_messages = t.messages(donor)
local drinker_vessel_messages = t.messages(water_drinker)
assert(says(vessel_messages, vessel_report), "the analyzer reports rhinovirus in an accessible vessel")
assert(
    not says(donor_vessel_messages, vessel_report),
    "the nearby donor does not receive the private vessel report"
)
assert(not says(drinker_vessel_messages, vessel_report), "the vessel report is private to the scanner")

-- Observe progression while the donor is still nearby and standing; the
-- later transfer legs do not depend on catching a symptom after it has passed.
go(medic, 3, 2)
assert(assert(t.body(donor)).posture == "standing", "the infected donor remains standing")
t.messages(medic)
local saw_stage_two = false
local saw_sneeze = false
local saw_cough = false
for _ = 1, WAIT_LIMIT_SECONDS do
    t.run_seconds(1)
    body_scan(medic, donor)
    local messages = t.messages(medic)
    if says(messages, "Stage: 2/3.") then
        saw_stage_two = true
    end
    if says(messages, "sneezes.") then
        saw_sneeze = true
    end
    if says(messages, "coughs!") then
        saw_cough = true
    end
    if saw_stage_two and saw_sneeze and saw_cough then
        break
    end
end
assert(saw_stage_two, "the standing infection progresses to stage 2")
assert(saw_sneeze, "a nearby player receives the seeded sneeze message")
assert(saw_cough, "a nearby player receives the seeded cough message")
assert(body_illness(donor), "the donor remains infected for the transfusion route")

-- Draw infected A+ blood into the syringe, then prove the compatible and
-- incompatible recipients each acquire the illness rider.
assert(not body_illness(medic), "the mask keeps the medic clear before the blood route")
go(medic, 6, 2)
syringe = take_nearby(medic, 6, 3, "syringe")
set_syringe("draw")
go(medic, 2, 1)
illness_actions.draw_from_body(medic, donor)
assert(illness_actions.has_illness(syringe, COLD), "blood drawn from the infected donor retains rhinovirus")
assert(rider_number(syringe, "blood_identity", "type") == A_PLUS, "the infected donor's drawn blood remains A+")
set_syringe("inject")
local medic_toxin = t.blood(medic).toxin or 0
illness_actions.inject_into_body(medic, medic)
assert(body_illness(medic), "compatible infected A+ blood infects the A+ medic")
assert((t.blood(medic).toxin or 0) <= medic_toxin + 1e-9, "compatible infected blood causes no toxin")

set_syringe("draw")
illness_actions.draw_from_body(medic, donor)
set_syringe("inject")
local incompatible_toxin = t.blood(incompatible).toxin or 0
assert(not body_illness(incompatible), "the remote O- recipient is healthy before transfusion")
go(medic, 8, 1)
illness_actions.inject_into_body(medic, incompatible)
assert(body_illness(incompatible), "incompatible infected blood still infects the O- recipient")
assert(rider_number(t.body_target(incompatible, incompatible), "blood_identity", "type") == O_MINUS, "the incompatible host keeps its O- type")
assert((t.blood(incompatible).toxin or 0) > incompatible_toxin + 0.001, "the incompatible transfusion also causes toxin")

-- Lying recovery clears the bloodstream rider and is visible to the analyzer.
assert(body_illness(medic), "the medic has an active infection before resting")
go(medic, 6, 3)
take_nearby(medic, 6, 2, "health_analyzer")
t.rest(medic, true)
t.run_ticks(2)
assert(assert(t.body(medic)).posture == "lying", "the medic is lying down during the cure leg")
local cured = false
for _ = 1, WAIT_LIMIT_SECONDS do
    t.run_seconds(1)
    if not body_illness(medic) then
        cured = true
        break
    end
end
assert(cured, "lying rest eventually clears the active illness")
t.messages(medic)
self_scan(medic)
local cure_messages = t.messages(medic)
assert(says(cure_messages, "No pathogens detected."), "the analyzer confirms the cured body is clear")
assert(not body_illness(medic), "the illness rider clears with the cure")
t.rest(medic, false)
t.run_ticks(2)
assert(assert(t.body(medic)).posture == "standing", "the medic gets up before reinoculation")

-- Re-exposure through the same culture is rejected by the acquired resistance.
go(medic, 6, 2)
syringe = take_nearby(medic, 6, 3, "syringe")
local culture3 = assert(t.target_at(medic, 5, 2, "bottle.rhinovirus_culture"), "the third culture bottle is visible")
set_syringe("draw")
illness_actions.draw_from_vessel(medic, 5, 2, culture3)
set_syringe("inject")
go(medic, 2, 1)
local post_cure_toxin = t.blood(medic).toxin or 0
illness_actions.inject_into_body(medic, medic)
assert(not body_illness(medic), "the cured medic resists culture reinoculation")
assert((t.blood(medic).toxin or 0) <= post_cure_toxin + 1e-9, "the resisted exposure has no toxin effect")
go(medic, 6, 3)
take_nearby(medic, 6, 2, "health_analyzer")
t.messages(medic)
self_scan(medic)
local reinoculation_messages = t.messages(medic)
assert(says(reinoculation_messages, "No pathogens detected."), "the analyzer confirms reinoculation stayed clear")

-- Mix real culture into water, inspect that accessible vessel, then have a
-- distinct healthy player drink the water-and-blood mixture.
go(medic, 4, 3)
take_nearby(medic, 4, 2, "bottle.rhinovirus_culture")
go(medic, 10, 3)
local water = assert(t.target_at(medic, 10, 2, "beaker.water"), "the water beaker is visible")
t.click(medic, 10, 2, water)
t.run_ticks(2)
local mixture = assert(t.contents(water), "the beaker contents are observable")
assert((mixture.water or 0) > 0, "the contaminated vessel still contains water")
assert((mixture.blood or 0) > 0, "the tested vessel honestly contains culture blood too")
assert(illness_actions.has_illness(water, COLD), "the water-and-blood mixture retains rhinovirus")

go(medic, 4, 2)
take_nearby(medic, 4, 3, "health_analyzer")
go(medic, 9, 3)
local water_donor_x, water_donor_y = t.pos(donor)
assert(water_donor_x == 3 and water_donor_y == 1, "the donor remains within range of the water scan")
t.messages(medic)
t.messages(donor)
t.messages(water_drinker)
item_scan(medic, 10, 2, water)
local water_messages = t.messages(medic)
local water_donor_messages = t.messages(donor)
local water_drinker_messages = t.messages(water_drinker)
assert(says(water_messages, vessel_report), "the analyzer reports rhinovirus in the accessible water mixture")
assert(
    not says(water_donor_messages, vessel_report),
    "the nearby donor does not receive the private water report"
)
assert(not says(water_drinker_messages, vessel_report), "the water specimen report remains private")

go(medic, 10, 3)
take_nearby(medic, 10, 2, "beaker.water")
go(medic, 16, 4)
t.drop(medic)
t.tick()
assert(not body_illness(water_drinker), "the remote water recipient is healthy before drinking")
go(water_drinker, 16, 3)
local drank_before = #t.ledger_rows("drank")
take_nearby(water_drinker, 16, 4, "beaker.water")
composition.click_deck(water_drinker, 16, 3)
t.run_ticks(2)
assert(#t.ledger_rows("drank") == drank_before + 1, "the player performs one real drink action")
assert(body_illness(water_drinker), "drinking the contaminated water mixture infects a distinct host")
assert(not body_illness(medic), "the resistant medic remains healthy during the water route")
