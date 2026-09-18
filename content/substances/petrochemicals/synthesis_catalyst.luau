-- Synthesis catalyst: a reusable liquid process aid for the compact
-- syngas-to-naphtha step. It is a gameplay abstraction of a catalyst bed,
-- kept separate from the polymer catalyst so the two temperatures and
-- process choices cannot cross-trigger.
return {
    id = "synthesis_catalyst",
    name = "synthesis catalyst",
    molar_mass = 98.0,
    cv = 100.0,
    phase = { unmodeled = "liquid" },
    density = { liquid = 1.1 },
    color = "#355C7D",
    group = "other",
    hazard = { health = 2, fire = 0, instability = 1 },
}
