-- Hepatectomy (tg operation_organ_repair.dm:111-159): the liver to 10 %,
-- +15 % on failure.
return {
    id = "repair_liver", name = "remove the damaged section",
    organ = "repair", organ_tag = "liver",
    requires = { "skin_open", "organs_cut" },
    organ_heal = { to_fraction = 0.1 }, organ_damage = { fraction = 0.15 },
    time = 5.2,
    implements = {
        { tool = "scalpel", mult = 1.05 },
        { item = "shard", mult = 2.85 },
    },
}
