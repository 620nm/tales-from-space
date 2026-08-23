-- First aid, not surgery (tg operation_healing.dm): tend bruises and
-- burns on intact skin. One application per click; the looping and the
-- 5 + 0.07*loss curve are simplified to a flat 5 (docs/SURGERY.md 6.7).
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
