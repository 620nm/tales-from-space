-- Toner is a composite powder: four resin units, one carbon-black unit
-- and one wax unit. Its 573.11 g/mol bookkeeping mass is the weighted
-- sum of those inputs, not a claim that toner is one molecule.
return {
    id = "toner",
    name = "printer toner",
    molar_mass = 573.11,
    cv = 100.0,
    phase = { unmodeled = "solid" },
    density = { solid = 1.1 },
    color = "#181818",
    group = "other",
    hazard = { health = 1, fire = 1, instability = 0 },
}
