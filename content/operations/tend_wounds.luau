-- First aid, not surgery (tg operation_healing.dm): tend bruises and
-- burns. INVERTS tg's availability on purpose: tg requires the skin cut
-- or open (any_surgery_states_required = ALL_SURGERY_SKIN_STATES,
-- operation_healing.dm:31), whereas here it is offered only on INTACT
-- skin so it does not crowd the mid-operation window. One application per
-- click; the looping and the 5 + 0.07*loss curve are simplified to a flat
-- 5 (both deviations in docs/SURGERY.md §6.7).
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
