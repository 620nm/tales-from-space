-- Iodine: the shelf's one solid that will not stay one. A crystal left
-- out on the bench loses itself to a violet vapour without ever
-- melting, because at room temperature its sublimation line sits at a
-- few pascals and nothing holds it down (docs/MATTER.md 5).
--
-- Real iodine, NIST WebBook (I2, phase-change data): triple point
-- 386.75 K at 12.1 kPa, normal boiling point 457.4 K, enthalpy of
-- fusion 15.52 kJ/mol, enthalpy of vaporisation 41.57 kJ/mol. The
-- `boil` spelling is legal because P_vap at the melting point is far
-- under one atmosphere (D10); the registry derives the sublimation
-- line by Hess's law, L_sub = L_fus + L_vap, and never has it authored.
-- Solid 4.93 g/mL, liquid 3.96 g/mL at the melting point.
--
-- The vapour is the famous purple (through glass tg draws the solid
-- amber, other_reagents.dm:1998); `visible` is the same pair the
-- other clouds carry (chlorine.luau), tuned so a sealed bottle's few
-- micromoles of vapour stay clear and a spilt crystal's plume shows.
--
-- Not on the dispenser shelf (docs/CHEMISTRY.md 7): it arrives in a
-- bottle (items/bottle_iodine.luau). Off tg's `dangerous` roster, so
-- it draws no alarm; it does not cross into blood (no `inhale`).
return {
    id = "iodine",
    name = "iodine",
    molar_mass = 253.81,
    cv = { solid = 54.4, liquid = 80.7, gas = 36.9 },
    phase = { melt = 386.75, boil = 457.4, l_fus = 15520, l_vap = 41570 },
    density = { solid = 4.93, liquid = 3.96 },
    visible = { moles = 0.02, factor = 20, tint = "#7B2CBF" },
    -- What it looks like through glass (tg: other_reagents.dm:1998).
    color = "#BC8A00",
    relevance = 5,
    group = "volatile",
}
