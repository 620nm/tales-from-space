-- Wax is the solid flow aid in the toner blend. It shares naphtha's
-- bookkeeping mass so the lab can choose resin or wax without a hidden
-- mass conversion.
return {
    id = "wax",
    name = "wax",
    molar_mass = 112.22,
    cv = 100.0,
    phase = { unmodeled = "solid" },
    density = { solid = 0.9 },
    color = "#F4E8B8",
    group = "other",
    hazard = { health = 0, fire = 1, instability = 0 },
}
