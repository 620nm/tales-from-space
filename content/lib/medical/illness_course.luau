local illness_course = {}
local illnesses = require("@lib/medical/illnesses")

type IllnessDefinition = illnesses.IllnessDefinition
type RawInfectionRecord = {
    index: unknown,
    id: unknown,
    stage: unknown,
    half_stage: unknown,
    stage_peaked: unknown,
    peaked_cycles: unknown,
}

local RNG_PURPOSES = {
    "stage",
    "natural_recovery",
    "final_cure",
    "sneeze",
    "cough",
    "sore_throat",
    "mucus",
    "rest_lying",
    "rest_baseline",
}

type PurposeKeys = { [string]: string }
local RNG_KEYS: { [string]: PurposeKeys } = {}
for _, illness_id in ipairs(illnesses.IDS) do
    local purposes: PurposeKeys = {}
    for _, purpose in ipairs(RNG_PURPOSES) do
        purposes[purpose] = "illness:" .. illness_id .. ":" .. purpose
    end
    RNG_KEYS[illness_id] = purposes
end

export type InfectionRecord = {
    id: string,
    index: number,
    stage: number,
    half_stage: boolean,
    stage_peaked: boolean,
    peaked_cycles: number,
}

export type ProgressResult = {
    cured: boolean,
    resistance: boolean,
}

local function percentage(value: number): number
    return math.max(0, math.min(100, value))
end

local function valid_number(value: unknown): boolean
    return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function illness_course.copy_records(raw: any): { InfectionRecord }
    local records: { InfectionRecord } = {}
    local seen: { [number]: boolean } = {}
    if typeof(raw) ~= "table" then
        return records
    end

    for _, raw_value in ipairs(raw) do
        if typeof(raw_value) == "table" then
            -- The named view keeps stored values unknown until validated below.
            local row = raw_value :: RawInfectionRecord
            local index = row.index
            if typeof(index) == "number"
                and valid_number(index)
                and index % 1 == 0
                and not seen[index]
            then
                local definition = illnesses.get(index)
                if definition ~= nil then
                    local id = row.id
                    local stage = row.stage
                    local half_stage = row.half_stage
                    local stage_peaked = row.stage_peaked
                    local peaked_cycles = row.peaked_cycles
                    if id == definition.id
                        and typeof(stage) == "number"
                        and valid_number(stage)
                        and stage % 1 == 0
                        and stage >= 1
                        and stage <= definition.max_stages
                        and typeof(half_stage) == "boolean"
                        and typeof(stage_peaked) == "boolean"
                        and typeof(peaked_cycles) == "number"
                        and valid_number(peaked_cycles)
                        and peaked_cycles >= 0
                    then
                        seen[index] = true
                        table.insert(records, {
                            id = definition.id,
                            index = definition.index,
                            stage = stage,
                            half_stage = half_stage,
                            stage_peaked = stage_peaked,
                            peaked_cycles = peaked_cycles,
                        })
                    end
                end
            end
        end
    end

    table.sort(records, function(left: InfectionRecord, right: InfectionRecord): boolean
        return left.index < right.index
    end)
    return records
end

function illness_course.canonical_indices(indices: { number }): { number }
    local seen: { [number]: boolean } = {}
    local canonical: { number } = {}
    for _, index in ipairs(indices) do
        if valid_number(index) and index >= 0 and index % 1 == 0 and illnesses.get(index) ~= nil then
            if not seen[index] then
                seen[index] = true
                table.insert(canonical, index)
            end
        end
    end
    table.sort(canonical)
    return canonical
end

local function keyed_roll(body: Handle, illness_id: string, purpose: string): number?
    local purposes = RNG_KEYS[illness_id]
    if purposes == nil then
        return nil
    end
    local key = purposes[purpose]
    if key == nil then
        return nil
    end
    return sim.random_for(key, body)
end

function illness_course.spt(
    body: Handle,
    illness_id: string,
    purpose: string,
    chance_per_second: number,
    elapsed_seconds: number
): boolean
    if elapsed_seconds <= 0 or chance_per_second <= 0 then
        return false
    end
    if chance_per_second >= 100 then
        return true
    end

    local chance = 1 - math.pow(1 - chance_per_second / 100, elapsed_seconds)
    local roll = keyed_roll(body, illness_id, purpose)
    return roll ~= nil and roll < chance
end

function illness_course.prob(
    body: Handle,
    illness_id: string,
    purpose: string,
    chance: number
): boolean
    local bounded = percentage(chance)
    if bounded <= 0 then
        return false
    end
    if bounded >= 100 then
        return true
    end
    local roll = keyed_roll(body, illness_id, purpose)
    return roll ~= nil and roll < bounded / 100
end

