-- Hydrogen: H2, the molecule.
--
-- ONE ID PER MOLECULE. tg's `hydrogen` REAGENT is a single atom -- its
-- ammonia recipe takes 3 parts hydrogen to 1 nitrogen, which is H3N
-- and not 3 H2 + N2 -- and its `/datum/gas/hydrogen` is the diatomic
-- gas the atmos column knows. Those were one fiction and one fact
-- wearing the same word; this file is the fact, and the recipe that
-- stood on the fiction was rewritten to the molecule's own ratio
-- (reactions/ammonia.luau: 1.5 H2 to 0.5 N2).
--
-- Physics is tg's own gas datum, verbatim: `specific_heat = 15`,
-- `dangerous = TRUE` (gas_types.dm:229-232). Molar mass is H2's,
-- 2.016 g/mol.
--
-- `gas_only`: hydrogen boils at 20.3 K and freezes at 14 K, so a
-- condensation model for it would be a cryogenics system nothing on
-- this station has -- and a curve nothing can reach is a curve that
-- only ever misleads. It is a permanent gas here for the same reason
-- oxygen and nitrogen are (docs/CHEMISTRY.md 2).
--
-- WHERE A CHEMIST GETS IT: not from the dispenser. A permanent gas
-- comes off a canister through a connector port into a vessel with a
-- lid on it (D19), because a press over an open beaker would leave
-- through the mouth it came in by.
-- tg: /datum/gas/hydrogen (gas_types.dm:229), /datum/reagent/hydrogen
-- (other_reagents.dm:1028).
return {
    id = "hydrogen",
    name = "hydrogen",
    molar_mass = 2.016,
    cv = 15.0,
    phase = "gas_only",
    dangerous = true,
    -- What it looks like through glass (tg: other_reagents.dm:1031 (COLOR_GRAY)).
    color = "#808080",
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAP-PROPERTIES.md, the recipe panel). Reachable as room air, and
    -- rarely what a room is commissioned holding.
    relevance = 30,
    -- tg's `dangerous = TRUE` (gas_types.dm:233) -- a gas at every station
    -- temperature, so the flag decides between the two gas groups and it
    -- says poison.
    group = "poison",
}
