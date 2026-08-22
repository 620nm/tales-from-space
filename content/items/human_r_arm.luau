-- One of the six limbs a human plan names (docs/BIOLOGY.md §1.1).
-- A part is an ITEM, so it is held, dropped, stored, thrown and
-- examined by every path an item has, and a dismembered limb is simply
-- this thing leaving its slot.
--
-- As the left arm (default_parts.dm:123-125, _bodyparts.dm:1643-1644).
return {
    id = "human_r_arm",
    name = "right arm",
    sprite = "part_r_arm",
    part = {
        max = 50,
        coeff = 0.75,
        bleed_scale = 0.25,
        tags = { "arm", "flesh" },
        -- Flesh never disables by damage in tg: LIMB_NO_DISABLE
        -- (code/__DEFINES/bodyparts.dm:71) means a mangled arm is still
        -- an arm right up to the moment it comes off. A cybernetic one
        -- would name a falling curve here instead.
        efficiency = {{0, 1}, {1, 1}},
        brute_mod = 1,
        burn_mod = 1,
    },
}
