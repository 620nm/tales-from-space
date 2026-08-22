-- One of the six limbs a human plan names (docs/BIOLOGY.md §1.1).
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
        brute_mod = 1,
        burn_mod = 1,
    },
}
