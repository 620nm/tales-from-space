-- First aid, not surgery (tg operation_healing.dm): tend bruises and
-- burns. INVERTS tg's availability on purpose: tg requires the skin cut
-- or open (any_surgery_states_required = ALL_SURGERY_SKIN_STATES,
-- operation_healing.dm:31), whereas here it is offered only on INTACT
-- skin so it does not crowd the mid-operation window. One application per
-- click; the looping and the 5 + 0.07*loss curve are simplified to a flat
-- 5 (both deviations in docs/SURGERY.md §6.7).
--
-- AND A THIRD DEVIATION, which is this file's most consequential and is
-- now deliberate: nothing here stops it being used on a CORPSE, and it
-- heals a corpse's parts at full strength.
--
-- tg scales this operation's healing to a fifth on a dead patient
-- (`dead_multiplier = 0.2`, operation_healing.dm:190), because in tg
-- healing damage is how a corpse comes back and the multiplier is the
-- brake. Here it is not: life is the HEART
-- (content/items/organ_heart.luau), and dying stops it
-- (content/bodies/human.luau). Mending a corpse's bruises mends a
-- corpse's bruises. It clears the plan's `dead` line and leaves the
-- stopped heart exactly where death put it, so the body stays dead
-- until a new heart is seated or a defibrillator restarts the old one
-- (content/items/defib.luau).
--
-- So the multiplier has nothing to brake, and porting it would only
-- make treating a body slower for no rule. Treating the parts is the
-- FIRST half of a revival either way, because a heart restarted under
-- a body still past the dead line revives it into a corpse
-- (tests/cadaver_revival_test.luau).

return {
    id = "tend_wounds", name = "tend the wounds",
    blocked = { "skin_cut", "skin_open" },
    ignore_clothes = true,
    heal = { brute = 5, burn = 5 },
    time = 2.5,
    implements = {
        { tool = "hemostat", mult = 1 },
        { tool = "cutters", mult = 1.67 },
        { tool = "screwdriver", mult = 1.5 },
    },
}
