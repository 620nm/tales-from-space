local physical_profiles = require("@lib/physical_profiles")
-- One of the seven parts a human plan names (docs/BIOLOGY.md §1.1).
-- A part is an ITEM, so it is held, dropped, stored, thrown and
-- examined by every path an item has, and a dismembered limb is simply
-- this thing leaving its slot.
--
-- max_damage LIMB_MAX_HP_CORE 200 and body_damage_coeff
-- LIMB_BODY_DAMAGE_COEFFICIENT_TOTAL 1
-- (code/modules/surgery/bodyparts/default_parts.dm:6,
-- code/__DEFINES/bodyparts.dm:11,25); the chest is the one part
-- whose surgical bleeding is unscaled
-- (code/modules/surgery/bodyparts/_bodyparts.dm:1641-1644).
return {
    id = "human_chest",
    visual_layer = "item",
    motion_response = physical_profiles.loose_item1kg,
    name_label = "lunatic/tfs:entity.human_chest.name",
    name = "chest",
    sprite = "part_chest",
    part = {
        max = 200,
        coeff = 1,
        bleed_scale = 1,
        tags = { "torso", "flesh" },
        -- Flesh never disables by damage in tg: LIMB_NO_DISABLE
        -- (code/__DEFINES/bodyparts.dm:71) means a mangled arm is still
        -- an arm right up to the moment it comes off. A cybernetic one
        -- would name a falling curve here instead.
        efficiency = { { 0, 1 }, { 1, 1 } },
        pool_mod = { brute = 1, burn = 1 },
        -- Circulation belongs to the part that physically hosts it. tg's
        -- carbon bloodstream is carried with the torso organs and losing
        -- bodyparts routes through their owner
        -- (code/modules/surgery/bodyparts/_bodyparts.dm:947-969).
        --
        -- Blood is MOLES of the `blood` substance held in this part's own
        -- bloodstream, so a dose, a rider and a bleed all act on the same
        -- mixture. A tg blood unit is a centilitre and 0.025 mol
        -- (docs/chemistry/tg-bridge.md): every figure below is the cited
        -- tg number x 0.025. Native code only bleeds it; filling it back
        -- up and what running low costs are `lib/blood_harmony.luau`.
        blood = {
            substance = "blood",
            -- BLOOD_VOLUME_NORMAL 560 u (code/__DEFINES/mobs.dm:20): 5.5 L.
            normal = 13.75,
            -- BLOOD_VOLUME_SURVIVE 112 u (code/__DEFINES/mobs.dm:25).
            dead_below = 2.8,
            -- generic_bleedstacks 0.5 u/s a stack
            -- (code/modules/surgery/bodyparts/_bodyparts.dm:1626-1627).
            stack_bleed_per_s = 0.0125,
        },
        bloodstream = {
            -- The shell holds a little more than normal blood, so a dose
            -- fits beside it: 6 L = 0.006 m3 against 5.5 L of blood
            -- (BLOOD_VOLUME_NORMAL 560 u read as centilitres,
            -- code/__DEFINES/mobs.dm:20).
            volume_m3 = 0.006,
            -- BODYTEMP_NORMAL (code/__DEFINES/atmospherics/
            -- atmos_mob_interaction.dm:53).
            temperature_k = 310.15,
        },
    },
}
