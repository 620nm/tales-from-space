-- Coronary bypass (tg operation_organ_repair.dm:176-224): the heart back
-- to 60 % on success, +20 % damage on failure.
return {
    id = "repair_heart", name = "graft a coronary bypass",
    organ = "repair", organ_tag = "heart",
    requires = { "skin_open", "organs_cut" },
    organ_heal = { to_fraction = 0.6 }, organ_damage = { fraction = 0.2 },
    time = 9,
    implements = {
        { tool = "hemostat", mult = 1.05 },
        { tool = "cutters", mult = 2.85 },
    },
}
