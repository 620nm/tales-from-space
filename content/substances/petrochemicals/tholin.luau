-- Tholin: the brown tar HCN polymerises into, and a cold world's dust.
--
-- interactions we know exist but don't need:
--   tholin made in the air by ultraviolet light on N2 and CH4: the
--     world has no insolation and no airborne particles, so tholin comes
--     only from the bench, by polymerising liquid HCN
--
-- Tholin is not a molecule: it is a family of nitrogen-rich polymers, so
-- every figure here is a stated convention (docs/CHEMISTRY.md, D2).
-- `molar_mass` is 108.10, the (HCN)4 unit, so polymerisation balances
-- as 4 HCN -> 1 tholin with no mass made or lost. `cv` is the pack's
-- flat 100 and density 1.0 g/mL. An unmodelled solid, because no
-- temperature the bench reaches melts or boils a cross-linked tar.
-- Its colour is the red-brown of laboratory tholin films.
return {
    id = "tholin",
    name = "tholin",
    molar_mass = 108.10,
    cv = 100.0,
    phase = { unmodeled = "solid" },
    density = { solid = 1.0 },
    color = "#8A4B22",
    appearance = {
        solid = { profile = "powder", tint = "#8A4B22" },
    },
    -- Where this sits in a tool that offers every substance there is
    -- (docs/MAP-PROPERTIES.md, the recipe panel): a product, not a fill.
    relevance = 5,
    group = "other",
    -- What a placard says about this substance alone
    -- (docs/chemistry/substances.md, `hazard`).
    -- No NFPA rating exists; rated as an organic tar: mildly harmful,
    -- burns when heated.
    hazard = { health = 1, fire = 2, instability = 0 },
}