-- tg: code/datums/diseases/_disease.dm:157-165,189-192,244-263.
function illness_course.progress(
    body: Handle,
    definition: IllnessDefinition,
    infection: InfectionRecord,
    elapsed_seconds: number
): ProgressResult
    if infection.stage == definition.max_stages and not infection.stage_peaked then
        infection.stage_peaked = true
    end

    if illness_course.spt(
        body,
        definition.id,
        "stage",
        definition.stage_probability * 2,
        elapsed_seconds
    ) then
        if infection.half_stage then
            infection.half_stage = false
            infection.stage = math.min(infection.stage + 1, definition.max_stages)
            if infection.stage == definition.max_stages then
                infection.stage_peaked = true
            end
        elseif infection.stage <= definition.max_stages then
            infection.half_stage = true
        end
    end

    local recovery = definition.natural_recovery
    infection.peaked_cycles += infection.stage / definition.max_stages

    local cycle_span = recovery.nonthreat_cycles / recovery.recovery_scaling
    local recovery_chance = recovery.recovery_constant
    if cycle_span > 0 then
        recovery_chance += infection.peaked_cycles / cycle_span
    end
    if infection.stage_peaked then
        recovery_chance *= recovery.peaked_recovery_multiplier
    end
    recovery_chance = percentage(recovery_chance)

    if illness_course.spt(body, definition.id, "natural_recovery", recovery_chance, elapsed_seconds) then
        if infection.stage == 1
            and illness_course.prob(
                body,
                definition.id,
                "final_cure",
                definition.cure_chance * recovery.final_cure_chance_multiplier
            )
        then
            return { cured = true, resistance = true }
        end
        infection.stage = math.max(infection.stage - 1, 1)
    end

    return { cured = false, resistance = false }
end

local function send_felt_message(body: Handle, key: string): ()
    sim.message.send({
        recipient = body,
        message = sim.msg("lunatic/tfs:lib.illness." .. key, {}),
    })
end

local function public_symptom(
    body: Handle,
    definition: IllnessDefinition,
    infection: InfectionRecord,
    symptom: string,
    elapsed_seconds: number
): ()
    if not illness_course.spt(
        body,
        infection.id,
        symptom,
        definition.symptom_probability,
        elapsed_seconds
    ) then
        return
    end
    local tile_ok, tile = pcall(function()
        return body.tile
    end)
    if not tile_ok or tile == nil then
        return
    end
    local name = body.name or body.prototype or "?"
    sim.message.broadcast({
        at = tile,
        radius = 7,
        message = sim.msg("lunatic/tfs:lib.illness." .. symptom, { name = name }),
    })
    sim.sound.play({ sound = symptom, at = tile })
end

local function private_symptom(
    body: Handle,
    definition: IllnessDefinition,
    infection: InfectionRecord,
    symptom: string,
    elapsed_seconds: number
): ()
    if illness_course.spt(
        body,
        infection.id,
        symptom,
        definition.symptom_probability,
        elapsed_seconds
    ) then
        send_felt_message(body, symptom)
    end
end

local function show_symptoms(
    body: Handle,
    definition: IllnessDefinition,
    infection: InfectionRecord,
    elapsed_seconds: number
): ()
    if infection.stage ~= 2 and infection.stage ~= 3 then
        return
    end
    public_symptom(body, definition, infection, "sneeze", elapsed_seconds)
    public_symptom(body, definition, infection, "cough", elapsed_seconds)
    private_symptom(body, definition, infection, "sore_throat", elapsed_seconds)
    private_symptom(body, definition, infection, "mucus", elapsed_seconds)
end

local function rest_cures(
    body: Handle,
    infection: InfectionRecord,
    definition: IllnessDefinition,
    state: any,
    elapsed_seconds: number
): boolean
    if infection.stage ~= 2 and infection.stage ~= 3 then
        return false
    end

    local lying_chance: number
    local other_chance: number
    if infection.stage == 2 then
        lying_chance = definition.rest_cure.stage_two_lying_per_second
        other_chance = definition.rest_cure.stage_two_other_per_second
    else
        lying_chance = definition.rest_cure.stage_three_lying_per_second
        other_chance = definition.rest_cure.stage_three_other_per_second
    end

    local lying_cure = state.posture == "lying"
        and illness_course.spt(body, infection.id, "rest_lying", lying_chance, elapsed_seconds)
    local baseline_cure = illness_course.spt(body, infection.id, "rest_baseline", other_chance, elapsed_seconds)
    return lying_cure or baseline_cure
end

-- tg: code/datums/diseases/cold.dm:20-56.
function illness_course.tick(
    body: Handle,
    definition: IllnessDefinition,
    infection: InfectionRecord,
    state: any,
    elapsed_seconds: number
): ProgressResult
    local result = illness_course.progress(body, definition, infection, elapsed_seconds)
    if result.cured then
        return result
    end

    show_symptoms(body, definition, infection, elapsed_seconds)
    if rest_cures(body, infection, definition, state, elapsed_seconds) then
        send_felt_message(body, "feels_better")
        return { cured = true, resistance = true }
    end
    return result
end

return illness_course
