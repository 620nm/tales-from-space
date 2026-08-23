-- Lobectomy (tg operation_organ_repair.dm:47-95): the lung to 60 %,
-- +10 % on failure.
return {
    id = "repair_lungs", name = "excise the damaged lobe",
    organ = "repair", organ_tag = "lung",
    requires = { "skin_open", "organs_cut" },
    organ_heal = { to_fraction = 0.6 }, organ_damage = { fraction = 0.1 },
    time = 4.2,
    implements = {
        { tool = "scalpel", mult = 1.05 },
        { item = "shard", mult = 2.85 },
    },
}
