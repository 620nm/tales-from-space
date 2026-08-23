-- Neurosurgery (tg operation_organ_repair.dm:460-522). tg heals the
-- brain by 25 % of its max; here it is modelled as setting the damage to
-- that fraction (docs/SURGERY.md 6.7). The brain socket needs the bone
-- sawed, which it enforces on its own.
return {
    id = "repair_brain", name = "perform neurosurgery",
    organ = "repair", organ_tag = "brain",
    requires = { "skin_open" },
    organ_heal = { to_fraction = 0.25 }, organ_damage = { fraction = 0.3 },
    time = 10,
    implements = {
        { tool = "hemostat", mult = 1.05 },
        { tool = "screwdriver", mult = 2.85 },
    },
}
