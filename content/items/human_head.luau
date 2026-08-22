-- One of the six limbs a human plan names (docs/BIOLOGY.md §1.1).
-- A part is an ITEM, so it is held, dropped, stored, thrown and
-- examined by every path an item has, and a dismembered limb is simply
-- this thing leaving its slot.
--
-- max_damage LIMB_MAX_HP_CORE 200
-- (code/modules/surgery/bodyparts/head.dm:6); a head bleeds at
-- half rate under the knife (_bodyparts.dm:1641-1642).
return {
    id = "human_head",
    name = "head",
    sprite = "part_head",
    part = {
        max = 200,
        coeff = 1,
        bleed_scale = 0.5,
        tags = { "head", "flesh" },
        -- Flesh never disables by damage in tg: LIMB_NO_DISABLE
        -- (code/__DEFINES/bodyparts.dm:71) means a mangled arm is still
        -- an arm right up to the moment it comes off. A cybernetic one
        -- would name a falling curve here instead.
        efficiency = {{0, 1}, {1, 1}},
        brute_mod = 1,
        burn_mod = 1,
    },
}
