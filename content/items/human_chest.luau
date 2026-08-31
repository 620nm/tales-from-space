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
        efficiency = {{0, 1}, {1, 1}},
        pool_mod = { brute = 1, burn = 1 },
        -- Circulation belongs to the part that physically hosts it. tg's
        -- carbon bloodstream is carried with the torso organs and losing
        -- bodyparts routes through their owner
        -- (code/modules/surgery/bodyparts/_bodyparts.dm:947-969).
        blood = {
            normal = 560,            -- BLOOD_VOLUME_NORMAL, code/__DEFINES/mobs.dm:20
            dead_below = 112,        -- BLOOD_VOLUME_SURVIVE, code/__DEFINES/mobs.dm:25
            regen_per_s = 0.25,      -- BLOOD_REGEN_FACTOR, code/__DEFINES/mobs.dm:28
            oxy_per_missing = 0.01,  -- code/modules/mob/living/blood.dm:256-262
        },
        bloodstream = {
            -- The dissolved-matter holder is the same body of blood the
            -- `blood` block counts, so it holds the same amount rather
            -- than a round number beside it: BLOOD_VOLUME_NORMAL 560,
            -- read as centilitres, is 5.6 L = 0.0056 m³
            -- (#define BLOOD_VOLUME_NORMAL 560,
            -- code/__DEFINES/mobs.dm:20). The 0.005 it replaces was an
            -- uncited five litres.
            volume_m3 = 0.0056,
            -- BODYTEMP_NORMAL (code/__DEFINES/atmospherics/
            -- atmos_mob_interaction.dm:53).
            temperature_k = 310.15,
        },
    },
}
