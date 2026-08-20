-- Ammonia: the bench's first real synthesis, and the way in to both
-- cleaner and laughing gas.
--
-- Real molar mass and real molar heat capacity, but INERT -- and this
-- is the sharpest case of D2's departure (docs/reagents.md): ammonia
-- really boils at 239.8 K, so a phase curve would have every beaker of
-- it flash to gas the instant it was made. A bench chemical that
-- vanished on contact with a room is not a chemical, it is a bug with a
-- citation.
-- tg: /datum/reagent/ammonia (other_reagents.dm:1627).
return {
    id = "ammonia",
    name = "ammonia",
    molar_mass = 17.03,
    cv = 80.8,
    -- What it looks like through glass (tg: other_reagents.dm:1630).
    color = "#404030",
}
