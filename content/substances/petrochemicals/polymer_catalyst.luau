-- Polymer catalyst: a reusable liquid catalyst for turning naphtha into
-- printer-grade resin. It is an authored process aid, not a claim that a
-- station beaker has isolated one industrial catalyst formulation.
return {
    id = "polymer_catalyst",
    name = "polymer catalyst",
    molar_mass = 120.0,
    cv = 100.0,
    phase = { unmodeled = "liquid" },
    density = { liquid = 1.2 },
    color = "#7A3E91",
    group = "other",
    hazard = { health = 2, fire = 0, instability = 1 },
}
