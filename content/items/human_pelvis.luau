-- One of the seven parts a human plan names (docs/BIOLOGY.md §1.1).
-- A part is an ITEM, so it is held, dropped, stored, thrown and
-- examined by every path an item has, and a dismembered limb is simply
-- this thing leaving its slot.
--
-- tg has no groin BODYPART: `BODY_ZONE_PRECISE_GROIN` is a precise zone
-- that `check_zone` folds straight into the chest
-- (code/modules/mob/mob_helpers.dm:10-28), so a groin hit there is a
-- chest hit wearing a different name. Here parts are real, and the
-- numbers below are the ones tg's own rules give a torso that is not
-- the chest.
--
-- max_damage LIMB_MAX_HP_CORE 200, whose comment reads "Only use this
-- for heads and torsos", and body_damage_coeff
-- LIMB_BODY_DAMAGE_COEFFICIENT_TOTAL 1, "Used by heads and torsos"
-- (code/__DEFINES/bodyparts.dm:11, :25).
return {
    id = "human_pelvis",
    name = "pelvis",
    -- The greyscale sheet has no groin cell -- tg's `human_chest_m`
    -- already draws the torso down to the legs, groin included -- so a
    -- severed pelvis borrows the torso's picture
    -- (assets/sprites/45-bodyparts-and-organs.ron).
    sprite = "part_pelvis",
    part = {
        max = 200,
        coeff = 1,
        -- ...but NOT the chest's unscaled surgical bleeding. tg halves
        -- it for the head and quarters it for every zone that is not
        -- the chest, which is what a pelvis is
        -- (code/modules/surgery/bodyparts/_bodyparts.dm:1640-1644).
        bleed_scale = 0.25,
        -- `torso` as the chest has it, because that is what it is; no
        -- capacity formula in content/bodies/human.luau reads the word,
        -- and `flesh` is the one every operation filters on.
        tags = { "torso", "flesh" },
        -- Flesh never disables by damage in tg: LIMB_NO_DISABLE
        -- (code/__DEFINES/bodyparts.dm:71) means a mangled arm is still
        -- an arm right up to the moment it comes off. A cybernetic one
        -- would name a falling curve here instead.
        efficiency = {{0, 1}, {1, 1}},
        pool_mod = { brute = 1, burn = 1 },
    },
}
