-- One of the seven parts a human plan names (docs/BIOLOGY.md §1.1).
-- A part is an ITEM, so it is held, dropped, stored, thrown and
-- examined by every path an item has, and a dismembered limb is simply
-- this thing leaving its slot.
--
-- max_damage LIMB_MAX_HP_DEFAULT 50 and body_damage_coeff
-- LIMB_BODY_DAMAGE_COEFFICIENT_DEFAULT 0.75
-- (default_parts.dm:376-377).
return {
    id = "human_l_leg",
    name = "left leg",
    sprite = "part_l_leg",
    part = {
        max = 50,
        coeff = 0.75,
        bleed_scale = 0.25,
        tags = { "leg", "flesh" },
        -- Flesh never disables by damage in tg: LIMB_NO_DISABLE
        -- (code/__DEFINES/bodyparts.dm:71) means a mangled arm is still
        -- an arm right up to the moment it comes off. A cybernetic one
        -- would name a falling curve here instead.
        efficiency = {{0, 1}, {1, 1}},
        pool_mod = { brute = 1, burn = 1 },
    },
}
