-- Bromine: Br2, the only halogen that stands in a beaker without a lid
-- on it, and the reason this shelf has a phase diagram on a reagent
-- nobody makes anything out of yet.
--
-- Chlorine boils at 239 K and is therefore a gas everywhere on this
-- station; bromine boils at 332 K and freezes at 266 K, which puts BOTH
-- of its transitions inside the range a reaction chamber reaches. That
-- is the whole reason it carries a curve rather than an `unmodeled`
-- rest phase (D2, docs/CHEMISTRY.md): a chemist can freeze it in a
-- fridge-cold beaker and boil it on the hotplate, and the vessel's own
-- sweep is what says so. A substance whose transitions nobody can reach
-- states a convention instead.
--
-- NIST WebBook, Br2: boiling 332.0 K, melting 265.8 K, heat of
-- vaporization 29.96 kJ/mol, heat of fusion 10.57 kJ/mol, liquid
-- density 3.10 g/mL, solid density 3.4 g/mL. Heat capacity 75.7
-- J/(mol*K) is the real LIQUID molar figure, carried across all three
-- phases the way chlorine carries its gas figure -- one number rather
-- than three, two of which would be invented.
--
-- The vapour line clears 6.8 kPa at the melting point, which is far
-- under one atmosphere, so `boil` is the legal spelling here and
-- `triple` is not (D10).
-- tg: /datum/reagent/bromine (other_reagents.dm:2246).
return {
    id = "bromine",
    name = "bromine",
    molar_mass = 159.81,
    cv = 75.7,
    phase = { melt = 265.8, boil = 332.0, l_fus = 10570, l_vap = 29960 },
    density = { liquid = 3.10, solid = 3.4 },
    -- What it looks like through glass (tg: other_reagents.dm:2249).
    color = "#D35415",
    -- Boils at 332 K and fumes well below it -- a bench hazard rather
    -- than an atmospheric one.
    group = "volatile",
}
