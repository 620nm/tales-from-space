-- Ammonia: the bench's first real synthesis, and the way in to both
-- cleaner and laughing gas.
--
-- Real molar mass and real molar heat capacity, but INERT -- and this
-- is the sharpest case of D2's departure (docs/CHEMISTRY.md): ammonia
-- really boils at 239.8 K, so a phase curve would have every beaker of
-- it flash to gas the instant it was made. A bench chemical that
-- vanished on contact with a room is not a chemical, it is a bug with a
-- citation.
--
-- The sequel is `nh3.luau`, which IS the molecule, curve and all. This
-- file keeps tg's fiction so the recipes standing on it keep working;
-- roast a beaker of this past 700 K and reactions/ammonia_gas.luau turns
-- it into the real thing, as gas, which then leaves the vessel and
-- fills the room. Policy D3, docs/CHEMISTRY.md.
-- tg: /datum/reagent/ammonia (other_reagents.dm:1627).
return {
    id = "ammonia",
    name = "ammonia",
    molar_mass = 17.03,
    cv = 80.8,
    -- What it looks like through glass (tg: other_reagents.dm:1630).
    color = "#404030",
}
