-- Sodium: the other half of salt. Real molar mass and the real molar
-- heat capacity of the metal, which happens to sit near Dulong-Petit
-- anyway.
-- tg: /datum/reagent/sodium (other_reagents.dm:1132).
return {
    id = "sodium",
    name = "sodium",
    molar_mass = 22.99,
    cv = 28.2,
    phase = { unmodeled = "solid" },
    -- What it looks like through glass (tg: other_reagents.dm:1135 (COLOR_GRAY)).
    color = "#808080",
}
