-- Sulfur: the yellow solid with the reputation. A dispenser button and
-- a leg tg spends on sulphuric acid and on the plant chems; nothing in
-- this pack's roster names it yet.
--
-- Real molar mass and the real molar heat capacity (S, 22.8
-- J/(mol*K)), with an authored `unmodeled` rest phase per D2
-- (docs/CHEMISTRY.md): sulfur melts at 388 K, which the reaction
-- chamber reaches easily -- but molten sulfur is a phase no rule here
-- reads, and a transition with no consequence is sweep time spent on
-- nothing.
-- tg: /datum/reagent/sulfur (other_reagents.dm:1062).
return {
    id = "sulfur",
    name = "sulfur",
    molar_mass = 32.06,
    cv = 22.8,
    phase = { unmodeled = "solid" },
    -- Real rhombic sulfur, 2.07 g/mL.
    density = { solid = 2.07 },
    -- What it looks like through glass (tg: other_reagents.dm:1065).
    color = "#BF8C00",
}
