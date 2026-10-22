local illnesses = {}

export type InactivationRule = {
    min_fractions: { [string]: number }?,
    contact_seconds: number?,
}

export type NaturalRecovery = {
    nonthreat_cycles: number,
    recovery_constant: number,
    recovery_scaling: number,
    peaked_recovery_multiplier: number,
    slowdown_recovery_bonus: number,
    slowdown_recovery_bonus_cycles: number,
    malnutrition_recovery_penalty: number,
    good_sleeping_recovery_bonus: number,
    sleeping_recovery_multiplier: number,
    final_cure_chance_multiplier: number,
    symptom_offset_cycles: number,
    symptom_frequency_modifier: number,
    symptom_immunity_recovery_bonus: number,
}

export type RestCure = {
    stage_two_lying_per_second: number,
    stage_two_other_per_second: number,
    stage_three_lying_per_second: number,
    stage_three_other_per_second: number,
}

export type IllnessDefinition = {
    id: string,
    index: number,
    name: string,
    agent: string,
    max_stages: number,
    required_organs: { string },
    infectivity: number,
    spreading_modifier: number,
    stage_probability: number,
    cure_chance: number,
    symptom_probability: number,
    natural_recovery: NaturalRecovery,
    rest_cure: RestCure,
    inactivation: InactivationRule?,
}

-- tg: code/datums/diseases/cold.dm:2-12,20-56; inherited values:
-- code/datums/diseases/_disease.dm:24-60.
local CATALOG: { IllnessDefinition } = {
    {
        id = "rhinovirus",
        index = 0,
        name = "The Cold",
        agent = "XY-rhinovirus",
        max_stages = 3,
        required_organs = { "lungs" },
        infectivity = 41,
        spreading_modifier = 0.5,
        stage_probability = 2,
        cure_chance = 4,
        symptom_probability = 0.5,
        rest_cure = {
            stage_two_lying_per_second = 23,
            stage_two_other_per_second = 0.025,
            stage_three_lying_per_second = 12.5,
            stage_three_other_per_second = 0.005,
        },
        -- code/__DEFINES/diseases.dm:60-112; copied as data for the
        -- supported host course to select its implemented recovery levers.
        natural_recovery = {
            nonthreat_cycles = 180,
            recovery_constant = 0,
            recovery_scaling = 2,
            peaked_recovery_multiplier = 1.2,
            slowdown_recovery_bonus = 2,
            slowdown_recovery_bonus_cycles = 120,
            malnutrition_recovery_penalty = 3,
            good_sleeping_recovery_bonus = 0.6,
            sleeping_recovery_multiplier = 6,
            final_cure_chance_multiplier = 6,
            symptom_offset_cycles = 200,
            symptom_frequency_modifier = 1,
            symptom_immunity_recovery_bonus = 1.5,
        },
    },
}

-- RefSet values are zero-based; Luau's catalog array remains one-based.
local IDS: { string } = { "rhinovirus" }
illnesses.IDS = IDS

function illnesses.index_of(id: string): number?
    for index, candidate in ipairs(IDS) do
        if candidate == id then
            return index - 1
        end
    end
    return nil
end

function illnesses.get(index: number): IllnessDefinition?
    if index ~= index or index < 0 or index % 1 ~= 0 then
        return nil
    end
    local definition = CATALOG[index + 1]
    if definition == nil or definition.index ~= index then
        return nil
    end
    return definition
end

return illnesses
