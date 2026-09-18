-- Polymer resin is the solid binder made from one naphtha bookkeeping
-- unit. The unit keeps the feedstock mass unchanged while leaving room
-- for the pack's simple pellet and toner recipes.
return {
    id = "polymer_resin",
    name = "polymer resin",
    molar_mass = 112.22,
    cv = 100.0,
    phase = { unmodeled = "solid" },
    density = { solid = 1.05 },
    color = "#E5D1A6",
    group = "other",
    hazard = { health = 0, fire = 1, instability = 0 },
}
